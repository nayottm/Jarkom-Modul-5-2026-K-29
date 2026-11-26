#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 13 SAJA (Brankas Balthasar)
# Kelompok : K-29 (10.78.0.0/16) | Node: Magi-Balthasar (10.78.4.59/29) | PIC: Arul
# Aturan   :
#   - Policy INPUT tetap ACCEPT (lalu lintas lain tidak boleh terganggu)
#   - Loopback & ESTABLISHED,RELATED diizinkan (ping 8.8.8.8 & balasannya aman)
#   - TCP 5000 & 5001 HANYA diizinkan dari:
#       * Magi-Casper : 10.78.4.58/32
#       * Semua Pilot : 10.78.4.64/29 (Switch-Cage / Misato)
#   - Node lain (termasuk satu switch: Magi-Melchior) langsung ditolak dengan
#     REJECT --reject-with tcp-reset (seketika Connection refused, bukan timeout)
# Letakkan di : /root/soal13.sh
# Jalankan    : bash /root/soal13.sh         (pasang firewall Soal 13)
#               bash /root/soal13.sh test    (tampilkan rule, port 5000/5001, & ping 8.8.8.8)
#               bash /root/soal13.sh status  (cek counter iptables)
# ==============================================================================

CASPER_IP="10.78.4.58/32"
PILOT_NET="10.78.4.64/29"
PORTS="5000 5001"

set -eu

setup_fw() {
    echo "=== [Soal 13] Memasang Firewall Brankas Balthasar di $(hostname) ==="
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    for PORT in $PORTS; do
        iptables -A INPUT -p tcp -s "$CASPER_IP" --dport "$PORT" -j ACCEPT
        iptables -A INPUT -p tcp -s "$PILOT_NET" --dport "$PORT" -j ACCEPT
    done

    for PORT in $PORTS; do
        iptables -A INPUT -p tcp --dport "$PORT" -j REJECT --reject-with tcp-reset
    done

    echo "[OK] Firewall Soal 13 aktif."
}

show_status() {
    echo "============================================================"
    echo "Status Firewall Soal 13 — $(hostname) (10.78.4.59)"
    echo "============================================================"
    echo "--- iptables -S INPUT ---"
    iptables -S INPUT
    echo "--- Counter INPUT (iptables -L INPUT -n -v --line-numbers) ---"
    iptables -L INPUT -n -v --line-numbers
    echo "--- Port TCP 5000 & 5001 Listening ---"
    ss -tlnp 2>/dev/null | grep -E "State|:500[01]([^0-9]|$)" || ps aux | grep '[n]c -l'
    echo "============================================================"
}

run_test() {
    show_status
    echo ">>> Uji ping 8.8.8.8 dari Balthasar (harus BERHASIL):"
    ping -c 3 -W 2 8.8.8.8
}

case "${1:-setup}" in
    test)
        run_test
        ;;
    status)
        show_status
        ;;
    *)
        setup_fw
        show_status
        ;;
esac
