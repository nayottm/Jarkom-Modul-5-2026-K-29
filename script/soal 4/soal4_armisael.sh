#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 4 (Node Uji ARMISAEL — DNS & Uji Internet)
# Kelompok: K-29 (10.78.0.0/16) | PIC: Arul
# Syarat  : Node bisa resolve domain (deb.debian.org) dan ping 8.8.8.8 lewat NAT Gendo.
# Letakkan di: /root/soal4.sh (di container Armisael)
# Jalankan   : bash /root/soal4.sh         (atur DNS resolver /etc/resolv.conf)
# Uji bukti  : bash /root/soal4.sh test    (ping 8.8.8.8 & ping deb.debian.org)
# ==============================================================================

IF_LAN="eth0"          # ke Switch-Monolith (gw Shigeru)
TEMP_IP="10.78.4.83/29"    # IP sementara Soal 3-5
TEMP_GW="10.78.4.81"         # Gateway sementara Soal 3-5
DNS_SERVER="8.8.8.8"   # DNS resolver (Modul §3.4)

set -eu

ensure_temp_network() {
    # Pastikan IP & gateway sementara Soal 3 masih aktif
    ip link set dev lo up 2>/dev/null || true
    ip link set dev "$IF_LAN" up
    if ! ip -4 addr show dev "$IF_LAN" | grep -q "${TEMP_IP%/*}"; then
        ip addr flush dev "$IF_LAN"
        ip addr add "$TEMP_IP" dev "$IF_LAN"
    fi
    ip route replace default via "$TEMP_GW"
}

show_status() {
    echo "============================================================"
    echo "Status Jaringan & DNS - $(hostname)"
    echo "============================================================"
    ip -br a
    echo "------------------------------------------------------------"
    ip route
    echo "------------------------------------------------------------"
    echo "Isi /etc/resolv.conf:"
    cat /etc/resolv.conf
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 4: DNS Resolver di ARMISAEL ==="
    ensure_temp_network
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf
    echo "    -> /etc/resolv.conf diset ke nameserver $DNS_SERVER"
    show_status
}

run_test() {
    show_status
    echo "=== Uji Bukti Soal 4 dari ARMISAEL ==="
    echo ">>> 1. Ping ke 8.8.8.8 (Uji NAT & Routing Internet)"
    ping -c 3 -W 3 8.8.8.8
    echo ""
    echo ">>> 2. Ping ke deb.debian.org (Uji DNS Resolution & Internet)"
    ping -c 3 -W 3 deb.debian.org
    echo ""
    echo "[OK] Bukti Soal 4 pada ARMISAEL selesai. Cek counter NAT di Gendo!"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
