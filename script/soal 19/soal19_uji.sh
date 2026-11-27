#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 19 (Listener TCP 9000 + Bukti Uji Isolasi Armisael)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Dipakai di: Armisael, Zeruel, Lilith (script SAMA; peran dikenali dari IP eth0).
#   Mode listen : nyalakan listener TCP 9000 (lewati bila port 9000 sudah dipakai, mis. Soal 17).
#   Mode uji    : Armisael -> Seele(TCP 53), Zeruel(9000), Lilith(9000), gateway : harus GAGAL
#                 Zeruel   -> Seele(TCP 53), Lilith(9000)                       : harus BERHASIL
#                 (Zeruel -> Armisael juga diuji: harus GAGAL)
#   Script ini TIDAK memasang isolasi apa pun (isolasi ada di Switch-Monolith/Shigeru/Zeruel).
# PENTING  : Jalankan "listen" di Armisael SEBELUM isolasi aktif (butuh apt untuk netcat).
# Letakkan di : /root/soal19.sh (di container Armisael, Zeruel, dan Lilith)
# Jalankan    : bash /root/soal19.sh listen   (listener 9000)
#               bash /root/soal19.sh          (uji sesuai peran node)
#               bash /root/soal19.sh log      (pesan yang diterima listener)
# ==============================================================================

ARMISAEL="10.78.4.83"
ZERUEL="10.78.4.82"
LILITH="10.78.4.74"
SEELE="8.8.8.8"
GATEWAY="10.78.4.81"
PORT="9000"
LOG_DIR="/var/log/soal19"
LOG="$LOG_DIR/port$PORT.log"
WAIT=3

set -u

MYIP="$(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"
NC_BIN="$(command -v nc.traditional || command -v nc || true)"

port_listening() {
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk '{print $4}' | grep -Eq "[:.]$1\$"
    else
        awk -v p="$(printf '%04X' "$1")" 'NR>1 { split($2,a,":"); if (a[2]==p && $4=="0A") f=1 } END { exit !f }' /proc/net/tcp
    fi
}

start_listener() {
    if port_listening "$PORT"; then
        echo "[OK] TCP $PORT sudah LISTEN di $(hostname) (mis. listener Soal 17) -> dipakai apa adanya."
        return 0
    fi
    if ! command -v nc.traditional >/dev/null 2>&1; then
        echo "[*] Memasang netcat-traditional..."
        grep -q nameserver /etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.8.8" > /etc/resolv.conf
        apt-get update || echo "[!] WARNING: sebagian repo gagal, lanjut."
        DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-traditional || true
    fi
    command -v nc.traditional >/dev/null 2>&1 || { echo "[!] ERROR: nc.traditional tidak tersedia."; exit 1; }
    mkdir -p "$LOG_DIR"
    pkill -f "soal19-port$PORT " 2>/dev/null || true
    setsid nohup bash -c '
        PORT="$1"; NC_BIN="$2"; LOG="$3"; HOST="$4"
        while true; do
            OUT="$(printf "OK\n" | "$NC_BIN" -n -v -l -p "$PORT" 2>&1)" || sleep 1
            { echo "[$(date "+%F %T") UTC] diterima oleh $HOST"; printf "%s\n" "$OUT" | grep -iv "^listening on" | sed "s/^/    /"; } >> "$LOG"
        done
    ' "soal19-port$PORT" "$PORT" "$(command -v nc.traditional)" "$LOG" "$(hostname)" >/dev/null 2>&1 &
    sleep 1
    if port_listening "$PORT"; then echo "[OK] $(hostname) LISTEN di TCP $PORT (log: $LOG)"; else echo "[!] port $PORT belum LISTEN"; fi
}

do_ping() {   # $1 target $2 label $3 harapan
    local OUT RC RES
    echo ">>> ping -c 3 -W 2 $1   ($2, harapan: $3)"
    OUT="$(ping -c 3 -W 2 "$1" 2>&1)"; RC=$?
    printf '%s\n' "$OUT" | tail -n 2 | sed 's/^/    | /'
    if [ "$RC" -eq 0 ]; then RES="BERHASIL"; else RES="GAGAL"; fi
    [ "$RES" = "$3" ] && echo "    [OK] $RES sesuai harapan" || echo "    [!] $RES (harapan $3)"
    echo ""
}

do_nc() {     # $1 target $2 port $3 label $4 harapan
    local OUT RC RES T0 T1
    echo ">>> nc -n -v -w $WAIT $1 $2   ($3, harapan: $4)"
    T0=$(date +%s%N)
    if [ -n "$NC_BIN" ]; then
        OUT="$(printf 'pesan dari %s\n' "$(hostname)" | "$NC_BIN" -n -v -w "$WAIT" -q 1 "$1" "$2" 2>&1)"; RC=$?
    else
        OUT="$(timeout "$WAIT" bash -c "exec 3<>/dev/tcp/$1/$2 && echo terhubung" 2>&1)"; RC=$?
        OUT="(nc tidak ada, pakai /dev/tcp) $OUT"
    fi
    T1=$(date +%s%N)
    printf '%s\n' "$OUT" | sed 's/^/    | /'
    echo "    exit=$RC durasi=$(( (T1 - T0) / 1000000 )) ms"
    if [ "$RC" -eq 0 ]; then RES="BERHASIL"; else RES="GAGAL"; fi
    [ "$RES" = "$4" ] && echo "    [OK] $RES sesuai harapan" || echo "    [!] $RES (harapan $4)"
    echo ""
}

run_test() {
    echo "============================================================"
    echo "Uji Soal 19 dari $(hostname) ($MYIP)"
    echo "Jam: $(date -u '+%H:%M:%S') UTC | $(date -u -d '+7 hours' '+%H:%M:%S') WIB"
    echo "============================================================"
    case "$MYIP" in
        "$ARMISAEL")
            do_ping "$SEELE"   "Armisael -> Seele"   "GAGAL"; do_nc "$SEELE"  53    "Armisael -> Seele"  "GAGAL"
            do_ping "$ZERUEL"  "Armisael -> Zeruel"  "GAGAL"; do_nc "$ZERUEL" "$PORT" "Armisael -> Zeruel" "GAGAL"
            do_ping "$LILITH"  "Armisael -> Lilith"  "GAGAL"; do_nc "$LILITH" "$PORT" "Armisael -> Lilith" "GAGAL"
            do_ping "$GATEWAY" "Armisael -> gateway Shigeru" "GAGAL" ;;
        "$ZERUEL")
            do_ping "$SEELE"   "Zeruel -> Seele"     "BERHASIL"; do_nc "$SEELE"  53    "Zeruel -> Seele"  "BERHASIL"
            do_ping "$LILITH"  "Zeruel -> Lilith"    "BERHASIL"; do_nc "$LILITH" "$PORT" "Zeruel -> Lilith" "BERHASIL"
            do_ping "$ARMISAEL" "Zeruel -> Armisael (ikut terisolasi)" "GAGAL" ;;
        *)
            echo "[i] Node ini ($MYIP) hanya penyedia listener. Uji dijalankan di Armisael & Zeruel." ;;
    esac
    echo "[i] Counter: Shigeru 'bash /root/soal19.sh test', Zeruel 'bash /root/soal19_isolasi.sh test'"
    echo "============================================================"
}

case "${1:-uji}" in
    listen) start_listener ;;
    log)    if [ -s "$LOG" ]; then cat "$LOG"; elif [ -s /var/log/soal17/port9000.log ]; then cat /var/log/soal17/port9000.log; else echo "(belum ada pesan masuk)"; fi ;;
    *)      run_test ;;
esac
