#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Konfigurasi MAGI-CASPER (Soal 7 + Soal 11)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# IP Node  : 10.78.4.58/29 (Switch-Terminal, Gateway Fuyutsuki: 10.78.4.57)
# Mencakup :
#   - Soal 7  : Instalasi iptables & netcat-traditional + listener TCP 5000
#   - Soal 11 : Mode "Hantu" — DROP semua ping masuk (ICMP echo-request),
#               tetap izinkan Casper ping keluar & layanan TCP 5000 tetap hidup
# Letakkan di : /root/casper.sh
# Jalankan    : bash /root/casper.sh         (jalankan penuh Soal 7 + 11)
#               bash /root/casper.sh fw      (pasang firewall Soal 11 saja)
#               bash /root/casper.sh test    (cek iptables, port 5000, & ping Balthasar+Lilith)
#               bash /root/casper.sh log     (lihat pesan masuk TCP 5000)
#               bash /root/casper.sh stop    (hentikan listener nc)
# ==============================================================================

NODE_NAME="Magi-Casper"
PORTS="5000"
DNS_SERVER="8.8.8.8"
BALTHASAR_IP="10.78.4.59"
LILITH_IP="10.78.4.74"

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

    if command -v update-alternatives >/dev/null 2>&1 && [ -x /bin/nc.traditional ]; then
        update-alternatives --set nc /bin/nc.traditional >/dev/null 2>&1 || true
    fi

    if ! iptables -S >/dev/null 2>&1; then
        echo "[!] iptables nft gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi
}

stop_listeners() {
    for PORT in $PORTS; do
        PID_FILE="/tmp/nc_${PORT}.pid"
        if [ -f "$PID_FILE" ]; then
            OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
            [ -n "$OLD_PID" ] && kill "$OLD_PID" 2>/dev/null || true
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

setup_soal11() {
    echo "=== [Soal 11] Konfigurasi Mode Hantu (Block Incoming Ping) di $NODE_NAME ==="
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    # Reset aman chain INPUT (idempoten)
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT

    # 1. Loopback tetap jalan
    iptables -A INPUT -i lo -j ACCEPT
    # 2. Balasan koneksi keluar (termasuk echo-reply saat Casper mem-ping host lain)
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # 3. Pastikan layanan TCP 5000 tetap hidup
    iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
    # 4. Buang diam-diam (DROP) semua ping masuk (ICMP echo-request) dari siapa pun
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    echo "[OK] Firewall Soal 11 aktif: incoming ping di-DROP, outbound ping & TCP 5000 tetap jalan."
}

show_status() {
    echo "============================================================"
    echo "Status $NODE_NAME (10.78.4.58) — Soal 7 & Soal 11"
    echo "============================================================"
    echo "--- iptables -S INPUT ---"
    iptables -S INPUT
    echo "--- Counter INPUT (iptables -L INPUT -n -v --line-numbers) ---"
    iptables -L INPUT -n -v --line-numbers
    echo "--- Port TCP 5000 Listening ---"
    ss -tlnp 2>/dev/null | grep -E "State|:5000([^0-9]|$)" || ps aux | grep '[n]c -l'
    echo "============================================================"
}

show_logs() {
    echo "=== Log Pesan TCP 5000 (/tmp/nc_5000.log) ==="
    if [ -s /tmp/nc_5000.log ]; then cat /tmp/nc_5000.log; else echo "(belum ada pesan masuk)"; fi
}

run_test() {
    show_status
    echo ">>> Uji ping dari Casper ke Balthasar ($BALTHASAR_IP) — harus BERHASIL:"
    ping -c 3 -W 2 "$BALTHASAR_IP"
    echo ""
    echo ">>> Uji ping dari Casper ke Lilith ($LILITH_IP) — harus BERHASIL:"
    ping -c 3 -W 2 "$LILITH_IP"
    echo ""
    echo "[i] Sekarang uji dari konsol Balthasar & Lilith (harus GAGAL / 100% packet loss):"
    echo "    ping -c 3 -W 2 10.78.4.58"
    echo "[i] Uji layanan TCP 5000 tetap hidup dari Lilith / Balthasar:"
    echo "    echo 'uji soal 11 tcp 5000' | nc -w 3 10.78.4.58 5000"
}

case "${1:-setup}" in
    fw)
        setup_soal11
        show_status
        ;;
    test)
        run_test
        ;;
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
        ensure_packages
        start_listeners
        setup_soal11
        show_status
        ;;
esac
