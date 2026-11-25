#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Host Uji COMM-NET — IP & Gateway Sementara (Soal 3–5))
# Kelompok: K-29 (10.78.0.0/16) | PIC: Julian
# Catatan : Sesuai Soal 3, IP dan gateway ini bersifat SEMENTARA untuk Soal 3–5
#           (IP statis permanen disimpan di /etc/network/interfaces pada Soal 6).
# Letakkan di: /root/soal3_comm-net.sh
# Jalankan   : bash /root/soal3_comm-net.sh         (pasang IP & gateway sementara)
# Uji bukti  : bash /root/soal3_comm-net.sh test    (ip -br a + ip route + uji ping Soal 3)
# ==============================================================================

IF_LAN="eth0"   # ke Switch-Comm (gw Hikari)
# VERIFIKASI: ip -br link
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
    echo "Status Node - $(hostname)"
    echo "============================================================"
    ip -br a
    echo "------------------------------------------------------------"
    ip route
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi IP Sementara Soal 3: Host Uji COMM-NET — IP & Gateway Sementara (Soal 3–5) ==="
    ip link set dev lo up 2>/dev/null || true
    ip link set dev "$IF_LAN" up
    ip addr flush dev "$IF_LAN"
    ip addr add "10.78.2.2/24" dev "$IF_LAN"
    ip route replace default via "10.78.2.1"
    show_status
}

run_test() {
    show_status
    echo "=== Uji Ping Bukti Soal 3 ==="
    ping_target "10.78.2.1" "Gateway Hikari (Switch-Comm)"
    ping_target "10.78.4.83" "Armisael (Arul — butuh rute Gendo/Shigeru dari Arul)"
    ping_target "10.78.4.74" "Lilith (Arul — butuh rute Gendo/Toji/Fuyutsuki dari Arul)"
    ping_target "10.78.3.130" "Sachiel (Julian)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
