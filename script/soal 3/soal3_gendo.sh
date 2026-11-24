#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Router GENDO / GENDOU — Static Routing + Ringkasan CIDR (21 Rute))
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Catatan : Memakai "ip route replace" agar idempoten (aman dijalankan berulang
#           untuk Soal 20 tanpa menduplikasi rute). Pastikan Soal 2 sudah aktif.
# Letakkan di: /root/soal3.sh (atau /root/soal3_gendo.sh)
# Jalankan   : bash /root/soal3_gendo.sh         (pasang routing statis)
# Uji bukti  : bash /root/soal3_gendo.sh test    (tampilkan ip route + uji ping)
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
    echo "=== Konfigurasi Soal 3: Router GENDO / GENDOU — Static Routing + Ringkasan CIDR (21 Rute) ==="
    if ! ip route show default | grep -q '^default '; then
        echo "[!] WARNING: Default route ke NAT1 belum ada! Pastikan DHCP eth0 aktif."
    else
        echo "    -> Default route ke NAT1 dipertahankan: $(ip route show default)"
    fi
    add_route "10.78.0.0/23" "10.78.4.110" "Switch-Quarters (Rei)"
    add_route "10.78.3.0/25" "10.78.4.110" "Switch-Hangar (Yui)"
    add_route "10.78.4.0/27" "10.78.4.110" "Switch-Garden (Shinji)"
    add_route "10.78.4.32/28" "10.78.4.110" "Switch-Dock (Mari)"
    add_route "10.78.4.136/29" "10.78.4.110" "[RINGKAS] Link Yui-Rei (.136/30) + Link Yui-Mari (.140/30)"
    add_route "10.78.4.144/30" "10.78.4.110" "Link Yui-Shinji"
    add_route "10.78.2.0/24" "10.78.4.114" "Switch-Comm (Hikari)"
    add_route "10.78.3.224/27" "10.78.4.114" "Switch-Relay (Kaworu)"
    add_route "10.78.4.148/30" "10.78.4.114" "Link Hikari-Kaworu"
    add_route "10.78.3.128/26" "10.78.4.118" "Switch-Bunker (Kensuke)"
    add_route "10.78.4.48/29" "10.78.4.118" "Switch-Lab (Ritsuko)"
    add_route "10.78.4.96/30" "10.78.4.118" "Switch-Archive (Asuka)"
    add_route "10.78.4.152/29" "10.78.4.118" "[RINGKAS] Link Asuka-Kensuke (.152/30) + Link Asuka-Ritsuko (.156/30)"
    add_route "10.78.4.100/30" "10.78.4.122" "Switch-Intel (Kaji)"
    add_route "10.78.4.64/29" "10.78.4.126" "Switch-Cage (Misato)"
    add_route "10.78.4.80/28" "10.78.4.130" "[RINGKAS] Switch-Monolith (.80/29) + Switch-Radar (.88/29)"
    add_route "10.78.4.168/30" "10.78.4.130" "Link Shigeru-Makoto"
    add_route "10.78.3.192/27" "10.78.4.134" "Switch-Medic (Maya)"
    add_route "10.78.4.56/29" "10.78.4.134" "Switch-Terminal (Fuyutsuki)"
    add_route "10.78.4.72/29" "10.78.4.134" "Switch-Dogma (Toji)"
    add_route "10.78.4.160/29" "10.78.4.134" "[RINGKAS] Link Fuyutsuki-Maya (.160/30) + Link Fuyutsuki-Toji (.164/30)"
    show_routes
}

run_test() {
    show_routes
    echo "=== Uji Ping Antar-Segmen Wilayah Arul ==="
    ping_target "10.78.4.73" "Gateway Switch-Dogma / Toji (Arul)"
    ping_target "10.78.3.193" "Gateway Switch-Medic / Maya (Arul)"
    ping_target "10.78.4.89" "Gateway Switch-Radar / Makoto (Arul)"
    ping_target "10.78.4.57" "Gateway Switch-Terminal / Fuyutsuki (Arul)"
    ping_target "10.78.4.81" "Gateway Switch-Monolith / Shigeru (Arul)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
