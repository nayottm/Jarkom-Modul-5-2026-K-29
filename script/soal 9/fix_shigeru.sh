# 1. Aktifkan kembali IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# 2. Hapus policy routing liar (prio 90 / iif eth2 -> table 100) & bersihkan tabel 100
ip rule del pref 90
ip route flush table 100

# 3. Hapus rute blackhole menuju Switch-Dogma (Lilith & Adam)
ip route del blackhole 10.78.4.72/29

# 4. Kembalikan default route ke Gendou (10.78.4.129 via eth0)
ip route replace default via 10.78.4.129 dev eth0