#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 7 (Membangunkan MAGI: Magi-Melchior)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# IP Node  : 10.78.4.60/29 (Switch-Terminal, Gateway Fuyutsuki: 10.78.4.57)
# Listener : TCP 5000
# Letakkan di : /root/melchior.sh
# Jalankan    : bash /root/melchior.sh         (install iptables & nc + nyalakan listener)
# Lihat pesan : bash /root/melchior.sh log     (tampilkan pesan diterima di tiap port)
# Cek status  : bash /root/melchior.sh status  (cek versi iptables, nc, & port listening)
# Hentikan    : bash /root/melchior.sh stop    (hentikan listener nc)
# ==============================================================================

NODE_NAME="Magi-Melchior"
PORTS="5000"
DNS_SERVER="8.8.8.8"

set -eu

ensure_packages() {
    if [ ! -s /etc/resolv.conf ]; then
        echo "nameserver $DNS_SERVER" > /etc/resolv.conf
    fi

    echo "[*] Memeriksa paket wajib (iptables, netcat-traditional)..."
    NEED_INSTALL=""
    if ! command -v iptables >/dev/null 2>&1; then
        NEED_INSTALL="$NEED_INSTALL iptables"
    fi
    if ! command -v nc.traditional >/dev/null 2>&1 && ! dpkg -s netcat-traditional >/dev/null 2>&1; then
        NEED_INSTALL="$NEED_INSTALL netcat-traditional"
    fi

    if [ -n "$NEED_INSTALL" ]; then
        echo "[*] Memasang paket:$NEED_INSTALL ..."
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y $NEED_INSTALL
    else
        echo "    -> iptables dan netcat-traditional sudah terpasang."
    fi

    # Pastikan perintah 'nc' mengarah ke netcat-traditional (sesuai Modul §3.4)
    if command -v update-alternatives >/dev/null 2>&1 && [ -x /bin/nc.traditional ]; then
        update-alternatives --set nc /bin/nc.traditional >/dev/null 2>&1 || true
    fi

    # Fallback otomatis ke iptables-legacy jika nf_tables tidak didukung kernel host (Modul §14)
    if ! iptables -S >/dev/null 2>&1; then
        echo "[!] iptables nft gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    echo "    -> iptables : $(iptables --version)"
    echo "    -> netcat   : $(nc -h 2>&1 | head -n 1)"
}

stop_listeners() {
    echo "[*] Menghentikan listener lama (jika ada)..."
    for PORT in $PORTS; do
        PID_FILE="/tmp/nc_${PORT}.pid"
        if [ -f "$PID_FILE" ]; then
            OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
            if [ -n "$OLD_PID" ]; then
                kill "$OLD_PID" 2>/dev/null || true
            fi
            rm -f "$PID_FILE"
        fi
        pkill -f "nc -l -p ${PORT}" 2>/dev/null || true
        pkill -f "nc.traditional -l -p ${PORT}" 2>/dev/null || true
    done
    sleep 1
}

start_listeners() {
    stop_listeners
    echo "[*] Menyalakan listener TCP ($PORTS) di $NODE_NAME..."
    for PORT in $PORTS; do
        LOG_FILE="/tmp/nc_${PORT}.log"
        PID_FILE="/tmp/nc_${PORT}.pid"
        : > "$LOG_FILE"

        # Loop agar listener langsung hidup kembali setelah satu pesan selesai diterima
        # (memudahkan pengujian berulang Soal 7, 11, 12, dan 13 tanpa restart manual).
        (
            while true; do
                nc -l -p "$PORT" >> "$LOG_FILE" 2>&1
            done
        ) >/dev/null 2>&1 &
        echo "$!" > "$PID_FILE"
        echo "    -> Listener TCP port $PORT aktif (PID loop: $(cat "$PID_FILE"), log: $LOG_FILE)"
    done
    sleep 1
}

show_status() {
    echo "============================================================"
    echo "Status MAGI - $(hostname) ($NODE_NAME | 10.78.4.60)"
    echo "============================================================"
    echo "iptables : $(iptables --version 2>/dev/null || echo 'belum terpasang')"
    echo "netcat   : $(nc -h 2>&1 | head -n 1 || echo 'belum terpasang')"
    echo "------------------------------------------------------------"
    echo "Port TCP Listening (ss -tlnp):"
    ss -tlnp 2>/dev/null | grep -E "State|:(5000|5001)" || netstat -tlnp 2>/dev/null || ps aux | grep '[n]c -l'
    echo "============================================================"
}

show_logs() {
    echo "============================================================"
    echo "Pesan Diterima di $(hostname) ($NODE_NAME | 10.78.4.60)"
    echo "============================================================"
    echo "--- Log Port 5000 (/tmp/nc_5000.log) ---"
    if [ -s /tmp/nc_5000.log ]; then cat /tmp/nc_5000.log; else echo "(belum ada pesan masuk)"; fi
    echo "============================================================"
}

case "${1:-setup}" in
    log|logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    stop)
        stop_listeners
        echo "[OK] Listener dihentikan."
        ;;
    *)
        echo "=== Konfigurasi Soal 7: Membangunkan $NODE_NAME (TCP 5000) ==="
        ensure_packages
        start_listeners
        show_status
        echo "[i] Sekarang kirim pesan dari Lilith, lalu jalankan:"
        echo "    bash /root/melchior.sh log"
        ;;
esac
