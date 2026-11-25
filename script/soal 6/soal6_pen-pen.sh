#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 6 (IP Statis Permanen: Pen-Pen)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Jaringan : Switch-Medic (Router Gateway: Maya) | Subnet: 10.78.3.192/27
# Kategori : Lainnya | Port Layanan: TCP 80 (Soal 8, 14), 9000 (Soal 17)
# Alamat   : 10.78.3.194/27 (netmask 255.255.255.224) | Gateway: 10.78.3.193
# Letakkan di : /root/soal6.sh (di container Pen-Pen)
# Jalankan    : bash /root/soal6.sh         (pasang IP, ifupdown, & simpan permanen)
# Uji bukti   : bash /root/soal6.sh test    (cek ip -br a, ip route, ping gateway & internet)
# ==============================================================================

IF_LAN="eth0"
STATIC_IP="10.78.3.194"
NETMASK="255.255.255.224"
PREFIX="27"
GATEWAY="10.78.3.193"
DNS_SERVER="8.8.8.8"
IFACES_FILE="/etc/network/interfaces"

set -eu

bootstrap_network() {
    echo "[*] Menyiapkan IP aktif sementara & DNS agar apt dapat berjalan..."
    ip link set dev lo up 2>/dev/null || true
    if ! ip link show "$IF_LAN" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IF_LAN tidak ditemukan!"
        exit 1
    fi
    ip link set dev "$IF_LAN" up
    ip addr flush dev "$IF_LAN"
    ip addr add "${STATIC_IP}/${PREFIX}" dev "$IF_LAN"
    ip route replace default via "$GATEWAY"
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf
}

ensure_ifupdown() {
    if command -v ifup >/dev/null 2>&1; then
        echo "    -> ifupdown sudah terpasang."
        return 0
    fi
    if command -v apt-get >/dev/null 2>&1; then
        echo "[*] Memasang ifupdown (sesuai Modul §3.4 debinet)..."
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y ifupdown
    else
        echo "[!] WARNING: ifup tidak ditemukan dan bukan sistem apt."
    fi
}

write_persistent_config() {
    echo "[*] Menulis konfigurasi permanen ke $IFACES_FILE..."
    mkdir -p /etc/network /run/network
    cat > "$IFACES_FILE" <<EOF
auto lo
iface lo inet loopback

auto $IF_LAN
iface $IF_LAN inet static
    address $STATIC_IP
    netmask $NETMASK
    gateway $GATEWAY
    up echo "nameserver $DNS_SERVER" > /etc/resolv.conf
EOF

    echo "[*] Menguji pemuatan ulang konfigurasi lewat ifup (sesuai Modul §3.4)..."
    if command -v ifup >/dev/null 2>&1; then
        ifdown "$IF_LAN" 2>/dev/null || true
        ip addr flush dev "$IF_LAN"
        mkdir -p /run/network
        ifup "$IF_LAN"
    fi
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf
}

show_status() {
    echo "============================================================"
    echo "Status IP Permanen Soal 6 - $(hostname) (Pen-Pen)"
    echo "============================================================"
    ip -br a
    echo "------------------------------------------------------------"
    echo "Tabel Rute (ip route):"
    ip route
    echo "------------------------------------------------------------"
    echo "Isi $IFACES_FILE:"
    cat "$IFACES_FILE"
    echo "------------------------------------------------------------"
    echo "DNS (/etc/resolv.conf): $(cat /etc/resolv.conf)"
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 6: IP Statis Permanen Pen-Pen (10.78.3.194/27) ==="
    bootstrap_network
    ensure_ifupdown
    write_persistent_config
    show_status
}

run_test() {
    show_status
    echo "=== Uji Ping Gateway (Maya: $GATEWAY) ==="
    ping -c 3 -W 2 "$GATEWAY"
    echo ""
    echo "=== Uji Ping Internet (8.8.8.8) ==="
    ping -c 3 -W 2 8.8.8.8
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
