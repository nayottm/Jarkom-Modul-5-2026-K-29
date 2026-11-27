#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 8 (Kondisi Normal: Layanan TCP Tokyo3-Core)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Tokyo3-Core 10.78.4.106 (Switch-Cmd, gateway Gendo)
# Layanan  : TCP 80 -> "Welcome to {hostname}", TCP 8080 -> "syifa imutz"
# Prasyarat: IP Soal 6 aktif + internet/DNS dari Gendo (Soal 4-5) untuk apt.
# Catatan  : Listener = loop netcat-traditional di background (nc -l hanya melayani
#            1 koneksi, jadi diulang). Port lain (mis. 22) sengaja TIDAK dilayani:
#            tanpa listener & tanpa DROP, kernel membalas RST -> klien langsung gagal.
#            Idempotent: listener lama dimatikan dulu (aman untuk Soal 20).
# Letakkan di : /root/soal8.sh (di container Tokyo3-Core)
# Jalankan    : bash /root/soal8.sh         (pasang paket + nyalakan listener)
# Uji lokal   : bash /root/soal8.sh test    (port listen, uji 127.0.0.1, log)
# Matikan     : bash /root/soal8.sh stop
# ==============================================================================

NODE_NAME="Tokyo3-Core"
DNS_SERVER="8.8.8.8"
LOG_DIR="/var/log/soal8"
RUN_DIR="/run/soal8"
# Format layanan: "PORT|PESAN"  ($(hostname) dievaluasi saat script jalan)
SERVICES=(
    "80|Welcome to $(hostname)"
    "8080|syifa imutz"
)

set -eu

check_internet() {
    echo "[*] Cek koneksi internet & DNS sebelum apt..."
    if ! ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo "[!] ERROR: ping 8.8.8.8 gagal -> masalah routing/NAT, bukan DNS."
        echo "    Cek di node ini : ip route   (harus: default via gateway LAN)"
        echo "    Cek di Gendo    : NAT MASQUERADE + default route ke NAT1 (Soal 4), FORWARD (Soal 5)"
        exit 1
    fi
    echo "    -> ping 8.8.8.8 OK"
    if ! getent hosts deb.debian.org >/dev/null 2>&1; then
        echo "    -> DNS gagal dengan resolv.conf sekarang:"
        sed 's/^/       /' /etc/resolv.conf 2>/dev/null || true
        echo "    -> mengganti nameserver ke $DNS_SERVER"
        echo "nameserver $DNS_SERVER" > /etc/resolv.conf
        if ! getent hosts deb.debian.org >/dev/null 2>&1; then
            echo "[!] ERROR: internet OK tapi DNS ke $DNS_SERVER gagal -> UDP/TCP 53 kemungkinan"
            echo "    diblokir firewall Gendo (Soal 5) atau tidak ikut di-NAT (Soal 4)."
            exit 1
        fi
    fi
    echo "    -> DNS OK: deb.debian.org = $(getent hosts deb.debian.org | awk '{print $1; exit}')"
}

ensure_packages() {
    echo "[*] Menyiapkan netcat-traditional (+ iptables untuk Soal 14-16)..."
    if command -v nc.traditional >/dev/null 2>&1 && command -v iptables >/dev/null 2>&1; then
        echo "    -> netcat-traditional & iptables sudah terpasang."
        return 0
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "[!] ERROR: apt-get tidak ada (bukan debinet?). Pasang netcat-traditional manual."
        exit 1
    fi
    check_internet
    # apt-get update bisa keluar 0 walau repo gagal (W:), atau != 0 hanya karena satu repo
    # (mis. trixie-security gagal verifikasi karena jam host terlambat). Yang menentukan:
    # apakah paket yang dibutuhkan punya kandidat dari indeks yang berhasil diunduh.
    apt-get update || echo "[!] WARNING: sebagian repo gagal (cek 'date -u' / jam host). Lanjut pakai indeks yang ada."
    for PKG in netcat-traditional iptables; do
        if ! apt-cache policy "$PKG" 2>/dev/null | grep -q "Candidate: [0-9]"; then
            echo "[!] ERROR: paket $PKG tidak tersedia di indeks apt. Cek DNS/NAT dan 'date -u'."
            exit 1
        fi
    done
    DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-traditional iptables
}

resolve_nc() {
    # Pakai biner eksplisit: bila netcat-openbsd juga ada, /bin/nc bisa menunjuk ke versi openbsd
    # yang tidak mengenal 'nc -l -p PORT -q 1'.
    NC_BIN="$(command -v nc.traditional || true)"
    if [ -z "$NC_BIN" ]; then
        echo "[!] ERROR: nc.traditional tidak ditemukan setelah instalasi."
        exit 1
    fi
}

