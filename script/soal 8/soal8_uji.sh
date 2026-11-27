#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 8 (Bukti Uji dari Lilith: nc ke Pen-Pen & Tokyo3-Core)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Lilith 10.78.4.74 (Switch-Dogma, gateway Toji) — node Arul, script ini HANYA menguji
#            (tidak mengubah IP/rute/firewall).
# Bukti    : port dilayani -> banner muncul; port 22 -> exit != 0 dalam < 2 detik (RST),
#            bukan habis timeout -w (menggantung). Exit code & durasi dipakai karena
#            sebagian nc (busybox) tidak mencetak pesan error.
# Letakkan di : /root/soal8.sh (di container Lilith)
# Jalankan    : bash /root/soal8.sh
# ==============================================================================

PENPEN="10.78.3.194"
TOKYO3="10.78.4.106"
WAIT=5        # batas -w; durasi mendekati ini = menggantung
FAST_MS=2000  # di bawah ini = langsung gagal

set -u

pick_nc() {
    NC_BIN="$(command -v nc.traditional || command -v nc || true)"
    if [ -z "$NC_BIN" ]; then
        echo "[*] nc belum ada di Lilith -> memasang netcat-traditional..."
        apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-traditional
        NC_BIN="$(command -v nc.traditional || command -v nc)"
    fi
    echo "[*] Klien nc: $NC_BIN"
    echo ""
}

PASS=0; FAIL=0

check_served() {
    IP="$1"; PORT="$2"; EXPECT="$3"; DESC="$4"
    echo ">>> nc -w $WAIT $IP $PORT   ($DESC)"
    OUT="$("$NC_BIN" -w "$WAIT" "$IP" "$PORT" </dev/null 2>&1)"
    echo "$OUT" | sed 's/^/    | /'
    if printf '%s' "$OUT" | grep -qF "$EXPECT"; then
        echo "    [OK] jawaban berisi \"$EXPECT\""; PASS=$((PASS+1))
    else
        echo "    [GAGAL] jawaban tidak berisi \"$EXPECT\""; FAIL=$((FAIL+1))
    fi
    echo ""
    sleep 1   # beri jeda: listener nc memulai ulang setelah tiap koneksi
}

check_closed() {
    IP="$1"; PORT="$2"; DESC="$3"
    echo ">>> time nc -w $WAIT $IP $PORT   ($DESC — tidak dilayani)"
    T0=$(date +%s%N)
    "$NC_BIN" -v -w "$WAIT" "$IP" "$PORT" </dev/null 2>&1 | sed 's/^/    | /'
    RC=${PIPESTATUS[0]}
    T1=$(date +%s%N)
    MS=$(( (T1 - T0) / 1000000 ))
    echo "    exit=$RC durasi=${MS} ms (batas tunggu ${WAIT}000 ms)"
    if [ "$RC" -ne 0 ] && [ "$MS" -lt "$FAST_MS" ]; then
        echo "    [OK] LANGSUNG GAGAL (ditolak RST), tidak menggantung"; PASS=$((PASS+1))
    elif [ "$RC" -ne 0 ]; then
        echo "    [GAGAL] MENGGANTUNG sampai timeout -> ada DROP / rute balik putus"; FAIL=$((FAIL+1))
    else
        echo "    [GAGAL] port ternyata dilayani (exit 0)"; FAIL=$((FAIL+1))
    fi
    echo ""
}

echo "============================================================"
echo "Uji Soal 8 dari $(hostname) ($(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}'))"
echo "Waktu: $(date)"
echo "============================================================"
pick_nc
check_served "$PENPEN" 80   "Welcome to" "Pen-Pen port 80"
check_served "$TOKYO3" 80   "Welcome to" "Tokyo3-Core port 80"
check_served "$TOKYO3" 8080 "syifa imutz" "Tokyo3-Core port 8080"
check_closed "$TOKYO3" 22   "Tokyo3-Core port 22"
check_closed "$PENPEN" 22   "Pen-Pen port 22"
echo "============================================================"
echo "HASIL: $PASS lolos, $FAIL gagal"
echo "============================================================"
[ "$FAIL" -eq 0 ]
