#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 17 (Listener TCP 9000: Pen-Pen & Zeruel)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Dipakai di: Pen-Pen (10.78.3.194) dan Zeruel (10.78.4.82) — script yang SAMA.
#            (Listener Zeruel 9000 juga dipakai lagi di Soal 19.)
# Fungsi   : Loop netcat-traditional di background pada TCP 9000. Setiap koneksi dicatat ke
#            log: waktu, alamat lokal yang dituju, alamat pengirim, dan isi pesan. Membalas
#            "OK" generik (sama di kedua node -> pengirim tidak bisa membedakan).
#            Idempotent: listener lama dimatikan dulu. Tidak menyentuh port 80 Soal 8/14.
# Letakkan di : /root/soal17.sh (di container Pen-Pen dan di container Zeruel)
# Jalankan    : bash /root/soal17.sh          (nyalakan listener 9000)
# Lihat log   : bash /root/soal17.sh log      (pesan yang diterima)
# Matikan     : bash /root/soal17.sh stop
# ==============================================================================

PORT="9000"
LOG_DIR="/var/log/soal17"
LOG="$LOG_DIR/port$PORT.log"
RUN_DIR="/run/soal17"
DNS_SERVER="8.8.8.8"

set -eu

ensure_nc() {
    if command -v nc.traditional >/dev/null 2>&1; then return 0; fi
    echo "[*] Memasang netcat-traditional..."
    grep -q "nameserver" /etc/resolv.conf 2>/dev/null || echo "nameserver $DNS_SERVER" > /etc/resolv.conf
    apt-get update || echo "[!] WARNING: sebagian repo gagal (cek jam host). Lanjut pakai indeks yang ada."
    DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-traditional
    command -v nc.traditional >/dev/null 2>&1 || { echo "[!] ERROR: nc.traditional tidak tersedia."; exit 1; }
}

stop_listener() {
    if [ -f "$RUN_DIR/port$PORT.pid" ]; then
        kill -- "-$(cat "$RUN_DIR/port$PORT.pid")" 2>/dev/null || true
        rm -f "$RUN_DIR/port$PORT.pid"
    fi
    pkill -f "soal17-port$PORT " 2>/dev/null || true
    pkill -f "nc.traditional -n -v -l -p $PORT " 2>/dev/null || true
}

port_listening() {
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk '{print $4}' | grep -Eq "[:.]$1\$"
    else
        awk -v p="$(printf '%04X' "$1")" 'NR>1 { split($2,a,":"); if (a[2]==p && $4=="0A") f=1 } END { exit !f }' /proc/net/tcp
    fi
}

start_listener() {
    mkdir -p "$LOG_DIR" "$RUN_DIR"
    stop_listener
    sleep 0.3
    setsid nohup bash -c '
        PORT="$1"; NC_BIN="$2"; LOG="$3"; HOST="$4"
        while true; do
            OUT="$(printf "OK\n" | "$NC_BIN" -n -v -l -p "$PORT" 2>&1)" || sleep 1
            {
                echo "[$(date "+%F %T") UTC] diterima oleh $HOST"
                printf "%s\n" "$OUT" | grep -iv "^listening on" | sed "s/^/    /"
            } >> "$LOG"
        done
    ' "soal17-port$PORT" "$PORT" "$(command -v nc.traditional)" "$LOG" "$(hostname)" >/dev/null 2>&1 &
    echo $! > "$RUN_DIR/port$PORT.pid"
    sleep 1
    if port_listening "$PORT"; then
        echo "    [OK] $(hostname) LISTEN di TCP $PORT (log: $LOG)"
    else
        echo "    [!] port $PORT belum LISTEN, cek $LOG"
    fi
}

show_log() {
    echo "============================================================"
    echo "Log listener TCP $PORT di $(hostname) ($(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}'))"
    echo "============================================================"
    if [ -s "$LOG" ]; then cat "$LOG"; else echo "    (belum ada pesan masuk)"; fi
    echo "============================================================"
}

case "${1:-start}" in
    log)  show_log ;;
    stop) stop_listener; echo "[OK] listener $PORT dimatikan." ;;
    *)    echo "=== Soal 17: listener TCP $PORT di $(hostname) ==="; ensure_nc; start_listener ;;
esac
