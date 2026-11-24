#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Router TOJI — 1 Default Route ke Fuyutsuki)
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Catatan : Memakai "ip route replace" agar idempoten (aman dijalankan berulang
#           untuk Soal 20 tanpa menduplikasi rute). Pastikan Soal 2 sudah aktif.
# Letakkan di: /root/soal3.sh (atau /root/soal3_toji.sh)
# Jalankan   : bash /root/soal3_toji.sh         (pasang routing statis)
# Uji bukti  : bash /root/soal3_toji.sh test    (tampilkan ip route + uji ping)
# ==============================================================================

set -eu

add_route() {
    DEST="$1"; GW="$2"; DESC="$3"
    ip route replace "$DEST" via "$GW"
    echo "    -> $DEST via $GW ($DESC)"
}

ping_target() {
    echo ">>> Ping ke $2 ($1)"
    if ping -c 3 -W 2 "$1"; then
        echo "    [OK] $2 ($1) terjangkau."
    else
        echo "    [GAGAL] $2 ($1) belum merespons."
    fi
    echo ""
}

show_routes() {
    echo "============================================================"
    echo "Tabel Rute (ip route) - $(hostname) [debinet]"
    echo "============================================================"
    ip route
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 3: Router TOJI — 1 Default Route ke Fuyutsuki ==="
    add_route "default" "10.78.4.165" "Default route ke atas (Fuyutsuki)"
    show_routes
}

run_test() {
    show_routes
    echo "=== Uji Ping Antar-Segmen Wilayah Arul ==="
    ping_target "10.78.4.105" "Gateway Switch-Cmd / Gendo"
    ping_target "10.78.3.193" "Gateway Switch-Medic / Maya"
    ping_target "10.78.4.81" "Gateway Switch-Monolith / Shigeru"
    ping_target "10.78.4.89" "Gateway Switch-Radar / Makoto"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
