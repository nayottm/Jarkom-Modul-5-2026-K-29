#!/bin/sh
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3-5 (IP & Gateway SEMENTARA Node Uji Comm-Net)
# Kelompok: K-29 (10.78.0.0/16) | Image: debinet / alpinet | PIC: Julian
# Catatan : POSIX sh (jalan di debinet & alpinet/busybox). Konfigurasi runtime saja,
#           hilang saat node restart. IP permanen dibuat di Soal 6.
# Letakkan di: /root/soal3_comm-net.sh
# Jalankan   : sh /root/soal3_comm-net.sh         (pasang IP + default gateway sementara)
# Uji bukti  : sh /root/soal3_comm-net.sh test    (ip addr + ip route + ping node uji)
# ==============================================================================

IFACE="eth0"            # ke Switch-Comm
IP_CIDR="10.78.2.2/24"
GATEWAY="10.78.2.1"       # Hikari

set -eu

ping_peer() {
    echo ">>> Ping ke $2 ($1)"
    if ping -c 3 -W 2 "$1"; then
        echo "    [OK] $2 ($1) terhubung."
    else
        echo "    [GAGAL] $2 ($1) belum merespons."
    fi
    echo ""
}

show_summary() {
    echo "============================================================"
    echo "Status Comm-Net - $(hostname)"
    echo "============================================================"
    ip -4 addr show dev "$IFACE"
    echo "------------------------------------------------------------"
    ip route
    echo "============================================================"
}

setup() {
    echo "=== Soal 3-5: IP sementara Comm-Net ==="
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IFACE tidak ditemukan! Cek kabel ke Switch-Comm di GNS3."
        exit 1
    fi
    ip link set dev lo up 2>/dev/null || true
    ip link set dev "$IFACE" up
    ip addr flush dev "$IFACE"
    ip addr add "$IP_CIDR" dev "$IFACE"
    while ip route del default 2>/dev/null; do :; done
    ip route add default via "$GATEWAY" dev "$IFACE"
    echo "    -> $IFACE : $IP_CIDR, default via $GATEWAY (Hikari)"
    show_summary
}

run_test() {
    show_summary
    echo "=== Uji Ping Node Uji Soal 3 ==="
    ping_peer "10.78.2.1" "Hikari (gateway)"
    ping_peer "10.78.4.83" "Armisael"
    ping_peer "10.78.4.74" "Lilith"
    ping_peer "10.78.3.130" "Sachiel"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
