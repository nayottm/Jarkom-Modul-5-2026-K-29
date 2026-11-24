#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 5 SAJA (Pintu Depan Dikunci Rapat di GENDO)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Syarat   : Pastikan Soal 2 (IP + ip_forward), Soal 3 (routing), dan Soal 4
#            (iptables + NAT MASQUERADE) sudah aktif di Gendo.
# Catatan  : Script ini hanya mengatur tabel filter (INPUT & FORWARD) tanpa
#            menghapus rule MASQUERADE di tabel nat.
# Letakkan di : /root/soal5.sh
# Jalankan    : bash /root/soal5.sh         (pasang firewall Soal 5)
# Uji bukti   : bash /root/soal5.sh test    (tampilkan iptables -S & counter)
# ==============================================================================

IF_NAT="eth0"                  # Interface Gendo ke NAT1
INTERNAL_PREFIX="10.78.0.0/16" # Prefix internal Kelompok 29

set -eu

setup_firewall() {
    echo "=== Konfigurasi Soal 5: Kunci Pintu Depan (NAT1) di GENDO ==="

    if ! command -v iptables >/dev/null 2>&1; then
        echo "[!] ERROR: iptables belum terpasang. Jalankan Soal 4 terlebih dahulu!"
        exit 1
    fi

    # Fallback otomatis ke iptables-legacy jika nf_tables tidak didukung kernel (Modul §14)
    if ! iptables -S >/dev/null 2>&1; then
        echo "[!] iptables nft gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    # 1. Reset aman tabel filter (policy ACCEPT dulu baru flush, Modul §12.3)
    #    Tabel nat (MASQUERADE dari Soal 4) TIDAK disentuh.
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT
    iptables -F FORWARD
    iptables -F OUTPUT

    # 2. Aturan INPUT (paket menuju Gendo sendiri)
    #    - Loopback tetap jalan
    iptables -A INPUT -i lo -j ACCEPT
    #    - (a) Balasan koneksi yang sudah ada
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    #    - DHCP dari sisi NAT1 (UDP 67 -> 68) tetap jalan
    iptables -A INPUT -i "$IF_NAT" -p udp --sport 67 --dport 68 -j ACCEPT
    #    - (d) Traffic dari jaringan internal ke Gendo sendiri
    iptables -A INPUT ! -i "$IF_NAT" -s "$INTERNAL_PREFIX" -j ACCEPT

    # 3. Aturan FORWARD (paket melewati Gendo)
    #    - (a) Balasan koneksi yang sudah ada
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    #    - (b) Traffic dari jaringan internal ke internet (keluar via NAT1)
    iptables -A FORWARD ! -i "$IF_NAT" -o "$IF_NAT" -s "$INTERNAL_PREFIX" -j ACCEPT
    #    - (c) Traffic antar-LAN internal
    iptables -A FORWARD ! -i "$IF_NAT" ! -o "$IF_NAT" -s "$INTERNAL_PREFIX" -d "$INTERNAL_PREFIX" -j ACCEPT

    # 4. Ubah policy INPUT & FORWARD menjadi DROP paling akhir (Modul §8.5)
    #    Koneksi baru dari sisi NAT1 otomatis dibuang.
    iptables -P INPUT DROP
    iptables -P FORWARD DROP

    echo "[OK] Policy INPUT=DROP & FORWARD=DROP aktif. Rule NAT Soal 4 tetap utuh."
}

show_proof() {
    echo "============================================================"
    echo "Bukti iptables -S (Soal 5) - $(hostname)"
    echo "============================================================"
    iptables -S
    echo "------------------------------------------------------------"
    echo "Pastikan NAT Soal 4 tetap ada (iptables -t nat -S):"
    iptables -t nat -S
    echo "------------------------------------------------------------"
    echo "Counter Filter (iptables -L -n -v --line-numbers):"
    iptables -L -n -v --line-numbers
    echo "============================================================"
}

if [ "${1:-setup}" = "test" ]; then
    show_proof
    echo ">>> Uji ping 8.8.8.8 dari Gendo:"
    ping -c 3 -W 2 8.8.8.8
    echo ""
    echo "[i] Sekarang uji di konsol Armisael: ping -c 3 8.8.8.8"
else
    setup_firewall
    show_proof
fi
