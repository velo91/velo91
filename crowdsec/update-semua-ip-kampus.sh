#!/bin/bash

IP_DIR="/path/to/folder" # lokasi file ip-kampus*.txt

for FILE in "$IP_DIR"/ip-*.txt; do
    [ -e "$FILE" ] || continue

    KAMPUS=$(basename "$FILE" .txt | sed 's/^ip-//')

    IP_SAAT_INI=$(grep "^ip_saat_ini:" "$FILE" | awk '{print $2}')
    IP_SAAT_INI_ALT=$(grep "^ip_saat_ini_alt:" "$FILE" | awk '{print $2}')

    IP_SEBELUMNYA=$(grep "^ip_sebelumnya:" "$FILE" | awk '{print $2}')
    IP_SEBELUMNYA_ALT=$(grep "^ip_sebelumnya_alt:" "$FILE" | awk '{print $2}')

    if [ -z "$IP_SAAT_INI" ]; then
        echo "[SKIP] $KAMPUS: ip_saat_ini kosong"
        continue
    fi

    ########################################
    # HAPUS IP LAMA
    ########################################

    if [ -n "$IP_SEBELUMNYA" ]; then
        echo "[REMOVE] Hapus IP lama $IP_SEBELUMNYA dari allowlist ($KAMPUS)"
        cscli allowlist remove semua_ip_kampus "$IP_SEBELUMNYA" >/dev/null 2>&1
    fi

    if [ -n "$IP_SEBELUMNYA_ALT" ]; then
        echo "[REMOVE] Hapus IP lama ALT $IP_SEBELUMNYA_ALT dari allowlist ($KAMPUS)"
        cscli allowlist remove semua_ip_kampus "$IP_SEBELUMNYA_ALT" >/dev/null 2>&1
    fi

    ########################################
    # FUNGSI UNTUK TAMBAH IP
    ########################################

    add_ip_if_needed () {

        local IP=$1
        local LABEL=$2

        if [ -z "$IP" ]; then
            return
        fi

        CHECK_OUTPUT=$(cscli allowlist check "$IP")

        if echo "$CHECK_OUTPUT" | grep -q "is allowlisted"; then
            echo "[OK] $CHECK_OUTPUT (kampus: $KAMPUS $LABEL)"
        else
            echo "[UPDATE] Tambah IP $IP ke allowlist ($KAMPUS $LABEL)"
            cscli allowlist add semua_ip_kampus "$IP" -e 30d >/dev/null 2>&1
        fi
    }

    ########################################
    # TAMBAH IP BARU
    ########################################

    add_ip_if_needed "$IP_SAAT_INI" ""
    add_ip_if_needed "$IP_SAAT_INI_ALT" "(ALT)"

done
