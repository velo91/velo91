#!/bin/bash
IP_DIR="/path/to/folder" # lokasi file ip-kampus*.txt

for FILE in "$IP_DIR"/ip-*.txt; do
    [ -e "$FILE" ] || continue
    KAMPUS=$(basename "$FILE" .txt | sed 's/^ip-//')

    # Ambil ip_saat_ini & ip_sebelumnya dari file
    IP_SAAT_INI=$(grep "ip_saat_ini:" "$FILE" | awk '{print $2}')
    IP_SEBELUMNYA=$(grep "ip_sebelumnya:" "$FILE" | awk '{print $2}')

    # Skip jika ip_saat_ini kosong
    if [ -z "$IP_SAAT_INI" ]; then
        echo "[SKIP] $KAMPUS: ip_saat_ini kosong"
        continue
    fi

    # Buat AllowList khusus kampus jika belum ada
    #cscli allowlist create semua_ip_kampus -d "Semua IP Kampus yang didapat dari cronjob ke OPENSIMKA" >/dev/null 2>&1

    # Hapus IP lama jika ip_sebelumnya ada & beda dengan ip_saat_ini
    if [ -n "$IP_SEBELUMNYA" ] && [ "$IP_SEBELUMNYA" != "$IP_SAAT_INI" ]; then
        echo "[REMOVE] Hapus IP lama $IP_SEBELUMNYA dari allowlist $KAMPUS"
        cscli allowlist remove semua_ip_kampus "$IP_SEBELUMNYA" >/dev/null 2>&1
    fi

    # Cek apakah IP saat ini sudah ada di AllowList pakai `cscli allowlist check`
    CHECK_OUTPUT=$(cscli allowlist check "$IP_SAAT_INI")
    if echo "$CHECK_OUTPUT" | grep -q "is allowlisted"; then
        echo "[OK] $CHECK_OUTPUT (kampus: $KAMPUS)"
    else
        echo "[UPDATE] Tambah IP $IP_SAAT_INI ke allowlist $KAMPUS"
        cscli allowlist add semua_ip_kampus "$IP_SAAT_INI" >/dev/null 2>&1
    fi
done
