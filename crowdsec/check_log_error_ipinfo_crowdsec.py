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

# --- Konfigurasi ---
LOG_FILE = "/var/www/logs/nginx/error.log"
IPINFO_TOKEN = "..." # Ganti token di sini
CACHE_FILE = "/var/www/logs/ipinfo_cache.json"
LOW_ACTIVITY_THRESHOLD = 10 # Aktivitas rendah yang bisa dipertimbangkan jika dari hosting
HIGH_ACTIVITY_THRESHOLD = 300 # Jumlah aktivitas tinggi yang layak untuk diambil tindakan
HOSTING_ASN_KEYWORDS = [
    'digitalocean',
    'akamai',
    'linode',
    'ovh',
    'contabo',
    'vultr',
    'hetzner',
    'hostinger',
    'leaseweb',
    'm247',
    'scaleway',
    'kamatera',
    'netcup',
    'exabytes',
    'sedayu',
    'andhika',
    'berkah',
    'dewa',
    'clouvider',
    'gsl',
    'cheapy',
    'choopa',
    'sovy',
    'serverastra',
    'oracle',
    'colocatel',
    'advin',
    'railnet',
    'psinet',
    'delska',
    'dzcrd',
    'xneelo',
    'powerhouse',
    'code200',
    'datacamp',
    'dpkgsoft',
    'worldstream'
]

# --- Tampilkan waktu sekarang ---
now = datetime.now()
formatted_time = now.strftime("%A, %d %B %Y %H:%M:%S")
timezone = time.tzname[0]
print(f"{formatted_time} {timezone}")

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

# --- Baca log Nginx dan ambil IP ( setelah client: ) ---
ips = []
with open(LOG_FILE, encoding='utf-8', errors='ignore') as f:
#with open(LOG_FILE) as f:
    for line in f:
        #if 'access forbidden by rule' in line:
        #    continue
        m = re.search(r'client: ([0-9a-fA-F:.]+)', line)
        if m:
            ips.append(m.group(1))
# --- Hitung IP terbanyak ---
counter = Counter(ips)

# --- Ambil IP server sendiri ---
my_ip = get_public_ip()
if my_ip:
    print(f"IP publik server saat ini: {my_ip}")
else:
    print("\n⚠ Gagal mendeteksi IP publik server.")
    my_ip = None

# --- Tampilkan IP yang sering muncul ---
print(f"Daftar IP terbanyak di error log Nginx (antara {LOW_ACTIVITY_THRESHOLD} hingga {HIGH_ACTIVITY_THRESHOLD} ke atas):")
#print("----------------------------------------------------------------------")

checked_subnets = {}
printed = 0

for ip, count in counter.most_common():
    try:
        ip_obj = ipaddress.ip_address(ip)
        subnet_obj = ipaddress.ip_network(f"{ip}/24", strict=False)
        subnet = str(subnet_obj)

        if ip == my_ip:
            continue

        if count <= LOW_ACTIVITY_THRESHOLD:
            # Terlalu kecil, abaikan saja biar tidak bikin semak log
            continue

        elif LOW_ACTIVITY_THRESHOLD < count < HIGH_ACTIVITY_THRESHOLD:
            # Jika jumlahnya antara LOW_ACTIVITY_THRESHOLD sampai HIGH_ACTIVITY_THRESHOLD, hanya blokir jika berasal dari hosting
            city, region, negara, org = get_geo_asn(ip)
            if subnet not in checked_subnets:
                blocked = is_subnet_blocked_by_crowdsec(subnet, ip)
                checked_subnets[subnet] = blocked
            else:
                blocked = checked_subnets[subnet]

            if blocked:
                status = '✅ sudah diblokir'
                action = ''
            elif any(x in org.lower() for x in HOSTING_ASN_KEYWORDS):
                subprocess.run([
                    "sudo", "cscli", "decisions", "add",
                    "--reason", "malicious subnet",
                    "--duration", "1000d",
                    "--range", subnet
                ])
                status = '🚫 diblokir otomatis (hosting)'
                action = ''
            elif 'microsoft' in org.lower() and negara == 'IE':
                subprocess.run([
                    "sudo", "cscli", "decisions", "add",
                    "--reason", "malicious subnet",
                    "--duration", "1000d",
                    "--range", subnet
                ])
                status = '🚫 diblokir otomatis (Microsoft Irlandia)'
                action = ''
            elif 'microsoft' in org.lower() and negara == 'JP':
                subprocess.run([
                    "sudo", "cscli", "decisions", "add",
                    "--reason", "malicious subnet",
                    "--duration", "1000d",
                    "--range", subnet
                ])
                status = '🚫 diblokir otomatis (Microsoft Jepang)'
                action = ''
            else:
                continue  # Tidak memenuhi syarat, skip

        else:
            # Jumlahnya >= HIGH_ACTIVITY_THRESHOLD maka lanjut diproses secara normal
            city, region, negara, org = get_geo_asn(ip)
            if subnet not in checked_subnets:
                blocked = is_subnet_blocked_by_crowdsec(subnet, ip)
                checked_subnets[subnet] = blocked
            else:
                blocked = checked_subnets[subnet]

            if blocked:
                status = '✅ sudah diblokir'
                action = ''
            elif any(x in org.lower() for x in HOSTING_ASN_KEYWORDS):
                subprocess.run([
                    "sudo", "cscli", "decisions", "add",
                    "--reason", "malicious subnet",
                    "--duration", "1000d",
                    "--range", subnet
                ])
                status = '🚫 diblokir otomatis (hosting)'
                action = ''
            elif 'google' in org.lower():
                status = '🔎 perlu ditinjau'
                action = (
                    '\n\tASN Google – silakan review manual\n'
                    f'\t→ Jalankan untuk blokir jika perlu: sudo cscli decisions add --reason "malicious subnet" --duration 1000d --range {subnet}'
                )
            elif negara != 'ID':
                subprocess.run([
                    "sudo", "cscli", "decisions", "add",
                    "--reason", "malicious subnet",
                    "--duration", "1000d",
                    "--range", subnet
                ])
                status = '🚫 diblokir otomatis (bukan Indonesia)'
                action = ''
            else:
                status = '🔎 perlu ditinjau'
                action = (
                    '\n\tIP dari Indonesia – silakan review manual\n'
                    f'\t→ Jalankan untuk blokir jika perlu: sudo cscli decisions add --reason "malicious subnet" --duration 1000d --range {subnet}\n'
                    f'\t→ Jika ISP (bukan hosting), pertimbangkan blok IP-nya (bukan subnet): sudo cscli decisions add --reason "malicious ip" --duration 24h --ip {ip}'
                )

        icon_khusus = "📌" if negara == "ID" else " 🛡"
        print(f"https://ipinfo.io/{ip:<15} | {count:5} kali | {status} | Negara: {negara} {icon_khusus} | {org} ({city}, {region}) {action}")
        printed += 1

    except Exception as e:
        print(f'{ip:<20}: {count:5} kali - ⚠ invalid IP - {e}')
        printed += 1

if printed == 0:
    print("Tidak ada IP yang memenuhi syarat.")

#print(f"\n")
