#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 20 (Uji Kebakaran Geofront)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Fungsi   :
#   1. Simpan rule aktif dengan iptables-save ke /root/<nama>.rules
#   2. Hapus semua rule iptables (filter & nat) serta rute yang ditambahkan sendiri
#   3. Pulihkan 2x berturut-turut dengan iptables-restore + /root/<nama>.sh
#   4. Bandingkan jumlah baris iptables -S, iptables -t nat -S, dan ip route
#      antara kondisi awal, pemulihan #1, dan pemulihan #2 (harus identik/tidak dobel)
#
# Letakkan di : /root/soal20_uji.sh
# Penggunaan  :
#   bash /root/soal20_uji.sh save    <nama> [/root/<nama>.sh]
#   bash /root/soal20_uji.sh destroy <nama>
#   bash /root/soal20_uji.sh recover <nama> [/root/<nama>.sh]
#   bash /root/soal20_uji.sh full    <nama> [/root/<nama>.sh]
#
# Contoh (3 node bagian Arul):
#   Di Gendou         : bash /root/soal20_uji.sh full gendo /root/gendo.sh
#   Di Magi-Casper    : bash /root/soal20_uji.sh full casper /root/casper.sh
#   Di Magi-Balthasar : bash /root/soal20_uji.sh full balthasar /root/balthasar.sh
# ==============================================================================

set -eu

MODE="${1:-help}"
NAME="${2:-}"
RESTORE_SCRIPT="${3:-}"

usage() {
    echo "Penggunaan:"
    echo "  bash /root/soal20_uji.sh save    <nama> [/root/<nama>.sh]"
    echo "  bash /root/soal20_uji.sh destroy <nama>"
    echo "  bash /root/soal20_uji.sh recover <nama> [/root/<nama>.sh]"
    echo "  bash /root/soal20_uji.sh full    <nama> [/root/<nama>.sh]"
    echo ""
    echo "Contoh:"
    echo "  bash /root/soal20_uji.sh full gendo /root/gendo.sh"
    echo "  bash /root/soal20_uji.sh full casper /root/casper.sh"
    echo "  bash /root/soal20_uji.sh full balthasar /root/balthasar.sh"
}

check_args() {
    if [ -z "$NAME" ]; then
        echo "[!] ERROR: Parameter <nama> wajib diisi (misal: gendo, casper, balthasar)."
        usage
        exit 1
    fi
    RULES_FILE="/root/${NAME}.rules"
    BASE_FILE="/tmp/soal20_${NAME}.baseline"
    if [ -z "$RESTORE_SCRIPT" ]; then
        RESTORE_SCRIPT="/root/${NAME}.sh"
    fi
}

ensure_iptables() {
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null 2>&1 || true
    fi
    # Inisialisasi tabel nat agar konsisten muncul pada iptables-save & iptables -t nat -S
    iptables -t nat -S >/dev/null 2>&1 || true
}

count_filter() { iptables -S | wc -l | tr -d ' '; }
count_nat()    { iptables -t nat -S | wc -l | tr -d ' '; }
count_route()  { ip route show | wc -l | tr -d ' '; }

print_snapshot() {
    LABEL="$1"
    F_CNT="$(count_filter)"
    N_CNT="$(count_nat)"
    R_CNT="$(count_route)"
    echo "------------------------------------------------------------"
    echo "[$LABEL] Node: $(hostname)"
    echo "  Jumlah baris iptables -S        : $F_CNT"
    echo "  Jumlah baris iptables -t nat -S : $N_CNT"
    echo "  Jumlah baris ip route           : $R_CNT"
    echo "--- iptables -S ---"
    iptables -S
    echo "--- iptables -t nat -S ---"
    iptables -t nat -S
    echo "--- ip route ---"
    ip route show
    echo "------------------------------------------------------------"
}

do_save() {
    ensure_iptables
    echo "============================================================"
    echo "[TAHAP 1 - SAVE] Menyimpan rule ke $RULES_FILE"
    echo "============================================================"
    iptables-save > "$RULES_FILE"
    F0="$(count_filter)"
    N0="$(count_nat)"
    R0="$(count_route)"
    printf '%s %s %s\n' "$F0" "$N0" "$R0" > "$BASE_FILE"
    echo "[OK] Tersimpan: $RULES_FILE ($(wc -l < "$RULES_FILE" | tr -d ' ') baris)"
    print_snapshot "KONDISI AWAL (BASELINE)"
}

