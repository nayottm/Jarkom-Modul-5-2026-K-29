#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 2 (Router TOJI (2 Interface: Fuyutsuki + Switch-Dogma))
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Catatan : Khusus Soal 2 di debinet memakai perintah ip + sysctl (tanpa ifupdown/apt,
#           karena instalasi paket baru dilakukan mulai Soal 4 sesuai Modul §2.2-2.5).
# Letakkan di: /root/toji.sh
# Jalankan   : bash /root/toji.sh         (setup IP + IP forwarding)
# Uji bukti  : bash /root/toji.sh test    (ip -br a + ip route + ping ujung link)
# ==============================================================================

# --- SESUAIKAN LABEL INTERFACE DENGAN TOPOLOGI GNS3 KALIAN ---
IF_FUYUTSUKI="eth0"    # ke Fuyutsuki1 (eth1)
IF_DOGMA="eth1"        # ke Switch-Dogma (LAN Lilith & Adam)
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
    echo "=== Konfigurasi Soal 2 (debinet): Router TOJI (2 Interface: Fuyutsuki + Switch-Dogma) ==="
    ip link set dev lo up 2>/dev/null || true
    set_static_iface "$IF_FUYUTSUKI" "10.78.4.166/30" "Link Toji -> Fuyutsuki"
    set_static_iface "$IF_DOGMA"     "10.78.4.73/29"  "LAN Switch-Dogma (gw Lilith, Adam)"
    enable_ip_forwarding
    show_summary
}

run_test() {
    show_summary
    echo "=== Uji Ping Ujung Link ==="
    ping_peer "10.78.4.165" "Fuyutsuki"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
