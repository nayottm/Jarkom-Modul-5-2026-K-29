#!/bin/bash
# ==============================================================================
# Modul 5 Operation Geofront — Konfigurasi Lengkap Router GENDO (Soal 2 – 5)
# Kelompok : K-29 (10.78.0.0/16) | Image: ardhptr21/debinet:latest | PIC: Arul
# Mencakup :
#   - Soal 2 : IP Interface (eth0 DHCP NAT1 + eth1-eth8 statis) & IP Forwarding
#   - Soal 3 : 21 Static Routes + 4 Ringkasan CIDR per Cabang (idempoten)
#   - Soal 4 : DNS Resolver (8.8.8.8), Paket Modul, & NAT MASQUERADE (10.78.0.0/16 -> eth0)
#   - Soal 5 : Default Deny (INPUT & FORWARD DROP) + 4 Izin Utama + Loopback + DHCP NAT1
# Letakkan di : /root/gendo.sh
# Jalankan    : bash /root/gendo.sh         (jalankan penuh Soal 2–5, idempoten)
#               bash /root/gendo.sh routes  (pulihkan rute Soal 3 saja — bantu Soal 20)
# Uji bukti   : bash /root/gendo.sh test    (tampilkan iptables -S, nat, rute, & counter)
# ==============================================================================

# --- PEMETAAN INTERFACE GENDOU (SUDAH SESUAI TOPOLOGI GNS3) ---
IF_NAT="eth0"                  # ke NAT1 (DHCP)
IF_YUI="eth1"                  # Link ke Yui (Julian)
IF_HIKARI="eth2"               # Link ke Hikari (Julian)
IF_ASUKA="eth3"                # Link ke Asuka (Julian)
IF_KAJI="eth4"                 # Link ke Kaji (Julian)
IF_MISATO="eth5"               # Link ke Misato (Julian)
IF_SHIGERU="eth6"              # Link ke Shigeru (Arul)
IF_FUYUTSUKI="eth7"            # Link ke Fuyutsuki (Arul)
IF_CMD="eth8"                  # ke Switch-Cmd (LAN Tokyo3-Core)

INTERNAL_PREFIX="10.78.0.0/16" # Prefix internal Kelompok 29
DNS_SERVER="8.8.8.8"           # DNS resolver
# --------------------------------------------------------------

set -eu

# ------------------------------------------------------------------------------
# HELPER FUNCTIONS
# ------------------------------------------------------------------------------
ensure_dhcp_nat() {
    IFACE="$1"; DESC="$2"
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IFACE ($DESC) tidak ditemukan!"
        exit 1
    fi
    ip link set dev "$IFACE" up
    if ip -4 addr show dev "$IFACE" | grep -q 'inet '; then
        CUR_IP="$(ip -4 -br addr show dev "$IFACE" | awk '{print $3}')"
        echo "    -> $IFACE : $CUR_IP (DHCP aktif dari $DESC, dipertahankan)"
        return 0
    fi
    echo "[*] $IFACE belum punya IPv4, mencoba DHCP ($DESC)..."
    if command -v dhclient >/dev/null 2>&1; then
        dhclient "$IFACE" || true
    elif command -v udhcpc >/dev/null 2>&1; then
        udhcpc -i "$IFACE" -q -t 5 || true
    fi
}

set_static_iface() {
    IFACE="$1"; CIDR="$2"; DESC="$3"
    if ! ip link show "$IFACE" >/dev/null 2>&1; then
        echo "[!] ERROR: Interface $IFACE ($DESC) tidak ditemukan!"
        exit 1
    fi
    ip link set dev "$IFACE" up
    # Hanya flush/add jika IP belum terpasang agar tidak memutus rute tak perlu
    if ! ip -4 -br addr show dev "$IFACE" | grep -qw "$CIDR"; then
        ip addr flush dev "$IFACE"
        ip addr add "$CIDR" dev "$IFACE"
    fi
    echo "    -> $IFACE : $CIDR ($DESC)"
}

add_route() {
    DEST="$1"; GW="$2"; DESC="$3"
    ip route replace "$DEST" via "$GW"
    echo "    -> $DEST via $GW ($DESC)"
}

