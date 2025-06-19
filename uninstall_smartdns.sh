#!/bin/bash
clear
set -e

if [[ $(id -u) -ne 0 ]]; then
  echo "请使用 root 权限运行！"
  exit 1
fi

echo "[+] 停止 SmartDNS 服务..."
systemctl stop smartdns

echo "[+] 禁用 SmartDNS 开机启动..."
systemctl disable smartdns

echo "[+] 卸载 SmartDNS 包..."
apt-get remove --purge -y smartdns || dpkg -r smartdns || echo "SmartDNS 可能未安装"

echo "[+] 删除配置文件和缓存..."
rm -rf /etc/smartdns
rm -rf /var/cache/smartdns

echo "[+] 删除 systemd 服务文件（如果存在）..."
rm -f /lib/systemd/system/smartdns.service
rm -f /etc/systemd/system/multi-user.target.wants/smartdns.service

echo "[+] 重新加载 systemd 配置..."
systemctl daemon-reload

echo -e "\n✅ SmartDNS 已完全卸载！"
