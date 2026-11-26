#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 3 (Routing Statis Router ASUKA: 3 rute, default -> Gendo + Switch-Bunker + Switch-Lab)
# Kelompok: K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Julian
# Prasyarat : Soal 2 sudah jalan (bash /root/asuka.sh). Script ini TIDAK mengubah IP/interface,
#             hanya menambah rute (idempotent: aman dijalankan berulang).
# PENTING   : Jika /root/asuka.sh (Soal 2) dijalankan ulang, 'ip addr flush' ikut menghapus rute
#             Soal 3 -> jalankan ulang script ini sesudahnya.
# Ringkasan : Subnet anak tidak bisa digabung tepat jadi satu CIDR (tidak bersebelahan /
#             tidak sejajar batas blok), jadi ditulis satu per satu.
# Letakkan di: /root/soal3_asuka.sh
# Jalankan   : bash /root/soal3_asuka.sh         (pasang default route + rute subnet bawah)
# Uji bukti  : bash /root/soal3_asuka.sh test    (ip route + ip route get + ping)
# ==============================================================================

SOAL2_SCRIPT="asuka.sh"
GW_UP="10.78.4.117"     # default route ke Gendo

set -eu

require_onlink() {
    # Next-hop harus berada di subnet yang terhubung langsung (hasil Soal 2).
    GW="$1"; DESC="$2"
    if ! RG=$(ip route get "$GW" 2>/dev/null) || printf '%s' "$RG" | grep -q " via "; then
        echo "[!] ERROR: next-hop $GW ($DESC) belum terhubung langsung."
        echo "    Jalankan dulu Soal 2: bash /root/$SOAL2_SCRIPT"
        return 1
    fi
}

ensure_forwarding() {
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" != "1" ]; then
        echo "[!] ip_forward masih 0 -> diaktifkan ulang (idempotent, sama seperti Soal 2)."
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward
    fi
}

set_default_route() {
    GW="$1"; DESC="$2"
    while ip route del default 2>/dev/null; do :; done
    ip route add default via "$GW"
    echo "    -> default via $GW ($DESC)"
}

add_route() {
    NET="$1"; GW="$2"; DESC="$3"
    ip route replace "$NET" via "$GW"
    echo "    -> $NET via $GW ($DESC)"
}

ping_peer() {
    echo ">>> Ping ke $2 ($1)"
    if ping -c 3 -W 2 "$1"; then
        echo "    [OK] $2 ($1) terhubung."
    else
        echo "    [GAGAL] $2 ($1) belum merespons (cek rute di router lawan / Gendo)."
    fi
    echo ""
}

show_summary() {
    echo "============================================================"
    echo "Tabel Rute (ip route) - $(hostname) [debinet] - Soal 3"
    echo "============================================================"
    ip route
    echo "------------------------------------------------------------"
    sysctl net.ipv4.ip_forward 2>/dev/null || echo "net.ipv4.ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
    echo "============================================================"
}

setup() {
    echo "=== Konfigurasi Soal 3 (debinet): Routing Statis Router ASUKA ==="
    require_onlink "$GW_UP" "Gendo"
    require_onlink "10.78.4.154" "Kensuke"
    require_onlink "10.78.4.158" "Ritsuko"
    ensure_forwarding
    set_default_route "$GW_UP" "Gendo"
    add_route "10.78.3.128/26"  "10.78.4.154" "Switch-Bunker via Kensuke"
    add_route "10.78.4.48/29"   "10.78.4.158" "Switch-Lab via Ritsuko"
    show_summary
}

run_test() {
    show_summary
    echo "=== Keputusan Rute (ip route get) ==="
    ip route get 10.78.4.117 || echo "    [!] tidak ada rute ke 10.78.4.117"
    ip route get 10.78.4.154 || echo "    [!] tidak ada rute ke 10.78.4.154"
    ip route get 10.78.4.158 || echo "    [!] tidak ada rute ke 10.78.4.158"
    ip route get 10.78.4.105 || echo "    [!] tidak ada rute ke 10.78.4.105"
    ip route get 10.78.4.73 || echo "    [!] tidak ada rute ke 10.78.4.73"
    ip route get 10.78.4.81 || echo "    [!] tidak ada rute ke 10.78.4.81"
    echo ""
    echo "=== Uji Ping ==="
    ping_peer "10.78.4.117" "Gendo"
    ping_peer "10.78.3.129" "Kensuke (gw Bunker)"
    ping_peer "10.78.4.49" "Ritsuko (gw Lab)"
    ping_peer "10.78.4.105" "Gendo (gw Switch-Cmd)"
    ping_peer "10.78.4.73" "Toji (gw Lilith)"
    ping_peer "10.78.4.81" "Shigeru (gw Armisael)"
}

if [ "${1:-setup}" = "test" ]; then
    run_test
else
    setup
fi
