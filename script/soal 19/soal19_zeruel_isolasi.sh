#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 19 (Isolasi Armisael: lapis tetangga satu switch di Zeruel)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Zeruel 10.78.4.82 — TIDAK ada konfigurasi di Armisael.
# Kenapa   : Armisael <-> Zeruel berada di Switch-Monolith yang sama; frame-nya diteruskan langsung
#            oleh switch dan tidak pernah lewat Shigeru. Selain memindah port Armisael ke VLAN lain
#            di Switch-Monolith, Zeruel sendiri membuang semua paket dari/ke Armisael.
# Aturan   : raw PREROUTING: DROP dari Armisael (IP & MAC) | raw OUTPUT: DROP ke Armisael.
#            Hanya alamat Armisael yang dicocokkan -> lalu lintas Zeruel lain tetap normal.
# Idempotent: hanya chain raw ZERUEL_ARMISAEL milik script ini yang dibuat ulang.
# Letakkan di : /root/soal19_isolasi.sh (di container Zeruel)
# Jalankan    : bash /root/soal19_isolasi.sh          (pasang)
# Uji bukti   : bash /root/soal19_isolasi.sh test     (rule & counter)
# Hapus       : bash /root/soal19_isolasi.sh reset
# ==============================================================================

ARMISAEL_IP="10.78.4.83"
ARMISAEL_MAC="02:42:de:21:ed:00"
CHAIN="ZERUEL_ARMISAEL"
MAC_COMMENT="Soal19: dari Armisael (MAC)"
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
    while iptables -t raw -C PREROUTING -m mac --mac-source "$ARMISAEL_MAC" -m comment --comment "$MAC_COMMENT" -j DROP 2>/dev/null; do
        iptables -t raw -D PREROUTING -m mac --mac-source "$ARMISAEL_MAC" -m comment --comment "$MAC_COMMENT" -j DROP
    done
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
    iptables -t raw -I PREROUTING 1 -m mac --mac-source "$ARMISAEL_MAC" -m comment --comment "$MAC_COMMENT" -j DROP
    echo "    -> raw: DROP semua dari/ke Armisael ($ARMISAEL_IP / $ARMISAEL_MAC) di Zeruel"
}

show_status() {
    echo "============================================================"
    echo "Status Soal 19 (lapis Zeruel) - $(hostname)"
    echo "============================================================"
    iptables -t raw -S
    echo "------------------------------------------------------------"
    iptables -t raw -L PREROUTING -n -v --line-numbers
    echo ""
    iptables -t raw -L "$CHAIN" -n -v --line-numbers 2>/dev/null || echo "    (belum terpasang)"
    echo "============================================================"
}

case "${1:-setup}" in
    test)  show_status ;;
    reset) remove_rules; echo "[OK] Aturan Soal 19 di Zeruel dicopot." ;;
    *)     echo "=== Soal 19: lapis isolasi Armisael di Zeruel ==="; ensure_iptables; remove_rules; build_rules; show_status ;;
esac
