echo "=== IP ==="; ip -br a
echo "=== ROUTE ==="; ip route
echo "=== RULE ==="; ip rule
echo "=== FORWARD ==="; sysctl net.ipv4.ip_forward
echo "=== IPTABLES FILTER ==="; iptables -S 2>/dev/null || echo "iptables belum terpasang"
echo "=== IPTABLES NAT ==="; iptables -t nat -S 2>/dev/null || true