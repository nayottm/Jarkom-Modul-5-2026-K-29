#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 16 (Pencuri yang Mencoba Setiap Pintu: Log + Tolak Dummy-Plug)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Tokyo3-Core 10.78.4.106 (Switch-Cmd, gateway Gendo)
# Aturan   : TCP dari Dummy-Plug (10.78.4.51) ke port 22, 23, 3306:
#              1) LOG --log-prefix "SCAN-NERV: "  (sekali per percobaan koneksi = paket SYN)
#              2) REJECT --reject-with tcp-reset   (pintu dibanting: klien langsung gagal)
#            Port 80 & 8080 (layanan Soal 8) tidak disentuh; klien lain tidak dicocokkan.
# Catatan  : Log kernel dari container biasanya tidak tampil (nf_log per-netns nonaktif),
#            jadi bukti utamanya counter rule LOG (iptables -L -v).
#            Rule Soal 15 (ICMP) tetap di urutan #1 INPUT; jump Soal 16 ditaruh tepat di bawahnya.
#            Idempotent: hanya chain T3_SCAN_NERV milik script ini yang dibuat ulang.
# Letakkan di : /root/soal16.sh (di container Tokyo3-Core)
# Jalankan    : bash /root/soal16.sh          (pasang aturan)
# Nol-kan     : bash /root/soal16.sh zero     (reset counter sebelum uji)
# Uji bukti   : bash /root/soal16.sh test     (urutan INPUT, counter LOG & REJECT, listener)
# Hapus       : bash /root/soal16.sh reset    (copot aturan Soal 16 saja)
# ==============================================================================

DUMMY_PLUG="10.78.4.51"
SENSITIVE_PORTS="22,23,3306"
LOG_PREFIX="SCAN-NERV: "
CHAIN="T3_SCAN_NERV"
SOAL15_CHAIN="T3_PING_LIMIT"
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

jump_rule() { echo "-s $DUMMY_PLUG -p tcp -m multiport --dports $SENSITIVE_PORTS -j $CHAIN"; }

remove_rules() {
    # shellcheck disable=SC2046
    while iptables -C INPUT $(jump_rule) 2>/dev/null; do
        iptables -D INPUT $(jump_rule)
    done
    iptables -F "$CHAIN" 2>/dev/null || true
    iptables -X "$CHAIN" 2>/dev/null || true
}

insert_position() {
    # Tepat di bawah jump Soal 15 bila ada (agar Soal 15 tetap #1), selain itu paling atas.
    local n
    n="$(iptables -L INPUT -n --line-numbers | awk -v c="$SOAL15_CHAIN" '$2==c {print $1; exit}')"
    if [ -n "$n" ]; then echo $(( n + 1 )); else echo 1; fi
}

build_rules() {
    iptables -N "$CHAIN"
    # 1) Catat setiap percobaan koneksi (SYN) dengan prefix huruf besar
    iptables -A "$CHAIN" -p tcp --syn -m comment --comment "Soal16: catat percobaan Dummy-Plug" \
        -j LOG --log-prefix "$LOG_PREFIX" --log-level 4
    # 2) Tolak seketika (RST) semua paket TCP ke port sensitif dari Dummy-Plug
    iptables -A "$CHAIN" -p tcp -m comment --comment "Soal16: banting pintu (RST)" \
        -j REJECT --reject-with tcp-reset
    local pos
    pos="$(insert_position)"
    # shellcheck disable=SC2046
    iptables -I INPUT "$pos" $(jump_rule)
    echo "    -> jump $CHAIN dipasang di INPUT #$pos (Dummy-Plug -> TCP $SENSITIVE_PORTS)"
}

show_status() {
    echo "============================================================"
    echo "Status Soal 16 - $(hostname) (Tokyo3-Core)"
    echo "============================================================"
    echo "Urutan chain INPUT:"
    iptables -L INPUT -n -v --line-numbers
    echo "------------------------------------------------------------"
    echo "Counter $CHAIN (baris 1 = LOG SCAN-NERV:, baris 2 = REJECT):"
    iptables -L "$CHAIN" -n -v -x --line-numbers 2>/dev/null || echo "    (belum terpasang)"
    echo "------------------------------------------------------------"
    echo "iptables -S (rule Soal 16):"
    iptables -S | grep -E "$CHAIN" || true
    echo "------------------------------------------------------------"
    echo "Listener layanan (harus ada 80 & 8080 dari Soal 8):"
    if command -v ss >/dev/null 2>&1; then ss -ltn | grep -E ":(80|8080)\b" || echo "    [!] port 80/8080 tidak LISTEN -> bash /root/soal8.sh"; fi
    echo "------------------------------------------------------------"
    echo "Log kernel (sering kosong/terlarang di container):"
    local KLOG
    KLOG="$(dmesg 2>/dev/null | grep "SCAN-NERV" | tail -n 5 || true)"
    if [ -n "$KLOG" ]; then
        printf '%s\n' "$KLOG"
    else
        echo "    (tidak terlihat/terlarang di container -> bukti = counter LOG di atas)"
    fi
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 16: Log & Tolak Dummy-Plug ke port $SENSITIVE_PORTS ==="
    ensure_iptables
    remove_rules
    build_rules
    show_status
}

case "${1:-setup}" in
    test)  show_status ;;
    zero)  iptables -Z "$CHAIN" && echo "[OK] Counter $CHAIN di-nol-kan."; iptables -L "$CHAIN" -n -v --line-numbers ;;
    reset) remove_rules; echo "[OK] Aturan Soal 16 dicopot (rule lain tidak disentuh)." ;;
    *)     setup ;;
esac
