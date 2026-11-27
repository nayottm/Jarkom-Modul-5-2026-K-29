#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 15 (Bukti Uji Rate-Limit Ping dari Lilith)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Node     : Lilith 10.78.4.74 — HANYA menguji (tidak mengubah IP/rute/firewall).
# Uji 1    : ping rapat  -i 0.1 -c 50 (10/detik, > batas 5/detik) -> sebagian HILANG
# Uji 2    : ping biasa  -i 3   -c 5  (jeda 3 detik, < batas)     -> SEMUA berhasil
# Letakkan di : /root/soal15.sh (di container Lilith)
# Jalankan    : bash /root/soal15.sh          (uji 1 + uji 2)
#               bash /root/soal15.sh rapat    (uji 1 saja)
#               bash /root/soal15.sh biasa    (uji 2 saja)
# ==============================================================================

TARGET="10.78.4.106"   # Tokyo3-Core

set -u

loss_of() { printf '%s' "$1" | grep -oE '[0-9.]+% packet loss' | head -n 1; }
recv_of() { printf '%s' "$1" | grep -oE '[0-9]+ received' | head -n 1 | awk '{print $1}'; }

uji_rapat() {
    echo ">>> [Uji 1] ping -i 0.1 -c 50 $TARGET   (10 ping/detik)"
    OUT="$(ping -i 0.1 -c 50 -W 1 "$TARGET" 2>&1)"
    printf '%s\n' "$OUT" | tail -n 3 | sed 's/^/    | /'
    R="$(recv_of "$OUT")"; R="${R:-0}"
    if [ "$R" -gt 0 ] && [ "$R" -lt 50 ]; then
        echo "    => OK: $R/50 dibalas, $(loss_of "$OUT") (kelebihan dibuang)"
    elif [ "$R" -eq 50 ]; then
        echo "    => GAGAL: semua dibalas -> rate-limit tidak mengenai paket (cek urutan rule)"
    else
        echo "    => GAGAL: tidak ada balasan -> cek rute/ping biasa dulu"
    fi
    echo ""
}

uji_biasa() {
    echo ">>> [Uji 2] ping -i 3 -c 5 $TARGET   (jeda 3 detik)"
    OUT="$(ping -i 3 -c 5 -W 2 "$TARGET" 2>&1)"
    printf '%s\n' "$OUT" | sed 's/^/    | /'
    R="$(recv_of "$OUT")"; R="${R:-0}"
    if [ "$R" -eq 5 ]; then
        echo "    => OK: 5/5 dibalas (ping di bawah batas tidak terganggu)"
    else
        echo "    => GAGAL: $R/5 dibalas"
    fi
    echo ""
}

echo "============================================================"
echo "Uji Soal 15 dari $(hostname) -> Tokyo3-Core $TARGET"
echo "Jam: $(date -u '+%H:%M:%S') UTC | $(date -u -d '+7 hours' '+%H:%M:%S') WIB"
echo "============================================================"
case "${1:-semua}" in
    rapat) uji_rapat ;;
    biasa) uji_biasa ;;
    *)     uji_rapat; echo "[i] jeda 5 detik agar token limit terisi penuh lagi..."; sleep 5; uji_biasa ;;
esac
echo "[i] Lanjut di Tokyo3-Core: bash /root/soal15.sh test  (lihat counter DROP naik)"
