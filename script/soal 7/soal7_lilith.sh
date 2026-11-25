#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 7 (Pengirim Uji dari LILITH ke Cluster MAGI)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# IP Node  : 10.78.4.74/29 (Switch-Dogma, Gateway Toji: 10.78.4.73)
# Tujuan   : Mengirim pesan uji ke:
#            - Magi-Casper    (10.78.4.58) port 5000
#            - Magi-Balthasar (10.78.4.59) port 5000 & 5001
#            - Magi-Melchior  (10.78.4.60) port 5000
# Letakkan di : /root/soal7_lilith.sh (di container Lilith)
# Jalankan    : bash /root/soal7_lilith.sh
# ==============================================================================

CASPER_IP="10.78.4.58"
BALTHASAR_IP="10.78.4.59"
MELCHIOR_IP="10.78.4.60"
DNS_SERVER="8.8.8.8"

set -eu

ensure_netcat() {
    if [ ! -s /etc/resolv.conf ]; then
        echo "nameserver $DNS_SERVER" > /etc/resolv.conf
    fi
    if ! command -v nc >/dev/null 2>&1; then
        echo "[*] Memasang netcat-traditional di Lilith..."
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-traditional
    fi
    if command -v update-alternatives >/dev/null 2>&1 && [ -x /bin/nc.traditional ]; then
        update-alternatives --set nc /bin/nc.traditional >/dev/null 2>&1 || true
    fi
    echo "    -> netcat di Lilith: $(nc -h 2>&1 | head -n 1)"
}

send_msg() {
    TARGET_NAME="$1"
    TARGET_IP="$2"
    TARGET_PORT="$3"
    MSG="$4"

    echo ">>> Mengirim ke $TARGET_NAME ($TARGET_IP:$TARGET_PORT)..."
    set +e
    printf '%s
' "$MSG" | nc -w 3 "$TARGET_IP" "$TARGET_PORT"
    RC=$?
    set -e
    echo "    -> Pesan: "$MSG" | exit=$RC"
    if [ "$RC" -eq 0 ]; then
        echo "    [OK] Terkirim ke $TARGET_NAME:$TARGET_PORT"
    else
        echo "    [GAGAL] Tidak tersambung ke $TARGET_NAME:$TARGET_PORT (pastikan listener sudah menyala)."
    fi
    echo ""
}

echo "=== Pengujian Soal 7: Kirim Pesan dari LILITH ke MAGI ==="
ensure_netcat
echo ""

send_msg "Magi-Casper"    "$CASPER_IP"    5000 "Halo Magi-Casper (5000) dari Lilith - Soal 7"
send_msg "Magi-Balthasar" "$BALTHASAR_IP" 5000 "Halo Magi-Balthasar (5000) dari Lilith - Soal 7"
send_msg "Magi-Balthasar" "$BALTHASAR_IP" 5001 "Halo Magi-Balthasar (5001) dari Lilith - Soal 7"
send_msg "Magi-Melchior"  "$MELCHIOR_IP"  5000 "Halo Magi-Melchior (5000) dari Lilith - Soal 7"

echo "============================================================"
echo "[i] Selesai! Cek pesan diterima pada tiap node MAGI:"
echo "    - Di Magi-Casper    : bash /root/casper.sh log"
echo "    - Di Magi-Balthasar : bash /root/balthasar.sh log"
echo "    - Di Magi-Melchior  : bash /root/melchior.sh log"
echo "============================================================"