stop_port() {
    PORT="$1"
    PIDF="$RUN_DIR/port$PORT.pid"
    if [ -f "$PIDF" ]; then
        PID="$(cat "$PIDF")"
        kill -- "-$PID" 2>/dev/null || kill "$PID" 2>/dev/null || true
        rm -f "$PIDF"
    fi
    # Sisa listener dari run lama / dijalankan manual
    pkill -f "soal8-port$PORT " 2>/dev/null || true
    pkill -f "nc.traditional -v -l -p $PORT " 2>/dev/null || true
}

start_port() {
    PORT="$1"; MSG="$2"
    LOG="$LOG_DIR/port$PORT.log"
    stop_port "$PORT"
    sleep 0.3
    # setsid + nohup: loop tetap hidup setelah script/konsol GNS3 ditutup.
    # -v -> catat "connect to [...] from [...]" sebagai log penerima.
    setsid nohup bash -c '
        PORT="$1"; MSG="$2"; NC_BIN="$3"; LOG="$4"
        while true; do
            printf "%s\n" "$MSG" | "$NC_BIN" -v -l -p "$PORT" -q 0 >>"$LOG" 2>&1 || sleep 1
        done
    ' "soal8-port$PORT" "$PORT" "$MSG" "$NC_BIN" "$LOG" >/dev/null 2>&1 &
    echo $! > "$RUN_DIR/port$PORT.pid"
    echo "    -> TCP $PORT : \"$MSG\" (log: $LOG)"
}

port_listening() {
    if command -v ss >/dev/null 2>&1; then
        ss -ltn | awk '{print $4}' | grep -Eq "[:.]$1\$"
    else
        # Fallback /proc: port dalam hex, state 0A = LISTEN
        awk -v p="$(printf '%04X' "$1")" 'NR>1 { split($2,a,":"); if (a[2]==p && $4=="0A") f=1 } END { exit !f }' /proc/net/tcp
    fi
}

show_status() {
    echo "============================================================"
    echo "Status Layanan Soal 8 - $(hostname) ($NODE_NAME)"
    echo "============================================================"
    ip -br a 2>/dev/null || true
    echo "------------------------------------------------------------"
    echo "Port TCP yang LISTEN:"
    if command -v ss >/dev/null 2>&1; then ss -ltn; else cat /proc/net/tcp; fi
    echo "------------------------------------------------------------"
    if command -v iptables >/dev/null 2>&1; then
        echo "iptables -S (harus kosong/ACCEPT agar port tertutup dibalas RST):"
        iptables -S 2>/dev/null || true
    fi
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 8: Layanan TCP $NODE_NAME ==="
    ensure_packages
    resolve_nc
    mkdir -p "$LOG_DIR" "$RUN_DIR"
    for S in "${SERVICES[@]}"; do
        start_port "${S%%|*}" "${S#*|}"
    done
    sleep 1
    for S in "${SERVICES[@]}"; do
        P="${S%%|*}"
        if port_listening "$P"; then
            echo "    [OK] port $P LISTEN"
        else
            echo "    [!] port $P belum LISTEN, cek log $LOG_DIR/port$P.log"
        fi
    done
    if port_listening 22; then
        echo "    [!] PERINGATAN: ada yang listen di port 22 -> uji 'port tidak dilayani' pakai port lain."
    fi
    show_status
}

run_test() {
    show_status
    resolve_nc
    echo "=== Uji lokal (127.0.0.1) ==="
    for S in "${SERVICES[@]}"; do
        P="${S%%|*}"
        echo ">>> nc 127.0.0.1 $P"
        "$NC_BIN" -w 3 127.0.0.1 "$P" </dev/null || true
        echo ""
    done
    echo ">>> nc 127.0.0.1 22 (harus langsung ditolak)"
    T0=$(date +%s%N)
    if "$NC_BIN" -w 5 127.0.0.1 22 </dev/null; then RC=0; else RC=$?; fi
    T1=$(date +%s%N)
    echo "    exit=$RC durasi=$(( (T1 - T0) / 1000000 )) ms"
    echo ""
    echo "=== Log penerima (5 baris terakhir per port) ==="
    for S in "${SERVICES[@]}"; do
        P="${S%%|*}"
        echo "--- $LOG_DIR/port$P.log"
        tail -n 5 "$LOG_DIR/port$P.log" 2>/dev/null || echo "(belum ada koneksi)"
    done
}

stop_all() {
    for S in "${SERVICES[@]}"; do
        stop_port "${S%%|*}"
        echo "    -> port ${S%%|*} dimatikan"
    done
}

case "${1:-setup}" in
    test) run_test ;;
    stop) stop_all ;;
    *)    setup ;;
esac
