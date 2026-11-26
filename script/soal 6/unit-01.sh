#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 6 (IP Statis Permanen: Unit-01)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Jaringan : Switch-Cage (Router Gateway: Misato) | Subnet: 10.78.4.64/29
# Kategori : Pilot | Port Layanan: -
# Alamat   : 10.78.4.66/29 (netmask 255.255.255.248) | Gateway: 10.78.4.65
# Persisten: /etc/network/interfaces (= isi "Edit config" GNS3) -> dimuat ulang saat container start.
# Catatan  : Kode POSIX, jadi juga jalan dengan `sh` bila node ternyata alpinet (busybox ifup).
# Letakkan di : /root/unit-01.sh (di container Unit-01)
# Jalankan    : bash /root/unit-01.sh         (pasang IP, ifupdown, & simpan permanen)
# Uji bukti   : bash /root/unit-01.sh test    (cek ip -br a, ip route, ping gateway & internet)
# ==============================================================================

IF_LAN="eth0"
STATIC_IP="10.78.4.66"
NETMASK="255.255.255.248"
PREFIX="29"
GATEWAY="10.78.4.65"
DNS_SERVER="8.8.8.8"
IFACES_FILE="/etc/network/interfaces"

set -eu

apply_runtime() {
    # Idempotent: replace (bukan add) -> tidak ada 'File exists'; IPv4 lama yang berbeda dibuang.
    ip link set dev lo up 2>/dev/null || true
    ip link set dev "$IF_LAN" up
    ip addr replace "${STATIC_IP}/${PREFIX}" dev "$IF_LAN"
    for OLD in $(ip -4 -o addr show dev "$IF_LAN" | awk '{print $4}'); do
        [ "$OLD" = "${STATIC_IP}/${PREFIX}" ] || ip addr del "$OLD" dev "$IF_LAN"
    done
    ip route replace default via "$GATEWAY" dev "$IF_LAN"
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf
}

bootstrap_network() {
    echo "[*] Menyiapkan IP aktif & DNS agar apt dapat berjalan..."
    if ! ip link show "$IF_LAN" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IF_LAN tidak ditemukan! Cek kabel ke Switch-Cage di GNS3."
        exit 1
    fi
    apply_runtime
}

ensure_ifupdown() {
    if command -v ifup >/dev/null 2>&1; then
        echo "    -> ifup sudah tersedia."
        return 0
    fi
    if command -v apt-get >/dev/null 2>&1; then
        echo "[*] Memasang ifupdown (sesuai Modul §3.4 debinet)..."
        if apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y ifupdown; then
            return 0
        fi
        echo "[!] WARNING: apt gagal (cek NAT/DNS Gendo Soal 4). Lanjut: file tetap ditulis,"
        echo "    dan init GNS3 memuat $IFACES_FILE saat container start."
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

    if command -v ifup >/dev/null 2>&1; then
        echo "[*] Menguji pemuatan ulang konfigurasi lewat ifup (sesuai Modul §3.4)..."
        ifdown "$IF_LAN" 2>/dev/null || true
        ip addr flush dev "$IF_LAN"
        if ! ifup "$IF_LAN"; then
            echo "[!] WARNING: ifup gagal -> IP dipasang ulang manual agar host tidak putus."
        fi
    fi
    # Jaring pengaman: apa pun hasil ifup, pastikan IP & gateway aktif.
    if ! ip -4 -o addr show dev "$IF_LAN" | grep -q " ${STATIC_IP}/${PREFIX} " \
       || ! ip route show default | grep -q "via $GATEWAY"; then
        apply_runtime
    fi
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf
}

show_status() {
    echo "============================================================"
    echo "Status IP Permanen Soal 6 - $(hostname) (Unit-01)"
    echo "============================================================"
    ip -br a 2>/dev/null || ip -4 addr show
    echo "------------------------------------------------------------"
    echo "Tabel Rute (ip route):"
    ip route
    echo "------------------------------------------------------------"
    echo "Isi $IFACES_FILE:"
    cat "$IFACES_FILE" 2>/dev/null || echo "(belum ada)"
    echo "------------------------------------------------------------"
    echo "DNS (/etc/resolv.conf): $(cat /etc/resolv.conf 2>/dev/null)"
    echo "============================================================"
}

ping_target() {
    echo ">>> Ping ke $2 ($1)"
    if ping -c 3 -W 2 "$1"; then
        echo "    [OK] $2 ($1) terjangkau."
    else
        echo "    [GAGAL] $2 ($1) belum merespons."
    fi
    echo ""
}

setup() {
    echo "=== Konfigurasi Soal 6: IP Statis Permanen Unit-01 (10.78.4.66/29) ==="
    bootstrap_network
    ensure_ifupdown
    write_persistent_config
    show_status
}

run_test() {
    show_status
    if grep -q "address $STATIC_IP" "$IFACES_FILE" 2>/dev/null; then
        echo "[OK] $IFACES_FILE memuat $STATIC_IP (akan bertahan setelah restart)."
    else
        echo "[!] $IFACES_FILE belum memuat $STATIC_IP -> jalankan setup / isi Edit config GNS3."
    fi
    echo ""
    echo "=== Uji Ping ==="
    ping_target "$GATEWAY" "Gateway Misato"
    ping_target "8.8.8.8" "Internet (via NAT Gendo)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
