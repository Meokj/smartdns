#!/bin/bash

# 创建 curl 输出格式文件
cat > curl-format.txt <<EOF
\n
Time to resolve:  %{time_namelookup}s
Time to connect:  %{time_connect}s
Time to TLS:      %{time_appconnect}s
Time to first byte: %{time_starttransfer}s
Total time:       %{time_total}s
\n
EOF

# 使用 SmartDNS（监听在 127.0.0.1:5353）
echo "🔍 Using SmartDNS (127.0.0.1:5353):"
SMARTDNS_IP=$(dig @127.0.0.1 -p 5353 +short www.youtube.com | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
if [ -z "$SMARTDNS_IP" ]; then
  echo "❌ Failed to get IP from SmartDNS."
else
  echo "Resolved IP: $SMARTDNS_IP"
  curl -o /dev/null -s -w "@curl-format.txt" --resolve www.youtube.com:443:$SMARTDNS_IP https://www.youtube.com
fi

# 使用系统默认 DNS
echo -e "\n🌐 Using system default DNS:"
curl -o /dev/null -s -w "@curl-format.txt" https://www.youtube.com

# 清理格式文件
rm -f curl-format.txt
