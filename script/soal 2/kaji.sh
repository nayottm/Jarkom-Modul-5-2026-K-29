#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 2 (Router KAJI (2 Interface: Gendo + Switch-Intel))
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Catatan : Khusus Soal 2 di debinet memakai perintah ip + sysctl (tanpa ifupdown/apt,
#           karena instalasi paket baru dilakukan mulai Soal 4 sesuai Modul §2.2-2.5).
# Letakkan di: /root/kaji.sh
# Jalankan   : bash /root/kaji.sh         (setup IP + IP forwarding)
# Uji bukti  : bash /root/kaji.sh test    (ip -br a + ip route + ping ujung link)
# ==============================================================================

# --- SESUAIKAN LABEL INTERFACE DENGAN TOPOLOGI GNS3 KALIAN ---
IF_GENDO="eth0"         # ke Gendou (eth4, asumsi: konfirmasi ke Arul)
IF_INTEL="eth1"         # ke Switch-Intel
# -------------------------------------------------------------

set -eu

enable_ip_forwarding() {
    echo "[*] Mengaktifkan IPv4 forwarding..."
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward
    if [ -f /etc/sysctl.conf ] && ! grep -Eq '^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=[[:space:]]*1' /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    sysctl net.ipv4.ip_forward 2>/dev/null || echo "net.ipv4.ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
}

set_static_iface() {
    IFACE="$1"; CIDR="$2"; DESC="$3"
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IFACE ($DESC) tidak ditemukan! Cek jumlah adapter / label kabel di GNS3."
        return 1
    fi
    ip link set dev "$IFACE" up
    ip addr flush dev "$IFACE"
    ip addr add "$CIDR" dev "$IFACE"
    echo "    -> $IFACE : $CIDR ($DESC)"
}

ping_peer() {
    echo ">>> Ping ke $2 ($1)"
    if ping -c 3 -W 2 "$1"; then
        echo "    [OK] $2 ($1) terhubung."
    else
        echo "    [GAGAL] $2 ($1) belum merespons (pastikan router lawan sudah dikonfigurasi)."
    fi
    echo ""
}

show_summary() {
    echo "============================================================"
    echo "Status Interface (ip -br a) - $(hostname) [debinet]"
    echo "============================================================"
    ip -br a
    echo "------------------------------------------------------------"
    echo "Tabel Rute (ip route):"
    ip route
    echo "------------------------------------------------------------"
    sysctl net.ipv4.ip_forward 2>/dev/null || echo "net.ipv4.ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 2 (debinet): Router KAJI (2 Interface: Gendo + Switch-Intel) ==="
    ip link set dev lo up 2>/dev/null || true
    set_static_iface "$IF_GENDO"      "10.78.4.122/30"   "Link Kaji -> Gendo"
    set_static_iface "$IF_INTEL"      "10.78.4.101/30"   "LAN Switch-Intel (gw Spy)"
    enable_ip_forwarding
    show_summary
}

run_test() {
    show_summary
    echo "=== Uji Ping Ujung Link ==="
    ping_peer "10.78.4.121" "Gendo"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
