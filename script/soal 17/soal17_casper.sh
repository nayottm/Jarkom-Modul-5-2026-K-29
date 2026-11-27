#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 17 (Pengirim Uji dari Magi-Casper)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Magi-Casper 10.78.4.58 — HANYA mengirim/menguji (firewall Soal 11-12 tidak disentuh).
# Uji      : 1) TCP: kirim pesan unik ke IP Zeruel 10.78.4.82 port 9000 (nc -v)
#               -> balasan "OK" datang dari 10.78.4.82, padahal pesan mendarat di Pen-Pen.
#            2) Ping ke Zeruel -> tidak dialihkan (tetap dijawab Zeruel).
# Letakkan di : /root/soal17.sh (di container Magi-Casper)
# Jalankan    : bash /root/soal17.sh                  (pesan default bertanda waktu)
#               bash /root/soal17.sh "pesan bebas"    (pesan sendiri)
# ==============================================================================

ZERUEL="10.78.4.82"
PORT="9000"
MSG="${1:-Pesan Casper untuk Zeruel $(date -u '+%H:%M:%S')}"

set -u

NC_BIN="$(command -v nc.traditional || command -v nc || true)"
if [ -z "$NC_BIN" ]; then
    echo "[!] ERROR: nc tidak ada di Casper (seharusnya terpasang di Soal 7)."
    exit 1
fi

echo "============================================================"
echo "Uji Soal 17 dari $(hostname) ($(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}'))"
echo "============================================================"
echo ">>> [1] echo \"$MSG\" | nc -n -v -w 3 -q 1 $ZERUEL $PORT"
OUT="$(printf '%s\n' "$MSG" | "$NC_BIN" -n -v -w 3 -q 1 "$ZERUEL" "$PORT" 2>&1)"; RC=$?
printf '%s\n' "$OUT" | sed 's/^/    | /'
if [ "$RC" -eq 0 ] && printf '%s' "$OUT" | grep -q "OK"; then
    echo "    => Terhubung ke $ZERUEL:$PORT dan menerima balasan 'OK' dari $ZERUEL."
    echo "       Cek di Pen-Pen & Zeruel: bash /root/soal17.sh log  (pesan harus ada di Pen-Pen saja)"
else
    echo "    => GAGAL (exit $RC). Cek listener 9000 di Pen-Pen & rule di Fuyutsuki."
fi
echo ""
echo ">>> [2] ping -c 3 $ZERUEL   (ping TIDAK dialihkan)"
ping -c 3 -W 2 "$ZERUEL" 2>&1 | sed 's/^/    | /'
echo "    => Balasan ping dari $ZERUEL asli (cek conntrack ICMP di Fuyutsuki: tanpa NAT)."
echo "============================================================"
echo "Pesan terkirim: \"$MSG\""
echo "============================================================"
