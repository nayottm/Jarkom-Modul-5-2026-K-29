#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 15 (Banjir Ping di Pusat Komando: Rate-Limit Tokyo3-Core)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Tokyo3-Core 10.78.4.106 (Switch-Cmd, gateway Gendo)
# Aturan   : Ping MASUK (ICMP type 8 echo-request) dijawab maksimal PING_LIMIT/detik
#            (limit global, burst PING_BURST); kelebihannya DROP (dibuang, bukan ditolak).
# Kenapa aman:
#   - Hanya echo-request yang dicocokkan. Balasan atas ping KELUAR dari Tokyo3-Core adalah
#     echo-reply (type 0) -> tidak kena rule -> ping milik Tokyo3-Core sendiri tidak dibatasi.
#   - Rule ditaruh PALING ATAS INPUT. Bila ada rule ACCEPT ESTABLISHED di atasnya, ping beruntun
#     (ID ICMP sama) dianggap ESTABLISHED oleh conntrack dan lolos tanpa dibatasi.
#   - Hanya chain T3_PING_LIMIT milik script ini yang dibuat ulang (idempotent); rule Soal 8/16
#     dan policy INPUT tidak disentuh.
# Letakkan di : /root/soal15.sh (di container Tokyo3-Core)
# Jalankan    : bash /root/soal15.sh          (pasang rate-limit)
# Nol-kan     : bash /root/soal15.sh zero     (reset counter sebelum uji dari Lilith)
# Uji bukti   : bash /root/soal15.sh test     (urutan rule, counter, uji ping keluar sendiri)
# Hapus       : bash /root/soal15.sh reset    (copot aturan Soal 15 saja)
# ==============================================================================

PING_LIMIT="5/second"   # maksimal ping dijawab per detik
PING_BURST="5"          # token awal; laju jangka panjang tetap 5/detik
CHAIN="T3_PING_LIMIT"
OWN_PING_TARGET="10.78.4.105"   # gateway Gendo, untuk bukti ping keluar tidak dibatasi
DNS_SERVER="8.8.8.8"

set -eu

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

remove_rules() {
    while iptables -C INPUT -p icmp --icmp-type echo-request -j "$CHAIN" 2>/dev/null; do
        iptables -D INPUT -p icmp --icmp-type echo-request -j "$CHAIN"
    done
    iptables -F "$CHAIN" 2>/dev/null || true
    iptables -X "$CHAIN" 2>/dev/null || true
}

build_rules() {
    iptables -N "$CHAIN"
    iptables -A "$CHAIN" -m limit --limit "$PING_LIMIT" --limit-burst "$PING_BURST" \
        -m comment --comment "Soal15: jawab maks $PING_LIMIT" -j ACCEPT
    iptables -A "$CHAIN" -m comment --comment "Soal15: buang kelebihan ping" -j DROP
    # Paling atas INPUT, hanya echo-request (type 8)
    iptables -I INPUT 1 -p icmp --icmp-type echo-request -j "$CHAIN"
}

check_order() {
    local first
    first="$(iptables -S INPUT | grep '^-A INPUT' | head -n 1)"
    if printf '%s' "$first" | grep -q -- "-j $CHAIN"; then
        echo "[OK] Rule Soal 15 berada di urutan #1 INPUT (tidak dilewati rule ACCEPT lain)."
    else
        echo "[!] PERINGATAN: rule #1 INPUT bukan Soal 15:"
        echo "    $first"
        echo "    Jalankan ulang: bash /root/soal15.sh"
    fi
}

show_status() {
    echo "============================================================"
    echo "Status Soal 15 - $(hostname) (Tokyo3-Core)"
    echo "============================================================"
    echo "Urutan chain INPUT (iptables -L INPUT -n -v --line-numbers):"
    iptables -L INPUT -n -v --line-numbers
    echo "------------------------------------------------------------"
    check_order
    echo "------------------------------------------------------------"
    echo "Counter $CHAIN (baris 2 = pembuangan, harus naik saat ping rapat):"
    iptables -L "$CHAIN" -n -v --line-numbers 2>/dev/null || echo "    (belum terpasang)"
    echo "------------------------------------------------------------"
    echo "iptables -S (rule Soal 15):"
    iptables -S | grep -E "$CHAIN" || true
    echo "============================================================"
}

own_ping_test() {
    local before after
    before="$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/DROP/ {print $1}')"
    echo "=== Bukti ping KELUAR dari Tokyo3-Core tidak dibatasi ==="
    echo ">>> ping -i 0.1 -c 30 -q $OWN_PING_TARGET  (10 ping/detik, di atas batas)"
    ping -i 0.1 -c 30 -q -W 2 "$OWN_PING_TARGET" || true
    after="$(iptables -L "$CHAIN" -n -v -x 2>/dev/null | awk '/DROP/ {print $1}')"
    echo "    Counter DROP sebelum=$before sesudah=$after (harus sama: balasan type 0 tidak kena rule)"
}

setup() {
    echo "=== Konfigurasi Soal 15: Rate-Limit Ping Tokyo3-Core ($PING_LIMIT, burst $PING_BURST) ==="
    ensure_iptables
    remove_rules
    build_rules
    echo "    -> ICMP echo-request: ACCEPT maks $PING_LIMIT, sisanya DROP"
    show_status
}

case "${1:-setup}" in
    test)  show_status; own_ping_test ;;
    zero)  iptables -Z "$CHAIN" && echo "[OK] Counter $CHAIN di-nol-kan."; iptables -L "$CHAIN" -n -v --line-numbers ;;
    reset) remove_rules; echo "[OK] Aturan Soal 15 dicopot (rule lain tidak disentuh)." ;;
    *)     setup ;;
esac
