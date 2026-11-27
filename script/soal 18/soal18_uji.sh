#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 18 (Bukti Uji Gerbang Zona)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Dipakai di: Magi-Casper (Terminal), Lilith (luar zona), Zeruel (dalam zona) — HANYA menguji.
#   - Casper : ping Zeruel -> BERHASIL (pengecualian ping dari Terminal)
#   - Lilith : ping Zeruel -> GAGAL; TCP ke Zeruel -> GAGAL (koneksi baru dari luar)
#   - Zeruel : ping Lilith & 8.8.8.8 -> BERHASIL (zona boleh memulai, balasan tetap sampai)
# Letakkan di : /root/soal18.sh (di container Casper, Lilith, Zeruel)
# Jalankan    : bash /root/soal18.sh
# ==============================================================================

ZERUEL="10.78.4.82"
LILITH="10.78.4.74"
SEELE="8.8.8.8"

set -u

MYIP="$(ip -4 -o addr show dev eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1)"

do_ping() {   # $1 target, $2 label, $3 harapan (BERHASIL/GAGAL)
    local OUT RC RES
    echo ">>> ping -c 3 -W 2 $1   ($2, harapan: $3)"
    OUT="$(ping -c 3 -W 2 "$1" 2>&1)"; RC=$?
    printf '%s\n' "$OUT" | tail -n 3 | sed 's/^/    | /'
    if [ "$RC" -eq 0 ]; then RES="BERHASIL"; else RES="GAGAL"; fi
    if [ "$RES" = "$3" ]; then echo "    [OK] $RES sesuai harapan"; else echo "    [!] $RES (harapan $3)"; fi
    echo ""
}

do_tcp() {    # $1 target, $2 port, $3 label, $4 harapan
    local RC RES
    echo ">>> TCP $1:$2 (bash /dev/tcp, batas 3 dtk)   ($3, harapan: $4)"
    timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; RC=$?
    case "$RC" in
        0)   RES="BERHASIL"; echo "    | tersambung" ;;
        124) RES="GAGAL";    echo "    | timeout (paket dibuang di gerbang)" ;;
        *)   RES="GAGAL";    echo "    | ditolak/gagal (exit $RC)" ;;
    esac
    if [ "$RES" = "$4" ]; then echo "    [OK] $RES sesuai harapan"; else echo "    [!] $RES (harapan $4)"; fi
    echo ""
}

echo "============================================================"
echo "Uji Soal 18 dari $(hostname) ($MYIP)"
echo "============================================================"
case "$MYIP" in
    10.78.4.5[7-9]|10.78.4.6[0-2])   # Switch-Terminal
        do_ping "$ZERUEL" "Terminal -> Zeruel" "BERHASIL" ;;
    10.78.4.8[1-9]|10.78.4.9[0-4])   # di dalam zona (Monolith/Radar)
        do_ping "$LILITH" "Zeruel -> Lilith (zona memulai)" "BERHASIL"
        do_ping "$SEELE"  "Zeruel -> Seele (zona memulai)"  "BERHASIL" ;;
    *)                                # luar zona (mis. Lilith)
        do_ping "$ZERUEL" "luar zona -> Zeruel" "GAGAL"
        do_tcp  "$ZERUEL" 9000 "luar zona -> Zeruel" "GAGAL" ;;
esac
echo "[i] Lihat counter di Shigeru: bash /root/soal18.sh test"
echo "============================================================"
