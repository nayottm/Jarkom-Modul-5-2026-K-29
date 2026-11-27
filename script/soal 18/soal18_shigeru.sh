#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 18 (Gerbang Monolith & Radar: Firewall Zona di Shigeru)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Shigeru — eth0 ke Gendo (10.78.4.130/30), eth1 ke Makoto (Radar di baliknya),
#            eth2 ke Switch-Monolith (10.78.4.81/29).
# Zona     : semua yang TIDAK di sisi Gendo = Switch-Monolith + Switch-Radar (+ IP Shigeru sisi zona).
# Aturan   : Paket yang MASUK dari interface sisi Gendo (IF_GENDO) diperiksa di chain SHIGERU_GERBANG:
#              1) ESTABLISHED,RELATED   -> ACCEPT  (balasan koneksi yang dimulai dari dalam zona)
#              2) ping (echo-request) dari subnet Terminal 10.78.4.56/29 -> ACCEPT (satu pengecualian)
#              3) selain itu            -> DROP    (koneksi baru dari luar ditolak)
#            Dipasang di FORWARD (ke host zona) & INPUT (ke IP Shigeru sisi zona, mis. 10.78.4.81).
#            Penolakan berdasarkan ARAH (-i IF_GENDO), TANPA daftar subnet luar -> subnet baru
#            otomatis ikut terblokir. Dari dalam zona tidak ada rule -> bebas memulai koneksi.
# Catatan  : IF_GENDO dideteksi dari default route (via Gendo); bisa ditimpa: IF_GENDO=eth0 bash ...
#            Idempotent: hanya chain SHIGERU_GERBANG milik script ini yang dibuat ulang.
# Letakkan di : /root/soal18.sh (di container Shigeru)
# Jalankan    : bash /root/soal18.sh          (pasang gerbang)
# Uji bukti   : bash /root/soal18.sh test     (interface, urutan rule, counter)
# Hapus       : bash /root/soal18.sh reset    (copot aturan Soal 18 saja)
# ==============================================================================

GENDO_GW="10.78.4.129"              # next-hop Shigeru ke Gendo (Soal 3)
TERMINAL_NET="10.78.4.56/29"        # pengecualian: ping dari Switch-Terminal (Casper, Balthasar, Melchior)
CHAIN="SHIGERU_GERBANG"
DNS_SERVER="8.8.8.8"

set -eu

detect_if_gendo() {
    if [ -n "${IF_GENDO:-}" ]; then return 0; fi
    IF_GENDO="$(ip route get "$GENDO_GW" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')"
    if [ -z "$IF_GENDO" ]; then
        echo "[!] ERROR: tidak bisa menentukan interface ke Gendo ($GENDO_GW). Jalankan Soal 2 & 3 Shigeru dulu,"
        echo "    atau tentukan manual: IF_GENDO=eth0 bash /root/soal18.sh"
        exit 1
    fi
}

ensure_iptables() {
    if ! command -v iptables >/dev/null 2>&1; then
        echo "[*] iptables belum ada -> memasang..."
        grep -q "nameserver" /etc/resolv.conf 2>/dev/null || echo "nameserver $DNS_SERVER" > /etc/resolv.conf
        apt-get update || echo "[!] WARNING: sebagian repo gagal (cek jam host). Lanjut pakai indeks yang ada."
        DEBIAN_FRONTEND=noninteractive apt-get install -y iptables
    fi
    if ! iptables -S >/dev/null 2>&1; then
        echo "[!] iptables (nft) gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi
}

gendo_side_ip() {
    ip -4 -o addr show dev "$IF_GENDO" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n 1
}

remove_rules() {
    local r
    # Hapus semua jump ke chain ini (apa pun interface-nya, aman bila IF_GENDO berubah)
    for TBL_CHAIN in FORWARD INPUT; do
        while r="$(iptables -S "$TBL_CHAIN" | grep -- "-j $CHAIN\$" | head -n 1)" && [ -n "$r" ]; do
            # shellcheck disable=SC2086
            iptables ${r/-A/-D}
        done
    done
    iptables -F "$CHAIN" 2>/dev/null || true
    iptables -X "$CHAIN" 2>/dev/null || true
}

build_rules() {
    local myip
    myip="$(gendo_side_ip)"
    iptables -N "$CHAIN"
    iptables -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED \
        -m comment --comment "Soal18: balasan koneksi dari dalam zona" -j ACCEPT
    iptables -A "$CHAIN" -s "$TERMINAL_NET" -p icmp --icmp-type echo-request \
        -m comment --comment "Soal18: pengecualian ping dari Terminal" -j ACCEPT
    iptables -A "$CHAIN" -m comment --comment "Soal18: koneksi baru dari sisi Gendo ditolak" -j DROP

    # Ke host di zona (diteruskan Shigeru)
    iptables -I FORWARD 1 -i "$IF_GENDO" -j "$CHAIN"
    # Ke IP Shigeru sisi zona (10.78.4.81, 10.78.4.169); IP sisi Gendo sendiri tetap bisa dijangkau
    if [ -n "$myip" ]; then
        iptables -I INPUT 1 -i "$IF_GENDO" ! -d "$myip" -j "$CHAIN"
    fi
    echo "    -> semua yang masuk dari $IF_GENDO (sisi Gendo) -> $CHAIN [FORWARD & INPUT ! -d $myip]"
}

flush_icmp_conntrack() {
    # Ping lama (ID sama) yang sudah tercatat ESTABLISHED akan tetap lolos sampai kedaluwarsa.
    if command -v conntrack >/dev/null 2>&1; then
        conntrack -D -p icmp >/dev/null 2>&1 || true
        echo "    -> entri conntrack ICMP lama dibersihkan"
    else
        echo "    [i] conntrack tidak terpasang: ping lama dari luar bisa lolos <=30 dtk; mulai ping baru untuk uji."
    fi
}

show_status() {
    echo "============================================================"
    echo "Status Soal 18 - $(hostname) (Shigeru)"
    echo "============================================================"
    echo "Interface sisi Gendo : $IF_GENDO ($(gendo_side_ip))"
    ip -br a 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo "FORWARD (urutan):"; iptables -L FORWARD -n -v --line-numbers
    echo ""
    echo "INPUT (urutan):";   iptables -L INPUT -n -v --line-numbers
    echo "------------------------------------------------------------"
    echo "Counter $CHAIN (baris 2 = ping Terminal, baris 3 = DROP koneksi baru dari luar):"
    iptables -L "$CHAIN" -n -v --line-numbers 2>/dev/null || echo "    (belum terpasang)"
    echo "------------------------------------------------------------"
    echo "iptables -S (rule Soal 18):"
    iptables -S | grep -E "$CHAIN" || true
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 18: Gerbang Zona Monolith & Radar di Shigeru ==="
    detect_if_gendo
    ensure_iptables
    remove_rules
    build_rules
    flush_icmp_conntrack
    show_status
}

case "${1:-setup}" in
    test)  detect_if_gendo; show_status ;;
    reset) remove_rules; echo "[OK] Aturan Soal 18 dicopot (rule lain tidak disentuh)." ;;
    *)     setup ;;
esac
