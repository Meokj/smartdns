#!/bin/bash
clear
set -e
if [[ $(id -u) -ne 0 ]]; then
  echo "请使用 root 权限运行！"
  exit 1
fi

if ss -tuln | grep -q ':53 '; then
  if ss -tuln | grep -q ':5353 '; then
    echo "端口 53 和 5353 都被占用"
    exit 1
  else
    PORT=5353
  fi
else
  PORT=53
fi
echo "SmartDNS 将使用端口: $PORT"

CPU_THREADS=$(nproc)
if [[ $CPU_THREADS -ge 2 ]]; then
  SPEED_THREAD=3
else
  SPEED_THREAD=1
fi

echo "[+] 安装 wget curl ca-certificates..."
if apt install -y wget curl ca-certificates >/dev/null 2>&1; then
  echo "✅ 安装成功"
else
  echo "❌ 安装失败，请检查网络或软件源"
  exit 1
fi

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
wget --no-check-certificate -q -O "/tmp/$FILE" "$URL"

echo "[+] 安装 SmartDNS..."
dpkg -i "/tmp/$FILE" > /dev/null 2>&1 || {
  echo "⚠️ dpkg 安装失败，尝试修复依赖..."
  apt install -f -y > /dev/null 2>&1
}

echo "[+] 写入配置 /etc/smartdns/smartdns.conf ..."
cat > /etc/smartdns/smartdns.conf <<EOF
# ===========================
# SmartDNS 优化完整配置示例
# ===========================

# 监听地址和端口
# SmartDNS监听本机127.0.0.1的如下端口，通常配合本地代理或系统DNS使用
bind 127.0.0.1:$PORT

# DNS缓存大小，单位是条目数
# 4096条记录能有效减少重复查询，提高解析速度
cache-size 4096

# 最小缓存TTL（秒）
# 缓存中DNS记录的最短存活时间，防止频繁刷新，设置为300秒（5分钟）
rr-ttl-min 300

# 启用预取功能
# 常用域名会自动提前解析，提升响应速度
prefetch-domain yes

# 启用过期记录服务
# 解析缓存过期时仍会返回旧记录，避免因解析失败导致网络中断
serve-expired yes

# 启用双栈IP选择
# 智能选择IPv4或IPv6中响应更快的IP返回，提升连接速度和稳定性
dualstack-ip-selection yes

# ----------------- 以下为Fast IP测速相关配置 -----------------

# 启用测速模式
# 先用ping测试延迟，不通再用TCP 443端口测试，确保测速准确
speed-check-mode ping,tcp:443

# 测速间隔（秒）
# 表示每隔10秒重新测速一次，保证IP质量实时更新
speed-check-interval 10

# 测速线程数量
# 同时开启3个线程并发测速，适合2核CPU，平衡速度和资源占用
# 同时开启1个线程并发测速，适合1核CPU，平衡速度和资源占用
speed-check-thread $SPEED_THREAD 

# DNS请求超时时间（秒）
# 超过4秒未响应则视为失败
timeout 4

# ----------------- 上游 DNS 服务器配置（分组管理） -----------------

# 普通DNS服务器组 g_dns，包含谷歌和Cloudflare的公共DNS
# -exclude-default-group 参数避免自动加入默认组，方便自定义管理
server 8.8.8.8 -group g_dns -exclude-default-group
server 1.1.1.1 -group g_dns -exclude-default-group

# DoH（DNS over HTTPS）服务器组 g_doh，包含谷歌和Cloudflare的DoH地址
server-tls https://dns.google/dns-query -group g_doh
server-tls https://cloudflare-dns.com/dns-query -group g_doh

# 设置默认使用的服务器组为 g_doh
# 优先使用安全的DoH服务器，提高隐私和安全性
server-group default g_doh

# 设置备用服务器组为 g_dns
# 当默认组不可用时自动切换到普通DNS服务器
server-group fallback g_dns
EOF

echo "[+] 重启并开机自启 SmartDNS..."
systemctl enable smartdns
systemctl restart smartdns

echo "[+] 验证监听端口 127.0.0.1:$PORT ..."
ss -tuln | grep -E "127\.0\.0\.1:$PORT\b" && echo "✅ 成功监听" || echo "⚠️ 没有监听，请检查"

if [ "$PORT" = "53" ]; then
  if systemctl list-unit-files | grep -q '^systemd-resolved\.service'; then
    echo "🛠 关闭 systemd-resolved 服务..."
    sudo systemctl disable --now systemd-resolved
  else
    echo "ℹ️ systemd-resolved 服务不存在，跳过关闭操作。"
  fi

  echo "🔄 备份 /etc/resolv.conf（如果存在）..."
  if [ -f /etc/resolv.conf ]; then
    sudo cp /etc/resolv.conf /etc/resolv.conf.bak.$(date +%s)
  fi

  echo "🧹 移除 /etc/resolv.conf 软链接（如果是）..."
  if [ -L /etc/resolv.conf ]; then
    sudo rm -f /etc/resolv.conf
  fi

  echo "📝 创建新的 resolv.conf 文件..."
  sudo bash -c 'cat > /etc/resolv.conf' <<EOF
nameserver 127.0.0.1
nameserver 2001:4860:4860::8888
nameserver 2001:4860:4860::8844
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
sudo chmod 644 /etc/resolv.conf

  echo "✅ 53 端口空闲，已设置 smartdns 为系统默认 DNS 优先使用，当前 /etc/resolv.conf 内容如下："
  cat /etc/resolv.conf
fi




