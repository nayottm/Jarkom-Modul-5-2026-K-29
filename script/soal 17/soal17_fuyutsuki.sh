#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 17 (Sihir Hitam di Jalur Paket: DNAT Casper->Zeruel ke Pen-Pen)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Fuyutsuki (gateway Switch-Terminal 10.78.4.57)
# Aturan   : nat PREROUTING: TCP dari Magi-Casper (10.78.4.58) ke Zeruel (10.78.4.82)
#            -> DNAT ke Pen-Pen (10.78.3.194), port tetap sama (mis. 9000).
#            Ping (ICMP) TIDAK dicocokkan -> tetap ke Zeruel.
# Kenapa cukup DNAT (tanpa SNAT):
#   Balasan Pen-Pen ke Casper lewat Maya -> Fuyutsuki (default route Maya = Fuyutsuki), jadi
#   melewati router yang sama. conntrack Fuyutsuki otomatis membalik alamat sumber balasan
#   10.78.3.194 -> 10.78.4.82, sehingga Casper melihat balasan dari Zeruel ("tidak sadar").
#   SNAT baru perlu bila jalur balik tidak lewat Fuyutsuki (asimetris).
# Idempotent: hanya chain nat FUYU_SIHIR milik script ini yang dibuat ulang; rule lain aman.
# Letakkan di : /root/soal17.sh (di container Fuyutsuki)
# Jalankan    : bash /root/soal17.sh          (pasang DNAT + bersihkan conntrack lama)
# Uji bukti   : bash /root/soal17.sh test     (rule nat, counter, tabel conntrack)
# Hapus       : bash /root/soal17.sh reset    (copot aturan Soal 17 saja)
# ==============================================================================

CASPER="10.78.4.58"
ZERUEL="10.78.4.82"
PENPEN="10.78.3.194"
CHAIN="FUYU_SIHIR"
DNS_SERVER="8.8.8.8"

set -eu

ensure_tools() {
    local need=""
    command -v iptables  >/dev/null 2>&1 || need="$need iptables"
    command -v conntrack >/dev/null 2>&1 || need="$need conntrack"
    if [ -n "$need" ]; then
        echo "[*] Memasang:$need"
        grep -q "nameserver" /etc/resolv.conf 2>/dev/null || echo "nameserver $DNS_SERVER" > /etc/resolv.conf
        apt-get update || echo "[!] WARNING: sebagian repo gagal (cek jam host). Lanjut pakai indeks yang ada."
        # shellcheck disable=SC2086
        DEBIAN_FRONTEND=noninteractive apt-get install -y $need || true
    fi
    command -v iptables >/dev/null 2>&1 || { echo "[!] ERROR: iptables tidak tersedia."; exit 1; }
    if ! iptables -t nat -S >/dev/null 2>&1; then
        echo "[!] iptables (nft) gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi
    command -v conntrack >/dev/null 2>&1 || echo "[!] WARNING: conntrack belum terpasang -> bukti pakai /proc/net/nf_conntrack bila ada."
}

remove_rules() {
    while iptables -t nat -C PREROUTING -s "$CASPER" -d "$ZERUEL" -p tcp -j "$CHAIN" 2>/dev/null; do
        iptables -t nat -D PREROUTING -s "$CASPER" -d "$ZERUEL" -p tcp -j "$CHAIN"
    done
    iptables -t nat -F "$CHAIN" 2>/dev/null || true
    iptables -t nat -X "$CHAIN" 2>/dev/null || true
}

build_rules() {
    iptables -t nat -N "$CHAIN"
    iptables -t nat -A "$CHAIN" -p tcp -m comment --comment "Soal17: Casper->Zeruel dialihkan ke Pen-Pen" \
        -j DNAT --to-destination "$PENPEN"
    iptables -t nat -I PREROUTING 1 -s "$CASPER" -d "$ZERUEL" -p tcp -j "$CHAIN"
    echo "    -> TCP $CASPER -> $ZERUEL  ==DNAT==>  $PENPEN (port tetap); ICMP tidak dialihkan"
}

flush_old_conntrack() {
    # Keputusan NAT dibuat di paket pertama koneksi; entri lama Casper->Zeruel harus dibuang
    if command -v conntrack >/dev/null 2>&1; then
        conntrack -D -p tcp -s "$CASPER" -d "$ZERUEL" >/dev/null 2>&1 || true
        echo "    -> entri conntrack lama TCP $CASPER->$ZERUEL dibersihkan"
    fi
}

show_conntrack() {
    echo "Tabel conntrack (koneksi dari Casper):"
    if command -v conntrack >/dev/null 2>&1; then
        conntrack -L -s "$CASPER" 2>/dev/null || true
        echo ""
        echo "Hanya yang dialihkan (--dst-nat):"
        conntrack -L -s "$CASPER" --dst-nat 2>/dev/null || true
    elif [ -r /proc/net/nf_conntrack ]; then
        grep "src=$CASPER" /proc/net/nf_conntrack || echo "    (kosong)"
    else
        echo "    (conntrack tidak tersedia)"
    fi
    echo "  Cara baca: arah asli  src=$CASPER dst=$ZERUEL  |  arah balas  src=$PENPEN dst=$CASPER"
    echo "  -> paket menuju Zeruel, tapi yang menjawab Pen-Pen; Fuyutsuki membalik alamatnya."
}

show_status() {
    echo "============================================================"
    echo "Status Soal 17 - $(hostname) (Fuyutsuki)"
    echo "============================================================"
    echo "iptables -t nat -S (rule Soal 17):"
    iptables -t nat -S | grep -E "$CHAIN" || echo "    (belum terpasang)"
    echo "------------------------------------------------------------"
    echo "Counter nat PREROUTING & $CHAIN (pkts = koneksi yang dialihkan):"
    iptables -t nat -L PREROUTING -n -v --line-numbers
    iptables -t nat -L "$CHAIN" -n -v --line-numbers 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo "Keputusan rute Fuyutsuki: Pen-Pen via $(ip route get "$PENPEN" 2>/dev/null | head -n 1)"
    echo "------------------------------------------------------------"
    show_conntrack
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 17: DNAT diam-diam di Fuyutsuki ==="
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
        echo "[!] ip_forward=0 -> jalankan dulu Soal 2 Fuyutsuki (bash /root/soal2.sh)."
        exit 1
    fi
    ensure_tools
    remove_rules
    build_rules
    flush_old_conntrack
    show_status
}

case "${1:-setup}" in
    test)  show_status ;;
    reset) remove_rules; flush_old_conntrack; echo "[OK] Aturan Soal 17 dicopot (rule lain tidak disentuh)." ;;
    *)     setup ;;
esac
