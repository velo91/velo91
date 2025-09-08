#!/usr/bin/env python3
import re
import ipaddress
from collections import Counter
import urllib.request
import subprocess
import requests
from datetime import datetime
import time
import json
from pathlib import Path
from check_log_config_hosting_asn_keyword import HOSTING_ASN_KEYWORDS

# --- Konfigurasi ---
IPINFO_TOKEN = "..." # Ganti token di sini
CACHE_FILE = "/var/www/logs/ipinfo_cache.json"
IP_DIR = "/var/www/opensimka-production/app/h2h/gateway-serverlocal" # lokasi file ip-kampus*.txt
LOW_ACTIVITY_THRESHOLD = 5 # Aktivitas rendah yang layak untuk diambil tindakan

# --- Tampilkan waktu sekarang ---
now = datetime.now()
formatted_time = now.strftime("%A, %d %B %Y %H:%M:%S")
timezone = time.tzname[0]

# --- Load Cache ---
try:
    with open(CACHE_FILE, "r") as f:
        ipinfo_cache = json.load(f)
except:
    ipinfo_cache = {}

# --- Simpan cache ke file ---
def save_cache():
    with open(CACHE_FILE, "w") as f:
        json.dump(ipinfo_cache, f)

# --- Fungsi: Ambil IP publik server ---
def get_public_ip():
    try:
        with urllib.request.urlopen('https://api.ipify.org') as response:
            return response.read().decode('utf-8')
    except:
        return None

