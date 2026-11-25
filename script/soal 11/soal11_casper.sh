#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 11 SAJA (Casper Jadi Hantu)
# Kelompok : K-29 (10.78.0.0/16) | Node: Magi-Casper (10.78.4.58/29) | PIC: Arul
# Tujuan   : DROP semua ICMP echo-request masuk (termasuk satu switch),
#            Casper tetap bisa ping keluar, layanan TCP 5000 tetap hidup.
# Letakkan di : /root/soal11_casper.sh
# Jalankan    : bash /root/soal11_casper.sh
# Uji bukti   : bash /root/soal11_casper.sh test
# ==============================================================================

BALTHASAR_IP="10.78.4.59"
LILITH_IP="10.78.4.74"

set -eu

setup_soal11() {
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    echo "[OK] Firewall Soal 11 aktif di $(hostname)."
}

show_proof() {
    echo "=== iptables -S INPUT ==="
    iptables -S INPUT
    echo "=== iptables -L INPUT -n -v --line-numbers ==="
    iptables -L INPUT -n -v --line-numbers
}

if [ "${1:-setup}" = "test" ]; then
    show_proof
    echo ">>> Ping dari Casper ke Balthasar ($BALTHASAR_IP):"
    ping -c 3 -W 2 "$BALTHASAR_IP"
    echo ">>> Ping dari Casper ke Lilith ($LILITH_IP):"
    ping -c 3 -W 2 "$LILITH_IP"
else
    setup_soal11
    show_proof
fi
