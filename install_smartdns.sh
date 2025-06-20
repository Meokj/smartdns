#!/bin/bash
clear
set -e

check_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "请使用 root 权限运行！"
    exit 1
  fi
}

select_port() {
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
}

set_speed_thread() {
  CPU_THREADS=$(nproc)
  if [[ $CPU_THREADS -ge 2 ]]; then
    SPEED_THREAD=3
  else
    SPEED_THREAD=1
  fi
}

install_dependencies() {
  echo "[+] 安装 wget curl ca-certificates..."
  if apt install -y wget curl ca-certificates >/dev/null 2>&1; then
    echo "✅ 安装成功"
  else
    echo "❌ 安装失败，请检查网络或软件源"
    exit 1
  fi
}

download_and_install_smartdns() {
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
}

write_config() {
  echo "[+] 写入配置 /etc/smartdns/smartdns.conf ..."
  cat > /etc/smartdns/smartdns.conf <<EOF
bind 127.0.0.1:$PORT
cache-size 4096
rr-ttl-min 300
prefetch-domain yes
serve-expired yes
dualstack-ip-selection yes
speed-check-mode ping,tcp:443
speed-check-interval 10
speed-check-thread $SPEED_THREAD
timeout 4
server 8.8.8.8 -group g_dns -exclude-default-group
server 1.1.1.1 -group g_dns -exclude-default-group
server-tls https://dns.google/dns-query -group g_doh
server-tls https://cloudflare-dns.com/dns-query -group g_doh
server-group default g_doh
server-group fallback g_dns
EOF
}

restart_smartdns() {
  echo "[+] 重启并开机自启 SmartDNS..."
  systemctl enable smartdns
  systemctl restart smartdns

  echo "[+] 验证监听端口 127.0.0.1:$PORT ..."
  ss -tuln | grep -E "127\.0\.0\.1:$PORT\b" && echo "✅ 成功监听" || echo "⚠️ 没有监听，请检查"
}

set_as_default_dns() {
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
}

check_root
select_port
set_speed_thread
install_dependencies
download_and_install_smartdns
write_config
restart_smartdns
set_as_default_dns