# --- Fungsi: Cek apakah subnet atau IP sudah diblokir CrowdSec ---
def is_subnet_blocked_by_crowdsec(subnet, ip):
    try:
        # Cek blokir subnet
        result = subprocess.run(
            ["sudo", "cscli", "decisions", "list", "--scope", "range", "--value", subnet],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        if result.returncode == 0 and "No active decisions" not in result.stdout:
            return True  # Subnet diblokir

        # Jika subnet tidak diblokir, cek apakah IP-nya diblokir
        result_ip = subprocess.run(
            ["sudo", "cscli", "decisions", "list", "--ip", ip],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        if result_ip.returncode == 0 and "No active decisions" not in result_ip.stdout:
            return True  # IP diblokir

        return False  # Tidak diblokir sama sekali

    except Exception as e:
        print(f"⚠ Error saat cek blokir CrowdSec untuk subnet {subnet} / IP {ip}: {e}")
        return False

# --- Fungsi: Ambil GeoIP dan ASN, gunakan cache ---
def get_geo_asn(ip):
    if ip in ipinfo_cache:
        return tuple(ipinfo_cache[ip])

    url = f'https://ipinfo.io/{ip}?token={IPINFO_TOKEN}'
    try:
        response = requests.get(url, timeout=5)
        data = response.json()
        city = data.get('city', 'City tidak diketahui')
        region = data.get('region', 'Region tidak diketahui')
        negara = data.get('country', 'Negara tidak diketahui')
        org = data.get('org', 'ASN tidak diketahui')

        ipinfo_cache[ip] = [city, region, negara, org]
        save_cache()

        return city, region, negara, org
    except Exception as e:
        return 'Tidak diketahui', 'Tidak diketahui', 'Tidak diketahui', f'ERROR: {e}'

# --- Muat daftar IP kampus ---
ip_kampus_map = {}  # ip_saat_ini -> nama kampus
for file_path in Path(IP_DIR).glob("ip-*.txt"):
    if not file_path.is_file():
        continue
    kampus = file_path.stem.replace("ip-", "")
    try:
        with open(file_path, 'r') as f:
            for line in f:
                if line.startswith("ip_saat_ini:"):
                    ip_saat_ini = line.strip().split(":")[1].strip()
                    ip_kampus_map[ip_saat_ini] = kampus
                    break
    except Exception as e:
        print(f"⚠ Gagal membaca {file_path}: {e}")

# --- Ambil IP dari koneksi aktif nginx via netstat ---
ips = []
try:
    result = subprocess.run(
        ["sudo", "netstat", "-tnp"],   # tidak perlu -a biar LISTEN tidak ikut
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )
    for line in result.stdout.splitlines():
        if 'nginx' in line and 'ESTABLISHED' in line:  # hanya koneksi aktif
            parts = line.split()
            if len(parts) > 5:
                address = parts[4]
                ip = address.split(":")[0]
                if ip and ip not in ("127.0.0.1", "0.0.0.0"):
                    ips.append(ip)
except Exception as e:
    print(f"⚠ Gagal mengambil IP koneksi aktif nginx dari netstat: {e}")

# --- Hitung IP terbanyak ---
counter = Counter(ips)

# --- Ambil IP server sendiri ---
my_ip = get_public_ip()
#if my_ip:
#    print(f"\nIP publik server saat ini: {my_ip}")
#else:
#    print("\n⚠ Gagal mendeteksi IP publik server.")
#    my_ip = None

# --- Tampilkan IP yang sering muncul ---
print(f"💻 Daftar IP terbanyak di NETSTAT yang sedang aktif terkoneksi ke nginx (>{LOW_ACTIVITY_THRESHOLD}). Last update {formatted_time} {timezone}.")

checked_subnets = {}
printed = 0

for ip, count in counter.most_common():
    # Tampilkan hasil
    #print(f"{ip.ljust(20)}{str(count).rjust(12)}")

    try:
        ip_obj = ipaddress.ip_address(ip)
        subnet_obj = ipaddress.ip_network(f"{ip}/24", strict=False)
        subnet = str(subnet_obj)

        if ip == my_ip:
            # Skip, langsung loncat ke iterasi berikutnya
            continue

        if count < LOW_ACTIVITY_THRESHOLD:
            # Terlalu kecil, abaikan saja biar tidak bikin semak
            continue

#        elif LOW_ACTIVITY_THRESHOLD < count < HIGH_ACTIVITY_THRESHOLD:
#            # Jika jumlahnya antara LOW_ACTIVITY_THRESHOLD sampai HIGH_ACTIVITY_THRESHOLD, hanya blokir jika berasal dari hosting
#            if subnet not in checked_subnets:
#                blocked = is_subnet_blocked_by_crowdsec(subnet, ip)
#                checked_subnets[subnet] = blocked
#            else:
#                blocked = checked_subnets[subnet]
#
#            if blocked:
#                status = '✅ sudah diblokir'
#                action = ''
#            elif any(x in org.lower() for x in HOSTING_ASN_KEYWORDS):
#                #subprocess.run([
#                #    "sudo", "cscli", "decisions", "add",
#                #    "--reason", "malicious subnet",
#                #    "--duration", "1000d",
#                #    "--range", subnet
#                #])
#                status = '🚫 diblokir otomatis (hosting)'
#                action = ''
#            elif 'microsoft' in org.lower() and negara == 'IE':
#                #subprocess.run([
#                #    "sudo", "cscli", "decisions", "add",
#                #    "--reason", "malicious subnet",
#                #    "--duration", "1000d",
#                #    "--range", subnet
#                #])
#                status = '🚫 diblokir otomatis (Microsoft Irlandia)'
#                action = ''
#            elif 'microsoft' in org.lower() and negara == 'JP':
#                #subprocess.run([
#                #    "sudo", "cscli", "decisions", "add",
#                #    "--reason", "malicious subnet",
#                #    "--duration", "1000d",
#                #    "--range", subnet
#                #])
#                status = '🚫 diblokir otomatis (Microsoft Jepang)'
#                action = ''
#            else:
#                continue  # Tidak memenuhi syarat, skip
#
        else:
            # Jumlahnya > LOW_ACTIVITY_THRESHOLD maka lanjut diproses secara normal
            city, region, negara, org = get_geo_asn(ip)

            # Cek apakah termasuk IP kampus
            if ip in ip_kampus_map:
                status = f"🏛 IP {ip_kampus_map[ip]}     "
            else:
                status = '                 '

            action = ''

#            if subnet not in checked_subnets:
#                blocked = is_subnet_blocked_by_crowdsec(subnet, ip)
#                checked_subnets[subnet] = blocked
#            else:
#                blocked = checked_subnets[subnet]
#
#            if blocked:
#                status = '✅ sudah diblokir'
#                action = ''
#            elif any(x in org.lower() for x in HOSTING_ASN_KEYWORDS):
#                #subprocess.run([
#                #    "sudo", "cscli", "decisions", "add",
#                #    "--reason", "malicious subnet",
#                #    "--duration", "1000d",
#                #    "--range", subnet
#                #])
#                status = '🚫 diblokir otomatis (hosting)'
#                action = ''
#            elif 'google' in org.lower():
#                status = '🔎 perlu ditinjau'
#                action = (
#                    '\n\tASN Google – silakan review manual\n'
#                    f'\t→ Jalankan untuk blokir jika perlu: sudo cscli decisions add --reason "malicious subnet" --duration 1000d --range {subnet}'
#                )
#            elif negara != 'ID':
#                #subprocess.run([
#                #    "sudo", "cscli", "decisions", "add",
#                #    "--reason", "malicious subnet",
#                #    "--duration", "1000d",
#                #    "--range", subnet
#                #])
#                status = '🚫 diblokir otomatis (bukan Indonesia)'
#                action = ''
#            else:
#                status = '🔎 perlu ditinjau'
#                action = (
#                    '\n\tIP dari Indonesia – silakan review manual\n'
#                    f'\t→ Jalankan untuk blokir jika perlu: sudo cscli decisions add --reason "malicious subnet" --duration 1000d --range {subnet}\n'
#                    f'\t→ Jika ISP (bukan hosting), pertimbangkan blok IP-nya (bukan subnet): sudo cscli decisions add --reason "malicious ip" --duration 24h --ip {ip}'
#                )
#
        icon_khusus = "📌" if negara == "ID" else "🛡 "
        print(f"https://ipinfo.io/{ip:<15} | {count:5} kali | {status} | Negara: {negara} {icon_khusus} | {org} ({city}, {region}) {action}")
        printed += 1

    except Exception as e:
        print(f'{ip:<20}: {count:5} kali - ⚠ invalid IP - {e}')
        printed += 1

if printed == 0:
    print(f"Tidak ada IP yang memenuhi syarat (>{LOW_ACTIVITY_THRESHOLD}).")
