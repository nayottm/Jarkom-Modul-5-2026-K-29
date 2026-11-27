#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 19 (Hukuman Sang Pengkhianat: Isolasi Armisael dari Gateway)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Shigeru (gateway Switch-Monolith 10.78.4.81) — TIDAK ada konfigurasi di Armisael.
# Aturan   : Tabel raw (diproses SEBELUM filter & conntrack), chain SHIGERU_ARMISAEL:
#              PREROUTING: DROP paket DARI Armisael (IP 10.78.4.83 ATAU MAC-nya) dan KE Armisael
#              OUTPUT    : DROP paket Shigeru sendiri KE Armisael
#            -> Armisael tidak bisa ke gateway, ke luar (Seele, Lilith), dan tidak bisa dihubungi.
#            Dicocokkan juga lewat MAC: bila pengkhianat mengganti IP-nya, tetap terblokir.
# Kenapa raw: tidak terpengaruh urutan rule filter Soal 18 (mis. ACCEPT ping Terminal /
#            ESTABLISHED) — raw selalu dievaluasi lebih dulu.
# Batas    : Lalu lintas Armisael <-> Zeruel (satu switch) TIDAK lewat Shigeru (diteruskan langsung
#            oleh Switch-Monolith di layer 2). Itu ditutup di Switch-Monolith (VLAN port Armisael)
#            dan/atau /root/soal19.sh di Zeruel.
# Idempotent: hanya chain raw SHIGERU_ARMISAEL milik script ini yang dibuat ulang.
# Letakkan di : /root/soal19.sh (di container Shigeru)
# Jalankan    : bash /root/soal19.sh          (pasang isolasi)
# Uji bukti   : bash /root/soal19.sh test     (rule raw & counter)
# Hapus       : bash /root/soal19.sh reset    (copot aturan Soal 19 saja)
# ==============================================================================

ARMISAEL_IP="10.78.4.83"
ARMISAEL_MAC="02:42:de:21:ed:00"   # mac_address node Armisael di project GNS3 (cek: ip link di Armisael)
CHAIN="SHIGERU_ARMISAEL"
DNS_SERVER="8.8.8.8"

set -eu

ensure_iptables() {
    if ! command -v iptables >/dev/null 2>&1; then
        echo "[*] iptables belum ada -> memasang..."
        grep -q "nameserver" /etc/resolv.conf 2>/dev/null || echo "nameserver $DNS_SERVER" > /etc/resolv.conf
        apt-get update || echo "[!] WARNING: sebagian repo gagal (cek jam host). Lanjut pakai indeks yang ada."
        DEBIAN_FRONTEND=noninteractive apt-get install -y iptables
    fi
    if ! iptables -t raw -S >/dev/null 2>&1; then
        echo "[!] iptables (nft) gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi
}

remove_rules() {
    local base
    for base in PREROUTING OUTPUT; do
        while iptables -t raw -C "$base" -j "$CHAIN" 2>/dev/null; do
            iptables -t raw -D "$base" -j "$CHAIN"
        done
    done
    iptables -t raw -F "$CHAIN" 2>/dev/null || true
    iptables -t raw -X "$CHAIN" 2>/dev/null || true
}

build_rules() {
    iptables -t raw -N "$CHAIN"
    iptables -t raw -A "$CHAIN" -s "$ARMISAEL_IP" -m comment --comment "Soal19: dari Armisael (IP)" -j DROP
    iptables -t raw -A "$CHAIN" -d "$ARMISAEL_IP" -m comment --comment "Soal19: ke Armisael" -j DROP
    iptables -t raw -I PREROUTING 1 -j "$CHAIN"
    iptables -t raw -I OUTPUT 1 -j "$CHAIN"
    # MAC hanya ada di paket masuk (PREROUTING) -> rule terpisah langsung di PREROUTING
    iptables -t raw -I PREROUTING 1 -m mac --mac-source "$ARMISAEL_MAC" \
        -m comment --comment "Soal19: dari Armisael (MAC, walau IP diganti)" -j DROP
    echo "    -> raw PREROUTING/OUTPUT: DROP semua dari/ke Armisael ($ARMISAEL_IP / $ARMISAEL_MAC)"
}

remove_mac_rule() {
    while iptables -t raw -C PREROUTING -m mac --mac-source "$ARMISAEL_MAC" \
            -m comment --comment "Soal19: dari Armisael (MAC, walau IP diganti)" -j DROP 2>/dev/null; do
        iptables -t raw -D PREROUTING -m mac --mac-source "$ARMISAEL_MAC" \
            -m comment --comment "Soal19: dari Armisael (MAC, walau IP diganti)" -j DROP
    done
}

show_status() {
    echo "============================================================"
    echo "Status Soal 19 - $(hostname) (Shigeru)"
    echo "============================================================"
    echo "iptables -t raw -S:"
    iptables -t raw -S
    echo "------------------------------------------------------------"
    echo "Counter raw PREROUTING (baris MAC) & $CHAIN:"
    iptables -t raw -L PREROUTING -n -v --line-numbers
    echo ""
    iptables -t raw -L "$CHAIN" -n -v --line-numbers 2>/dev/null || echo "    (belum terpasang)"
    echo "------------------------------------------------------------"
    echo "[i] Armisael <-> Zeruel tidak lewat Shigeru: cek counter di Zeruel (bash /root/soal19.sh test)"
    echo "    dan VLAN port Armisael di Switch-Monolith."
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 19: Isolasi Armisael di Shigeru ==="
    ensure_iptables
    remove_mac_rule
    remove_rules
    build_rules
    show_status
}

case "${1:-setup}" in
    test)  show_status ;;
    reset) remove_mac_rule; remove_rules; echo "[OK] Aturan Soal 19 dicopot (rule lain tidak disentuh)." ;;
    *)     setup ;;
esac
