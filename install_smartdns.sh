#!/bin/bash
clear
set -e
if [[ $(id -u) -ne 0 ]]; then
  echo "请使用 root 权限运行！"
  exit 1
fi

echo "[+] 更新软件源并安装依赖..."
apt update -y
apt install -y wget curl ca-certificates

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) FILE="smartdns.1.2025.03.02-1533.x86_64-debian-all.deb" ;;
  aarch64|arm64) FILE="smartdns.1.2025.03.02-1533.aarch64-debian-all.deb" ;;
  armv7l) FILE="smartdns.1.2025.03.02-1533.arm-debian-all.deb" ;;
  *) echo "❌ 不支持架构：$ARCH" && exit 1 ;;
esac

URL="https://github.com/pymumu/smartdns/releases/download/Release46.1/$FILE"
echo "[+] 下载 SmartDNS：$FILE"
if ! curl --head --silent --fail "$URL" > /dev/null; then
  echo "❌ 文件不存在：$URL"
  exit 1
fi
wget -O "/tmp/$FILE" "$URL"

echo "[+] 安装 SmartDNS..."
dpkg -i "/tmp/$FILE" || apt install -f -y

echo "[+] 写入配置 /etc/smartdns/smartdns.conf ..."
cat > /etc/smartdns/smartdns.conf <<EOF
bind 127.0.0.1:5353
cache-size 4096

# 开启双栈模式
dual-stack-mode yes

# 预取域名缓存
prefetch-domain yes

server 8.8.8.8
server 1.1.1.1
server 223.5.5.5

# 设置日志级别为无日志
log-level none

# 如果想开启日志，取消下面注释
# log-level info
# log-file /var/log/smartdns.log
EOF

echo "[+] 重启并开机自启 SmartDNS..."
systemctl enable smartdns
systemctl restart smartdns

echo "[+] 验证监听端口 127.0.0.1:5353 ..."
ss -tuln | grep 5353 && echo "✅ 成功监听" || echo "⚠️ 没有监听，请检查"

echo -e "\n✅ 安装完成！"