# ------------------------------------------------------------------------------
# SOAL 2: IP INTERFACE & IP FORWARDING
# ------------------------------------------------------------------------------
setup_soal2() {
    echo "=== [Soal 2] Konfigurasi Interface & IP Forwarding GENDO ==="
    ip link set dev lo up 2>/dev/null || true
    ensure_dhcp_nat  "$IF_NAT"       "NAT1 (WAN / DHCP)"
    set_static_iface "$IF_YUI"       "10.78.4.109/30" "Link Gendo -> Yui"
    set_static_iface "$IF_HIKARI"    "10.78.4.113/30" "Link Gendo -> Hikari"
    set_static_iface "$IF_ASUKA"     "10.78.4.117/30" "Link Gendo -> Asuka"
    set_static_iface "$IF_KAJI"      "10.78.4.121/30" "Link Gendo -> Kaji"
    set_static_iface "$IF_MISATO"    "10.78.4.125/30" "Link Gendo -> Misato"
    set_static_iface "$IF_SHIGERU"   "10.78.4.129/30" "Link Gendo -> Shigeru"
    set_static_iface "$IF_FUYUTSUKI" "10.78.4.133/30" "Link Gendo -> Fuyutsuki"
    set_static_iface "$IF_CMD"       "10.78.4.105/30" "LAN Switch-Cmd (gw Tokyo3-Core)"

    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || echo 1 > /proc/sys/net/ipv4/ip_forward
    if [ -f /etc/sysctl.conf ] && ! grep -Eq '^[[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=[[:space:]]*1' /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    echo "    -> net.ipv4.ip_forward = $(cat /proc/sys/net/ipv4/ip_forward)"
}

# ------------------------------------------------------------------------------
# SOAL 3: STATIC ROUTING + RINGKASAN CIDR (21 RUTE)
# ------------------------------------------------------------------------------
setup_soal3() {
    echo "=== [Soal 3] Konfigurasi Static Routing & Ringkasan CIDR GENDO ==="
    if ip route show default | grep -q '^default '; then
        echo "    -> Default route NAT1: $(ip route show default)"
    else
        echo "[!] WARNING: Default route ke NAT1 belum ada! Cek DHCP $IF_NAT."
    fi

    # Cabang Yui (via 10.78.4.110) — 7 subnet diringkas menjadi 6 rute
    add_route "10.78.0.0/23"   "10.78.4.110" "Switch-Quarters (Rei)"
    add_route "10.78.3.0/25"   "10.78.4.110" "Switch-Hangar (Yui)"
    add_route "10.78.4.0/27"   "10.78.4.110" "Switch-Garden (Shinji)"
    add_route "10.78.4.32/28"  "10.78.4.110" "Switch-Dock (Mari)"
    add_route "10.78.4.136/29" "10.78.4.110" "[RINGKAS] Link Yui-Rei + Link Yui-Mari"
    add_route "10.78.4.144/30" "10.78.4.110" "Link Yui-Shinji"

    # Cabang Hikari (via 10.78.4.114) — 3 rute
    add_route "10.78.2.0/24"   "10.78.4.114" "Switch-Comm (Hikari)"
    add_route "10.78.3.224/27" "10.78.4.114" "Switch-Relay (Kaworu)"
    add_route "10.78.4.148/30" "10.78.4.114" "Link Hikari-Kaworu"

    # Cabang Asuka (via 10.78.4.118) — 5 subnet diringkas menjadi 4 rute
    add_route "10.78.3.128/26" "10.78.4.118" "Switch-Bunker (Kensuke)"
    add_route "10.78.4.48/29"  "10.78.4.118" "Switch-Lab (Ritsuko)"
    add_route "10.78.4.96/30"  "10.78.4.118" "Switch-Archive (Asuka)"
    add_route "10.78.4.152/29" "10.78.4.118" "[RINGKAS] Link Asuka-Kensuke + Link Asuka-Ritsuko"

    # Cabang Kaji (via 10.78.4.122) — 1 rute
    add_route "10.78.4.100/30" "10.78.4.122" "Switch-Intel (Kaji)"

    # Cabang Misato (via 10.78.4.126) — 1 rute
    add_route "10.78.4.64/29"  "10.78.4.126" "Switch-Cage (Misato)"

    # Cabang Shigeru (via 10.78.4.130) — 3 subnet diringkas menjadi 2 rute
    add_route "10.78.4.80/28"  "10.78.4.130" "[RINGKAS] Switch-Monolith + Switch-Radar"
    add_route "10.78.4.168/30" "10.78.4.130" "Link Shigeru-Makoto"

    # Cabang Fuyutsuki (via 10.78.4.134) — 5 subnet diringkas menjadi 4 rute
    add_route "10.78.3.192/27" "10.78.4.134" "Switch-Medic (Maya)"
    add_route "10.78.4.56/29"  "10.78.4.134" "Switch-Terminal (Fuyutsuki)"
    add_route "10.78.4.72/29"  "10.78.4.134" "Switch-Dogma (Toji)"
    add_route "10.78.4.160/29" "10.78.4.134" "[RINGKAS] Link Fuyutsuki-Maya + Link Fuyutsuki-Toji"
}

