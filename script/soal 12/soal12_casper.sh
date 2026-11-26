#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Soal 12 SAJA (Perbaikan Hardening MAGI-CASPER)
# Kelompok : K-29 (10.78.0.0/16) | Node: Magi-Casper (10.78.4.58/29) | PIC: Arul
# Tujuan   : Memperbaiki sabotase break_fw.sh TANPA membatalkan tujuan hardening:
#            - Policy INPUT tetap DROP (default deny, ping masuk tetap ditolak)
#            - Menghapus blokir DNS keluar (-A OUTPUT -p udp --dport 53 -j DROP)
#            - Menghapus blokir seluruh ICMP (-A INPUT -p icmp -j DROP)
#            - Menambahkan ESTABLISHED,RELATED (agar ping 8.8.8.8 & apt-get update jalan)
#            - Membuka TCP 5000 (agar Unit-00 & klien lain tetap bisa terhubung)
# Letakkan di : /root/soal12_casper.sh
# Jalankan    : bash /root/soal12_casper.sh diag  (ambil bukti gejala SEBELUM diperbaiki)
#               bash /root/soal12_casper.sh       (terapkan perbaikan firewall Soal 12)
#               bash /root/soal12_casper.sh test  (ambil bukti SESUDAH diperbaiki)
# ==============================================================================

set -eu

show_diag() {
    echo "============================================================"
    echo "Diagnostik Gejala SEBELUM Perbaikan — $(hostname)"
    echo "============================================================"
    echo "--- iptables -S ---"
    iptables -S
    echo "--- Uji ping 8.8.8.8 (ekspektasi GAGAL saat rusak) ---"
    ping -c 2 -W 2 8.8.8.8 || true
    echo "--- Uji apt-get update (ekspektasi GAGAL saat rusak) ---"
    apt-get update -o Acquire::http::Timeout=5 -o Acquire::Retries=0 || true
    echo "============================================================"
}

fix_soal12() {
    echo "=== Perbaikan Soal 12 di $(hostname) (Hardening Tetap INPUT DROP) ==="
    if ! iptables -S >/dev/null 2>&1; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    # 1. Hapus rule sabotase & reset aman (policy ACCEPT dulu sebelum flush)
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT
    iptables -F OUTPUT

    # 2. Pasang whitelist minimal yang aman
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 5000 -j ACCEPT

    # 3. Kembalikan policy INPUT ke DROP (tujuan hardening tetap terjaga)
    iptables -P INPUT DROP

    echo "[OK] Perbaikan Soal 12 selesai. Policy INPUT tetap DROP."
    echo "--- iptables -S ---"
    iptables -S
}

run_test() {
    echo "============================================================"
    echo "Bukti SESUDAH Perbaikan Soal 12 — $(hostname)"
    echo "============================================================"
    echo "--- iptables -S ---"
    iptables -S
    echo "--- Counter (iptables -L -n -v --line-numbers) ---"
    iptables -L -n -v --line-numbers
    echo "--- Uji ping 8.8.8.8 (harus BERHASIL) ---"
    ping -c 3 -W 2 8.8.8.8
    echo "--- Uji apt-get update (harus BERHASIL) ---"
    apt-get update
    echo "============================================================"
    echo "[i] Uji koneksi TCP 5000 dari Lilith (sementara) & Unit-00 (wajib):"
    echo "    echo 'uji soal 12' | nc -w 3 10.78.4.58 5000"
    echo "[i] Pastikan ping dari Balthasar/Lilith ke 10.78.4.58 tetap 100% packet loss."
}

case "${1:-fix}" in
    diag)
        show_diag
        ;;
    test)
        run_test
        ;;
    *)
        fix_soal12
        ;;
esac
