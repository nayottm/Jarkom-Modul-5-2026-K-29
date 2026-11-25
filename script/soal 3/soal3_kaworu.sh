#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Router KAWORU — IP Interface, Forwarding & Routing Statis)
# Kelompok: K-29 (10.78.0.0/16) | PIC: Julian
# Catatan : IP interface (Soal 2) + IP forwarding + routing statis (Soal 3). Idempotent: aman dijalankan berulang.
# Letakkan di: /root/soal3_kaworu.sh
# Jalankan   : bash /root/soal3_kaworu.sh         (pasang IP, forwarding & rute)
# Uji bukti  : bash /root/soal3_kaworu.sh test    (ip -br a + ip route + uji ping Soal 3)
# ==============================================================================

IF_UP="eth0"   # ke Hikari (router induk)
IF_LAN="eth1"   # ke Switch-Relay (gateway LAN)
# Pemetaan dibaca dari label interface GNS3. Verifikasi dgn ping link setelah setup. Ubah variabel di atas bila perlu.
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
    echo "=== Konfigurasi Soal 2-3: Router Kaworu ==="
    ip link set dev lo up 2>/dev/null || true

    # IP forwarding (Soal 2)
    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward

    # IP interface (Soal 2) — flush dulu agar tidak dobel / 'File exists'
    ip link set dev "$IF_LAN" up
    ip addr flush dev "$IF_LAN"
    ip addr add "10.78.3.225/27" dev "$IF_LAN"
    ip link set dev "$IF_UP" up
    ip addr flush dev "$IF_UP"
    ip addr add "10.78.4.150/30" dev "$IF_UP"

    # Routing statis (Soal 3): default ke atas (Hikari)
    ip route replace default via "10.78.4.149"
    show_status
}

run_test() {
    show_status
    echo "=== Uji Ping Bukti Soal 3 ==="
    ping_target "10.78.4.149" "Hikari (router induk, link)"
    ping_target "10.78.4.105" "Gendo sisi Switch-Cmd (butuh rute Gendo)"
    ping_target "10.78.4.83" "Armisael (Arul — butuh rute Gendo/Shigeru dari Arul)"
    ping_target "10.78.4.74" "Lilith (Arul — butuh rute Gendo/Toji/Fuyutsuki dari Arul)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
