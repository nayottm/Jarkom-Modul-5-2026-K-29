#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Konfigurasi Lengkap MAGI-CASPER (Soal 7, 11, & 12)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# IP Node  : 10.78.4.58/29 (Switch-Terminal, Gateway Fuyutsuki: 10.78.4.57)
# Mencakup :
#   - Soal 7  : Instalasi iptables & netcat-traditional + listener TCP 5000
#   - Soal 11 : Mode Hantu (ping masuk ditolak diam-diam, ping keluar & TCP 5000 hidup)
#   - Soal 12 : Hardening Default Deny (policy INPUT DROP) yang tetap mengizinkan
#               loopback, ESTABLISHED/RELATED (ping keluar & apt-get update),
#               DNS keluar, serta layanan TCP 5000
# Letakkan di : /root/casper.sh
# Jalankan    : bash /root/casper.sh         (jalankan penuh Soal 7 + 11 + 12)
#               bash /root/casper.sh fw      (perbaiki/pasang firewall Soal 12 saja)
#               bash /root/casper.sh test    (uji iptables, ping 8.8.8.8/Balthasar/Lilith, & apt-get update)
#               bash /root/casper.sh log     (lihat pesan masuk TCP 5000)
#               bash /root/casper.sh status  (cek firewall & port listening)
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

setup_soal12_hardening() {
    echo "=== [Soal 11 & 12] Firewall Hardening Default Deny di $NODE_NAME ==="
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    # 1. Reset aman (kembalikan policy ACCEPT dulu sebelum flush INPUT & OUTPUT)
    #    Sekaligus menghapus rule sabotase:
    #    - INPUT  : -p icmp -j DROP (memblokir balasan ping / echo-reply)
    #    - OUTPUT : -p udp --dport 53 -j DROP (memblokir DNS keluar untuk apt-get update)
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT
    iptables -F OUTPUT

    # 2. Aturan INPUT yang diizinkan (whitelist minimal)
    #    - Loopback lokal tetap berjalan
    iptables -A INPUT -i lo -j ACCEPT
    #    - Balasan koneksi yang dibuka oleh Casper (ping 8.8.8.8, DNS, HTTP/HTTPS apt)
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    #    - Layanan MAGI-Casper pada TCP 5000 (untuk Unit-00, Lilith, dll.)
    iptables -A INPUT -p tcp --dport 5000 -j ACCEPT

    # 3. Kunci policy INPUT menjadi DROP paling akhir (default deny hardening)
    #    Semua lalu lintas masuk tak diizinkan (termasuk ICMP echo-request / ping masuk)
    #    otomatis ditolak diam-diam oleh policy INPUT DROP.
    iptables -P INPUT DROP

    echo "[OK] Hardening Soal 12 aktif: policy INPUT=DROP, OUTPUT=ACCEPT (DNS bebas), TCP 5000 & ESTABLISHED aktif."
}

show_status() {
    echo "============================================================"
    echo "Status $NODE_NAME (10.78.4.58) — Soal 7, 11, & 12"
    echo "============================================================"
    echo "--- iptables -S ---"
    iptables -S
    echo "--- Counter INPUT & OUTPUT (iptables -L -n -v --line-numbers) ---"
    iptables -L -n -v --line-numbers
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
    echo ">>> [1/4] Uji ping dari Casper ke 8.8.8.8 (harus BERHASIL):"
    ping -c 3 -W 2 8.8.8.8
    echo ""
    echo ">>> [2/4] Uji ping dari Casper ke Balthasar ($BALTHASAR_IP) (harus BERHASIL):"
    ping -c 3 -W 2 "$BALTHASAR_IP"
    echo ""
    echo ">>> [3/4] Uji ping dari Casper ke Lilith ($LILITH_IP) (harus BERHASIL):"
    ping -c 3 -W 2 "$LILITH_IP"
    echo ""
    echo ">>> [4/4] Uji apt-get update di Casper (harus BERHASIL):"
    apt-get update
    echo ""
    echo "[i] Verifikasi lanjutan dari node lain:"
    echo "    1) Ping ke 10.78.4.58 dari Balthasar & Lilith -> harus GAGAL (100% packet loss)."
    echo "    2) Uji sementara dari Lilith (sambil tunggu Julian):"
    echo "       echo 'uji soal 12 dari Lilith' | nc -w 3 10.78.4.58 5000"
    echo "    3) Bukti wajib dari Unit-00 (setelah Julian selesai Soal 6):"
    echo "       echo 'uji soal 12 dari Unit-00' | nc -w 3 10.78.4.58 5000"
    echo "    4) Cek pesan masuk di Casper: bash /root/casper.sh log"
}

case "${1:-setup}" in
    fw)
        setup_soal12_hardening
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
        setup_soal12_hardening
        show_status
        ;;
esac
