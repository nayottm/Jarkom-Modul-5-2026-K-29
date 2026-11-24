#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Host Uji LILITH — IP & Gateway Sementara (Soal 3–5))
# Kelompok: K-29 (10.78.0.0/16) | PIC: Arul
# Catatan : Sesuai Soal 3, IP dan gateway ini bersifat SEMENTARA untuk Soal 3–5
#           (IP statis permanen disimpan di /etc/network/interfaces pada Soal 6).
# Letakkan di: /root/soal3.sh (atau /root/soal3_lilith.sh)
# Jalankan   : bash /root/soal3_lilith.sh         (pasang IP & gateway sementara)
# Uji bukti  : bash /root/soal3_lilith.sh test    (ip -br a + ip route + uji ping Soal 3)
# ==============================================================================

IF_LAN="eth0"   # ke Switch-Dogma (gw Toji)

set -eu

ping_target() {
    echo ">>> Ping ke $2 ($1)"
    if ping -c 3 -W 2 "$1"; then
        echo "    [OK] $2 ($1) terjangkau."
    else
        echo "    [GAGAL] $2 ($1) belum merespons."
    fi
    echo ""
}

show_status() {
    echo "============================================================"
    echo "Status Node Uji - $(hostname)"
    echo "============================================================"
    ip -br a
    echo "------------------------------------------------------------"
    ip route
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi IP Sementara Soal 3: Host Uji LILITH — IP & Gateway Sementara (Soal 3–5) ==="
    ip link set dev lo up 2>/dev/null || true
    ip link set dev "$IF_LAN" up
    ip addr flush dev "$IF_LAN"
    ip addr add "10.78.4.74/29" dev "$IF_LAN"
    ip route replace default via "10.78.4.73"
    show_status
}

run_test() {
    show_status
    echo "=== Uji Ping Bukti Soal 3 ==="
    ping_target "10.78.4.73" "Gateway Toji (Switch-Dogma)"
    ping_target "10.78.4.83" "Armisael (Arul — wajib berhasil langsung)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
