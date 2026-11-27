#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 16 (Bukti Uji dari Dummy-Plug: nc -w ke Tokyo3-Core)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Dummy-Plug 10.78.4.51 (Switch-Lab, gateway Ritsuko) — HANYA menguji.
# Bukti    : port 22, 23, 3306 -> exit != 0 dalam < 2 detik (RST), bukan habis -w.
#            port 80 -> "Welcome to ...", port 8080 -> "syifa imutz".
#            Exit code & durasi dicetak karena sebagian nc (busybox) tidak mencetak error.
# Letakkan di : /root/soal16.sh (di container Dummy-Plug; boleh juga di Lilith sebagai
#               pembanding "klien lain": 22/23/3306 tetap ditolak kernel, tapi TIDAK dicatat)
# Jalankan    : bash /root/soal16.sh
# ==============================================================================

TARGET="10.78.4.106"   # Tokyo3-Core
WAIT=5
FAST_MS=2000

set -u

pick_nc() {
    NC_BIN="$(command -v nc.traditional || command -v nc || true)"
    if [ -z "$NC_BIN" ]; then
        echo "[*] nc belum ada -> memasang netcat-traditional..."
        grep -q nameserver /etc/resolv.conf 2>/dev/null || echo "nameserver 8.8.8.8" > /etc/resolv.conf
        apt-get update || echo "[!] WARNING: sebagian repo gagal (cek jam host), lanjut."
        DEBIAN_FRONTEND=noninteractive apt-get install -y netcat-traditional || true
        NC_BIN="$(command -v nc.traditional || command -v nc || true)"
    fi
    if [ -z "$NC_BIN" ]; then
        echo "[!] ERROR: nc tidak tersedia (cek internet/NAT). Soal meminta bukti dengan nc -w."
        exit 1
    fi
    echo "[*] Klien nc: $NC_BIN"
    echo ""
}

PASS=0; FAIL=0

check_closed() {
    local PORT="$1" T0 T1 MS RC
    echo ">>> time nc -v -w $WAIT $TARGET $PORT   (port sensitif)"
    T0=$(date +%s%N)
    "$NC_BIN" -v -w "$WAIT" "$TARGET" "$PORT" </dev/null 2>&1 | sed 's/^/    | /'
    RC=${PIPESTATUS[0]}
    T1=$(date +%s%N); MS=$(( (T1 - T0) / 1000000 ))
    echo "    exit=$RC durasi=${MS} ms (batas tunggu ${WAIT}000 ms)"
    if [ "$RC" -ne 0 ] && [ "$MS" -lt "$FAST_MS" ]; then
        echo "    [OK] DITOLAK SEKETIKA (RST)"; PASS=$((PASS+1))
    elif [ "$RC" -ne 0 ]; then
        echo "    [GAGAL] MENGGANTUNG -> ada DROP / rute balik putus"; FAIL=$((FAIL+1))
    else
        echo "    [GAGAL] koneksi berhasil -> rule Soal 16 tidak mengenai paket"; FAIL=$((FAIL+1))
    fi
    echo ""
    sleep 1
}

check_open() {
    local PORT="$1" EXPECT="$2" OUT
    echo ">>> nc -w $WAIT $TARGET $PORT   (harus tetap bisa)"
    OUT="$("$NC_BIN" -w "$WAIT" "$TARGET" "$PORT" </dev/null 2>&1)"
    printf '%s\n' "$OUT" | sed 's/^/    | /'
    if printf '%s' "$OUT" | grep -qF "$EXPECT"; then
        echo "    [OK] dijawab \"$EXPECT\""; PASS=$((PASS+1))
    else
        echo "    [GAGAL] tidak dijawab \"$EXPECT\" (cek listener Soal 8: ss -ltn di Tokyo3-Core)"; FAIL=$((FAIL+1))
    fi
    echo ""
    sleep 1
}

echo "============================================================"
echo "Uji Soal 16 dari $(hostname) ($(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}')) -> Tokyo3-Core $TARGET"
echo "Jam: $(date -u '+%H:%M:%S') UTC | $(date -u -d '+7 hours' '+%H:%M:%S') WIB"
echo "============================================================"
pick_nc
check_closed 22
check_closed 23
check_closed 3306
check_open 80   "Welcome to"
check_open 8080 "syifa imutz"
echo "============================================================"
echo "HASIL: $PASS lolos, $FAIL gagal"
echo "[i] Lanjut di Tokyo3-Core: bash /root/soal16.sh test  (counter LOG SCAN-NERV: harus naik 3)"
echo "============================================================"
[ "$FAIL" -eq 0 ]
