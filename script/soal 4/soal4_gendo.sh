#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 4 (Router GENDO / GENDOU — NAT & DNS)
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Syarat  :
#   - Akses internet seluruh jaringan lewat Gendo tanpa perlu ubah config jika IP NAT1 berubah (MASQUERADE).
#   - Hanya traffic dari prefix internal (10.78.0.0/16) yang keluar lewat NAT1 (eth0) yang di-NAT;
#     traffic antar-LAN tetap membawa IP asli pengirim.
#   - Selesaikan sebelum node lain memasang paket.
# Letakkan di: /root/soal4.sh (nanti digabung ke /root/gendo.sh pada Soal 5)
# Jalankan   : bash /root/soal4.sh         (install paket + pasang NAT MASQUERADE)
# Uji bukti  : bash /root/soal4.sh test    (tampilkan counter rule NAT setelah ping klien)
# ==============================================================================

# --- SESUAIKAN DENGAN TOPOLOGI GNS3 KALIAN ---
IF_NAT="eth0"                  # Interface Gendo ke NAT1 (DHCP)
INTERNAL_PREFIX="10.78.0.0/16" # Prefix internal Kelompok 29
DNS_SERVER="8.8.8.8"           # DNS resolver (Modul §2.4)
# ---------------------------------------------

set -eu

ensure_packages() {
    echo "[*] Mengatur DNS resolver di Gendo ($DNS_SERVER)..."
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf

    echo "[*] Cek ketersediaan paket (ifupdown, iptables, conntrack)..."
    MISSING=""
    for cmd_pkg in "iptables:iptables" "conntrack:conntrack" "ifup:ifupdown"; do
        CMD="${cmd_pkg%%:*}"
        PKG="${cmd_pkg##*:}"
        if ! command -v "$CMD" >/dev/null 2>&1; then
            MISSING="$MISSING $PKG"
        fi
    done

    if [ -n "$MISSING" ]; then
        echo "[*] Memasang paket:$MISSING ..."
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y $MISSING
    else
        echo "    -> Paket ifupdown, iptables, dan conntrack sudah terpasang."
    fi

    # Fallback otomatis ke iptables-legacy jika nftables tidak didukung kernel host (Modul §14)
    if ! iptables -t nat -S >/dev/null 2>&1; then
        echo "[!] iptables nft gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    echo "    -> Versi iptables: $(iptables --version)"
}

show_nat_status() {
    echo "============================================================"
    echo "Rule & Counter NAT POSTROUTING - $(hostname) [debinet]"
    echo "============================================================"
    iptables -t nat -L POSTROUTING -n -v --line-numbers
    echo "------------------------------------------------------------"
    echo "Format iptables -t nat -S:"
    iptables -t nat -S POSTROUTING
    echo "------------------------------------------------------------"
    echo "DNS (/etc/resolv.conf): $(cat /etc/resolv.conf)"
    echo "IP Forwarding         : $(cat /proc/sys/net/ipv4/ip_forward)"
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 4 (debinet): NAT MASQUERADE di GENDO ==="

    if ! ip link show "$IF_NAT" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IF_NAT tidak ditemukan!"
        exit 1
    fi

    # Pastikan IP forwarding tetap aktif
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward

    # Pasang paket modul di Gendo
    ensure_packages

    # Pasang rule NAT MASQUERADE secara idempoten:
    # - Hanya sumber dari prefix internal (-s 10.78.0.0/16)
    # - Hanya paket keluar lewat interface NAT1 (-o eth0)
    # - Traffic antar-LAN keluar lewat eth1-eth8 sehingga TIDAK terkena MASQUERADE
    echo "[*] Memasang rule NAT MASQUERADE (-s $INTERNAL_PREFIX -o $IF_NAT)..."
    if ! iptables -t nat -C POSTROUTING -s "$INTERNAL_PREFIX" -o "$IF_NAT" -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -s "$INTERNAL_PREFIX" -o "$IF_NAT" -j MASQUERADE
        echo "    -> Rule MASQUERADE ditambahkan."
    else
        echo "    -> Rule MASQUERADE sudah terpasang (tidak diduplikasi)."
    fi

    show_nat_status
    echo "[i] Selanjutnya jalankan soal4.sh di Armisael dan Lilith, lalu jalankan:"
    echo "    bash /root/soal4.sh test   (di Gendo untuk melihat counter pkts & bytes naik)"
}

run_test() {
    show_nat_status
    echo "=== Uji Konektivitas Internet dari Gendo ==="
    ping -c 3 -W 2 8.8.8.8
    ping -c 3 -W 2 deb.debian.org
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