do_destroy() {
    ensure_iptables
    echo "============================================================"
    echo "[TAHAP 2 - DESTROY] Menghapus rule iptables (filter & nat) dan rute statis"
    echo "============================================================"
    # 1. Reset policy & hapus seluruh rule iptables (filter & nat)
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X

    # 2. Hapus rute yang ditambahkan sendiri (pertahankan rute proto kernel / link langsung)
    NODE_HOST="$(hostname | tr '[:upper:]' '[:lower:]')"
    NAME_LOW="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]')"

    if [ "$NAME_LOW" = "gendo" ] || [ "$NAME_LOW" = "gendou" ] || printf '%s' "$NODE_HOST" | grep -q "gendo"; then
        echo "[*] Mode Router Gendou: menghapus seluruh rute statis internal (10.78.* via ...),"
        echo "    mempertahankan rute link langsung (proto kernel) dan default DHCP dari NAT1."
        ip route show | awk '/ via / && /^10\.78\./ {print $1}' | while read -r DST; do
            [ -n "$DST" ] && ip route del "$DST" 2>/dev/null || true
        done
    else
        echo "[*] Menghapus seluruh rute statis (default & subnet dengan 'via'),"
        echo "    mempertahankan rute link langsung (proto kernel)."
        ip route show | awk '/ via / {print $1}' | while read -r DST; do
            [ -n "$DST" ] && ip route del "$DST" 2>/dev/null || true
        done
    fi

    print_snapshot "KONDISI SETELAH DIHAPUS (HANCUR)"
}

do_recover() {
    ensure_iptables
    if [ ! -s "$RULES_FILE" ]; then
        echo "[!] ERROR: File $RULES_FILE tidak ditemukan atau kosong. Jalankan tahap 'save' dulu."
        exit 1
    fi
    if [ ! -f "$RESTORE_SCRIPT" ]; then
        echo "[!] ERROR: Script pemulihan rute $RESTORE_SCRIPT tidak ditemukan."
        exit 1
    fi

    echo "============================================================"
    echo "[TAHAP 3A - PEMULIHAN #1] iptables-restore + bash $RESTORE_SCRIPT"
    echo "============================================================"
    iptables-restore < "$RULES_FILE"
    bash "$RESTORE_SCRIPT"
    F1="$(count_filter)"
    N1="$(count_nat)"
    R1="$(count_route)"
    print_snapshot "SETELAH PEMULIHAN #1"

    echo "============================================================"
    echo "[TAHAP 3B - PEMULIHAN #2] iptables-restore + bash $RESTORE_SCRIPT"
    echo "============================================================"
    iptables-restore < "$RULES_FILE"
    bash "$RESTORE_SCRIPT"
    F2="$(count_filter)"
    N2="$(count_nat)"
    R2="$(count_route)"
    print_snapshot "SETELAH PEMULIHAN #2"

    echo "============================================================"
    echo "RINGKASAN VERIFIKASI IDEMPOTENSI — $(hostname) ($NAME)"
    echo "============================================================"
    if [ -f "$BASE_FILE" ]; then
        read -r F0 N0 R0 < "$BASE_FILE"
        printf "%-28s | %-8s | %-11s | %-11s\n" "Metrik" "Awal" "Pulih #1" "Pulih #2"
        printf "%-28s-+-%-8s-+-%-11s-+-%-11s\n" "----------------------------" "--------" "-----------" "-----------"
        printf "%-28s | %-8s | %-11s | %-11s\n" "Baris iptables -S" "$F0" "$F1" "$F2"
        printf "%-28s | %-8s | %-11s | %-11s\n" "Baris iptables -t nat -S" "$N0" "$N1" "$N2"
        printf "%-28s | %-8s | %-11s | %-11s\n" "Baris ip route" "$R0" "$R1" "$R2"
    else
        printf "%-28s | %-11s | %-11s\n" "Metrik" "Pulih #1" "Pulih #2"
        printf "%-28s-+-%-11s-+-%-11s\n" "----------------------------" "-----------" "-----------"
        printf "%-28s | %-11s | %-11s\n" "Baris iptables -S" "$F1" "$F2"
        printf "%-28s | %-11s | %-11s\n" "Baris iptables -t nat -S" "$N1" "$N2"
        printf "%-28s | %-11s | %-11s\n" "Baris ip route" "$R1" "$R2"
    fi
    echo "============================================================"

    if [ "$F1" = "$F2" ] && [ "$N1" = "$N2" ] && [ "$R1" = "$R2" ]; then
        echo "[OK] LULUS: Jumlah baris filter, nat, dan rute IDENTIK pada pemulihan #1 & #2 (tidak dobel)."
    else
        echo "[GAGAL] Jumlah baris BERBEDA! Cek apakah $RESTORE_SCRIPT sudah membersihkan rule lama (iptables -F / -t nat -F) dan memakai 'ip route replace'."
        exit 1
    fi
}

case "$MODE" in
    save)
        check_args
        do_save
        ;;
    destroy)
        check_args
        do_destroy
        ;;
    recover)
        check_args
        do_recover
        ;;
    full)
        check_args
        do_save
        do_destroy
        do_recover
        ;;
    *)
        usage
        ;;
esac
