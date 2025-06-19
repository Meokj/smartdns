* 1. SmartDNS 接收网络设备的 DNS 查询请求，如 PC、手机的查询请求；
* 2. 然后将查询请求发送到多个上游 DNS 服务器，可支持 UDP 标准端口或非标准端口查询，以及 TCP 查询；
* 3. 上游 DNS 服务器返回域名对应的服务器 IP 地址列表，SmartDNS 则会检测从客户端访问速度最快的服务器 IP；
* 4 .最后将访问速度最快的服务器 IP 返回给客户端。

---

* 安装
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Meokj/smartdns/main/install_smartdns.sh)
```

* 卸载
```bash
bash <(curl -Ls https://raw.githubusercontent.com/Meokj/smartdns/main/uninstall_smartdns.sh)
```
