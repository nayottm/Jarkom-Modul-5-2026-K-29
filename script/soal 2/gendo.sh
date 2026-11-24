#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 2 (Router GENDO / GENDOU1 (9 Interface: NAT1 DHCP + Switch-Cmd + 7 Router))
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Catatan : Khusus Soal 2 di debinet memakai perintah ip + sysctl (tanpa ifupdown/apt,
#           karena instalasi paket baru dilakukan mulai Soal 4 sesuai Modul §2.2-2.5).
# Letakkan di: /root/gendo.sh
# Jalankan   : bash /root/gendo.sh         (setup IP + IP forwarding)
# Uji bukti  : bash /root/gendo.sh test    (ip -br a + ip route + ping ujung link)
# ==============================================================================

# --- SESUAIKAN LABEL INTERFACE DENGAN TOPOLOGI GNS3 KALIAN ---
IF_NAT="eth0"          # ke NAT1 (nat0 / DHCP) -- ubah ke eth9 jika tadi pakai eth9
IF_YUI="eth1"          # Link ke Yui (Julian)
IF_HIKARI="eth2"       # Link ke Hikari (Julian)
IF_ASUKA="eth3"        # Link ke Asuka (Julian)
IF_KAJI="eth4"         # Link ke Kaji (Julian)
IF_MISATO="eth5"       # Link ke Misato1 (Julian)
IF_SHIGERU="eth6"      # Link ke Shigeru1 (Arul)
IF_FUYUTSUKI="eth7"    # Link ke Fuyutsuki1 (Arul)
IF_CMD="eth8"          # ke Switch-Cmd (LAN Tokyo3-Core1)
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

ensure_dhcp_nat() {
    IFACE="$1"; DESC="$2"
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IFACE ($DESC) tidak ditemukan! Cek jumlah adapter / label kabel di GNS3."
        return 1
    fi
    ip link set dev "$IFACE" up

    # Sesuai Modul Implementasi §2.1: pada debinet, interface ke NAT1 umumnya sudah mendapat IP DHCP otomatis.
    # Jangan flush/release jika sudah punya IPv4 aktif agar koneksi ke NAT1 tidak putus.
    if ip -4 addr show dev "$IFACE" | grep -q 'inet '; then
        CUR_IP="$(ip -4 -br addr show dev "$IFACE" | awk '{print $3}')"
        echo "    -> $IFACE : $CUR_IP (DHCP aktif dari $DESC, dipertahankan)"
        return 0
    fi

    echo "[*] $IFACE belum punya IPv4, mencoba DHCP ($DESC)..."
    if command -v dhclient >/dev/null 2>&1; then
        dhclient "$IFACE" || true
    elif command -v udhcpc >/dev/null 2>&1; then
        udhcpc -i "$IFACE" -q -t 5 || true
    fi

    if ip -4 addr show dev "$IFACE" | grep -q 'inet '; then
        CUR_IP="$(ip -4 -br addr show dev "$IFACE" | awk '{print $3}')"
        echo "    -> $IFACE : $CUR_IP (DHCP berhasil)"
    else
        echo "[!] WARNING: $IFACE ($DESC) belum mendapat IP DHCP."
        echo "    Cek kabel NAT1, atau pakai fallback Modul §2.2 (sesuaikan subnet NAT GNS3 kalian):"
        echo "    ip addr add 192.168.122.100/24 dev $IFACE && ip route replace default via 192.168.122.1"
    fi
}

setup() {
    echo "=== Konfigurasi Soal 2 (debinet): Router GENDO / GENDOU1 (9 Interface: NAT1 DHCP + Switch-Cmd + 7 Router) ==="
    ip link set dev lo up 2>/dev/null || true
    ensure_dhcp_nat  "$IF_NAT"       "NAT1 (WAN / DHCP)"
    set_static_iface "$IF_YUI"       "10.78.4.109/30" "Link Gendo -> Yui"
    set_static_iface "$IF_HIKARI"    "10.78.4.113/30" "Link Gendo -> Hikari"
    set_static_iface "$IF_ASUKA"     "10.78.4.117/30" "Link Gendo -> Asuka"
    set_static_iface "$IF_KAJI"      "10.78.4.121/30" "Link Gendo -> Kaji"
    set_static_iface "$IF_MISATO"    "10.78.4.125/30" "Link Gendo -> Misato"
    set_static_iface "$IF_SHIGERU"   "10.78.4.129/30" "Link Gendo -> Shigeru"
    set_static_iface "$IF_FUYUTSUKI" "10.78.4.133/30" "Link Gendo -> Fuyutsuki"
    set_static_iface "$IF_CMD"       "10.78.4.105/30" "LAN Switch-Cmd (gw Tokyo3-Core)"
    enable_ip_forwarding
    show_summary
}

run_test() {
    show_summary
    echo "=== Uji Ping Ujung Link ==="
    ping_peer "10.78.4.130" "Shigeru (Arul)"
    ping_peer "10.78.4.134" "Fuyutsuki (Arul)"
    ping_peer "10.78.4.110" "Yui (Julian)"
    ping_peer "10.78.4.114" "Hikari (Julian)"
    ping_peer "10.78.4.118" "Asuka (Julian)"
    ping_peer "10.78.4.122" "Kaji (Julian)"
    ping_peer "10.78.4.126" "Misato (Julian)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