# ------------------------------------------------------------------------------
# SOAL 4: DNS, PAKET MODUL, & NAT MASQUERADE
# ------------------------------------------------------------------------------
setup_soal4() {
    echo "=== [Soal 4] Konfigurasi DNS, Paket Modul, & NAT MASQUERADE ==="
    echo "nameserver $DNS_SERVER" > /etc/resolv.conf

    MISSING=""
    for cmd_pkg in "iptables:iptables" "conntrack:conntrack" "ifup:ifupdown"; do
        CMD="${cmd_pkg%%:*}"
        PKG="${cmd_pkg##*:}"
        if ! command -v "$CMD" >/dev/null 2>&1; then
            MISSING="$MISSING $PKG"
        fi
    done

    if [ -n "$MISSING" ]; then
        echo "[*] Memasang paket:$MISSING ..."
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y $MISSING
    fi

    # Fallback otomatis ke iptables-legacy jika nf_tables tidak didukung kernel (Modul §14)
    if ! iptables -t nat -S >/dev/null 2>&1; then
        echo "[!] iptables nft gagal, beralih ke iptables-legacy..."
        update-alternatives --set iptables /usr/sbin/iptables-legacy
    fi

    # Hanya NAT traffic dari prefix internal 10.78.0.0/16 yang keluar lewat NAT1 (eth0)
    if ! iptables -t nat -C POSTROUTING -s "$INTERNAL_PREFIX" -o "$IF_NAT" -j MASQUERADE 2>/dev/null; then
        iptables -t nat -A POSTROUTING -s "$INTERNAL_PREFIX" -o "$IF_NAT" -j MASQUERADE
        echo "    -> Rule NAT MASQUERADE ditambahkan."
    else
        echo "    -> Rule NAT MASQUERADE sudah terpasang (tidak dobel)."
    fi
}

# ------------------------------------------------------------------------------
# SOAL 5: PINTU DEPAN DIKUNCI RAPAT (DEFAULT DENY INPUT & FORWARD)
# ------------------------------------------------------------------------------
setup_soal5() {
    echo "=== [Soal 5] Konfigurasi Firewall Default Deny GENDO ==="

    # Urutan aman reset sesuai Modul §12.3: kembalikan policy ACCEPT dulu baru flush filter
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F INPUT
    iptables -F FORWARD
    iptables -F OUTPUT

    # --- CHAIN INPUT (lalu lintas menuju Gendo sendiri) ---
    # 1. Loopback tetap jalan
    iptables -A INPUT -i lo -j ACCEPT
    # 2. (a) Balasan koneksi yang sudah ada (stateful)
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # 3. DHCP dari sisi NAT1 (server UDP 67 -> client UDP 68) tetap jalan
    iptables -A INPUT -i "$IF_NAT" -p udp --sport 67 --dport 68 -j ACCEPT
    # 4. (d) Traffic dari jaringan internal ke Gendo sendiri (bukan dari eth0/NAT1)
    iptables -A INPUT ! -i "$IF_NAT" -s "$INTERNAL_PREFIX" -j ACCEPT

    # --- CHAIN FORWARD (lalu lintas melewati Gendo) ---
    # 1. (a) Balasan koneksi yang sudah ada (stateful)
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # 2. (b) Traffic dari jaringan internal ke internet (keluar lewat NAT1)
    iptables -A FORWARD ! -i "$IF_NAT" -o "$IF_NAT" -s "$INTERNAL_PREFIX" -j ACCEPT
    # 3. (c) Traffic antar-LAN internal (tidak masuk/keluar lewat NAT1)
    iptables -A FORWARD ! -i "$IF_NAT" ! -o "$IF_NAT" -s "$INTERNAL_PREFIX" -d "$INTERNAL_PREFIX" -j ACCEPT

    # Urutan aman Default Deny sesuai Modul §8.5: ubah policy ke DROP PALING AKHIR
    # Semua koneksi baru dari sisi NAT1 otomatis jatuh ke policy DROP.
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    echo "    -> Policy INPUT=DROP, FORWARD=DROP, OUTPUT=ACCEPT aktif."
}

show_status() {
    echo "============================================================"
    echo "Bukti iptables -S (Soal 5) - $(hostname) [debinet]"
    echo "============================================================"
    iptables -S
    echo "------------------------------------------------------------"
    echo "Tabel NAT (iptables -t nat -S):"
    iptables -t nat -S
    echo "------------------------------------------------------------"
    echo "Detail Counter Filter (iptables -L -n -v --line-numbers):"
    iptables -L -n -v --line-numbers
    echo "============================================================"
}

case "${1:-setup}" in
    routes)
        setup_soal3
        ip route
        ;;
    test)
        show_status
        echo ">>> Ping 8.8.8.8 dari Gendo (uji OUTPUT & ESTABLISHED):"
        ping -c 3 -W 2 8.8.8.8
        echo ""
        echo "[i] Untuk bukti lengkap Soal 5, jalankan juga di konsol Armisael:"
        echo "    ping -c 3 8.8.8.8"
        ;;
    *)
        setup_soal2
        setup_soal3
        setup_soal4
        setup_soal5
        show_status
        ;;
esac
