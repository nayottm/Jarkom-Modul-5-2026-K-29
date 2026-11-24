#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Router SHIGERU — Default Route ke Gendo + 1 Rute Bawah Makoto (2 Rute))
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Catatan : Memakai "ip route replace" agar idempoten (aman dijalankan berulang
#           untuk Soal 20 tanpa menduplikasi rute). Pastikan Soal 2 sudah aktif.
# Letakkan di: /root/soal3.sh (atau /root/soal3_shigeru.sh)
# Jalankan   : bash /root/soal3_shigeru.sh         (pasang routing statis)
# Uji bukti  : bash /root/soal3_shigeru.sh test    (tampilkan ip route + uji ping)
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
    echo "=== Konfigurasi Soal 3: Router SHIGERU — Default Route ke Gendo + 1 Rute Bawah Makoto (2 Rute) ==="
    add_route "default" "10.78.4.129" "Default route ke atas (Gendo)"
    add_route "10.78.4.88/29" "10.78.4.170" "Switch-Radar via Makoto"
    show_routes
}

run_test() {
    show_routes
    echo "=== Uji Ping Antar-Segmen Wilayah Arul ==="
    ping_target "10.78.4.105" "Gateway Switch-Cmd / Gendo"
    ping_target "10.78.4.57" "Gateway Switch-Terminal / Fuyutsuki"
    ping_target "10.78.4.73" "Gateway Switch-Dogma / Toji"
    ping_target "10.78.3.193" "Gateway Switch-Medic / Maya"
    ping_target "10.78.4.89" "Gateway Switch-Radar / Makoto"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
