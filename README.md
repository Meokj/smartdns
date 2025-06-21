# 53端口空闲，则使用53端口并设置smartdns为默认DNS，否则使用5353端口

---
* 安装
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Meokj/smartdns/main/install_smartdns.sh)
```

* 卸载
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Meokj/smartdns/main/uninstall_smartdns.sh)
```

---

* 修改配置
```bash
nano /etc/smartdns/smartdns.conf
```
* 停止
```bash
sudo systemctl stop smartdns
```
* 重启
```bash
sudo systemctl restart smartdns
```
