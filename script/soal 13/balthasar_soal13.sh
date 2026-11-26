#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Konfigurasi Lengkap MAGI-BALTHASAR (Soal 7 & 13)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# IP Node  : 10.78.4.59/29 (Switch-Terminal, Gateway Fuyutsuki: 10.78.4.57)
# Mencakup :
#   - Soal 7  : Instalasi iptables & netcat-traditional + listener TCP 5000 & 5001
#   - Soal 13 : Brankas Balthasar — hanya Magi-Casper (10.78.4.58/32) & semua Pilot
#               (Switch-Cage 10.78.4.64/29) yang boleh akses TCP 5000 & 5001;
#               node lain (termasuk satu switch) ditolak seketika (REJECT tcp-reset);
#               lalu lintas lain & ping 8.8.8.8 tetap berjalan normal.
# Letakkan di : /root/balthasar.sh
# Jalankan    : bash /root/balthasar.sh         (setup penuh Soal 7 + 13)
#               bash /root/balthasar.sh fw      (pasang/perbaiki firewall Soal 13 saja)
#               bash /root/balthasar.sh test    (cek iptables, port 5000/5001, & ping 8.8.8.8)
#               bash /root/balthasar.sh log     (lihat pesan masuk port 5000 & 5001)
#               bash /root/balthasar.sh status  (cek rule & counter iptables)
#               bash /root/balthasar.sh stop    (hentikan listener nc)
# ==============================================================================

NODE_NAME="Magi-Balthasar"
PORTS="5000 5001"
DNS_SERVER="8.8.8.8"
CASPER_IP="10.78.4.58/32"
PILOT_NET="10.78.4.64/29"   # Switch-Cage (Misato: Unit-00, Unit-01, Unit-02)

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

setup_soal13_firewall() {
    echo "=== [Soal 13] Brankas Balthasar di $NODE_NAME ==="
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    # 1. Reset aman chain INPUT (policy tetap ACCEPT agar lalu lintas lain tidak terganggu)
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT

    # 2. Izin dasar: loopback & balasan koneksi yang dibuka oleh Balthasar (ping 8.8.8.8, dll.)
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # 3. Whitelist TCP 5000 & 5001: hanya Magi-Casper dan semua Pilot (Switch-Cage)
    for PORT in $PORTS; do
        iptables -A INPUT -p tcp -s "$CASPER_IP" --dport "$PORT" -j ACCEPT
        iptables -A INPUT -p tcp -s "$PILOT_NET" --dport "$PORT" -j ACCEPT
    done

    # 4. Tolak SEKETIKA (TCP RST, bukan DROP/timeout) untuk semua node lain di port 5000 & 5001
    for PORT in $PORTS; do
        iptables -A INPUT -p tcp --dport "$PORT" -j REJECT --reject-with tcp-reset
    done

    echo "[OK] Firewall Soal 13 aktif: hanya Casper ($CASPER_IP) & Pilot ($PILOT_NET) boleh ke TCP $PORTS; lainnya REJECT tcp-reset."
}

show_status() {
    echo "============================================================"
    echo "Status $NODE_NAME (10.78.4.59) — Soal 7 & Soal 13"
    echo "============================================================"
    echo "--- iptables -S INPUT ---"
    iptables -S INPUT
    echo "--- Counter INPUT (iptables -L INPUT -n -v --line-numbers) ---"
    iptables -L INPUT -n -v --line-numbers
    echo "--- Port TCP 5000 & 5001 Listening ---"
    ss -tlnp 2>/dev/null | grep -E "State|:500[01]([^0-9]|$)" || ps aux | grep '[n]c -l'
    echo "============================================================"
}

show_logs() {
    for PORT in $PORTS; do
        echo "=== Log Pesan TCP $PORT (/tmp/nc_${PORT}.log) ==="
        if [ -s "/tmp/nc_${PORT}.log" ]; then
            cat "/tmp/nc_${PORT}.log"
        else
            echo "(belum ada pesan masuk)"
        fi
    done
}

run_test() {
    show_status
    echo ">>> Uji ping dari Balthasar ke 8.8.8.8 (harus BERHASIL):"
    ping -c 3 -W 2 8.8.8.8
    echo ""
    echo "[i] Verifikasi lanjutan dari node lain:"
    echo "    1) Dari Magi-Casper (10.78.4.58) -> harus BERHASIL:"
    echo "       echo 'uji soal 13 casper 5000' | nc -v -w 3 10.78.4.59 5000"
    echo "       echo 'uji soal 13 casper 5001' | nc -v -w 3 10.78.4.59 5001"
    echo "    2) Dari Magi-Melchior (10.78.4.60) & Lilith (10.78.4.74) -> harus DITOLAK SEKETIKA (Connection refused):"
    echo "       nc -vz -w 3 10.78.4.59 5000"
    echo "       nc -vz -w 3 10.78.4.59 5001"
    echo "    3) Dari Unit-01 (cabang Misato/Julian) -> harus BERHASIL:"
    echo "       echo 'uji soal 13 unit-01 5000' | nc -v -w 3 10.78.4.59 5000"
    echo "       echo 'uji soal 13 unit-01 5001' | nc -v -w 3 10.78.4.59 5001"
    echo "    4) Cek pesan masuk & counter di Balthasar:"
    echo "       bash /root/balthasar.sh log && bash /root/balthasar.sh status"
}

case "${1:-setup}" in
    fw)
        setup_soal13_firewall
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
        setup_soal13_firewall
        show_status
        ;;
esac
