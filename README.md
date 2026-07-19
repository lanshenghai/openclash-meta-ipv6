# OpenClash / Mihomo `meta-ipv6` 调优记录

面向：**OpenWrt / OpenClash + Mihomo + 双栈 IPv6** 软路由场景。  
整理 Access Check、YouTube/Telegram、头条、test-ipv6、IPv6 代理、**LAN 大文件下载** 等问题后的可分享配置与结论。

## 仓库文件

| 文件 | 说明 |
|------|------|
| `README.md` | 完整说明（本文） |
| `meta-ipv6.yaml` | **模式 A**：`fake-ip` + Redirect（默认推荐日常双栈） |
| `meta-ipv6-tun.yaml` | **模式 B**：`redir-host` + TUN + Sniffer（修复 LAN 大文件/透明代理问题） |
| `scripts/patch-tun-mtu.sh` | TUN MTU 覆写脚本（OpenClash 无 UCI 项时用） |

> **安全：** 配置中的订阅链接、API secret、内网 IP 已替换为 `REPLACE_*` 占位符。请用你自己的订阅与密钥。

---

## 两种模式怎么选

| | **模式 A：fake-ip + Redirect** | **模式 B：redir-host + TUN** |
|--|-------------------------------|------------------------------|
| 配置文件 | `meta-ipv6.yaml` | `meta-ipv6-tun.yaml` |
| DNS | `fake-ip` + `fake-ip-range6` | `redir-host`（真实 A/AAAA） |
| 流量入口 | nft `redirect :7892` + IPv6 Redirect | **TUN `utun`**（插件注入，勿手写 `tun:`） |
| 境外 IPv6 默认 | `MATCH,DIRECT`（原生拨号） | `MATCH,代理`（全屋 IPv6 翻墙） |
| Sniffer | 可选 | **必须开**（redir-host 靠嗅探补域名） |
| 优点 | DNS 快、分流成熟、境外 IPv6 直连省节点流量 | LAN 大文件稳定、DNS 返回真实 IP、少 fake-ip 副作用 |
| 缺点 | LAN 侧 `redir` 对大文件长连接不友好；fake-ip 偶发解析/IPv6 混乱 | 依赖 Sniffer + DNS 劫持；LAN 吞吐低于路由器本机；配置项更多 |
| 适用 | 日常浏览、test-ipv6、头条/YouTube 已调通 | Cursor/VS Code Remote 装 Server、WSL 大文件下载、LAN 长连接易断 |

### 实测参考（同一 124MB 文件，2026-07）

| 路径 | fake-ip + redir | TUN + system 栈 + MTU 1400 |
|------|-----------------|---------------------------|
| 路由器 WAN 本机 | ~25 MB/s | ~14 MB/s（13s 下完） |
| Windows LAN | 慢/易断 | **~8 MB/s**（14s 下完） |
| WSL2 LAN | ~8 KB/s，10MB 后卡死 | **~2 MB/s**（57s 下完） |

TUN 不能消除 LAN 与 WAN 本机的性能差，但能把「不可用」提升到「可用」。

---

## 模式 A：fake-ip + Redirect（`meta-ipv6.yaml`）

### 适用环境

- 软路由 OpenWrt + OpenClash
- 运行模式：`fake-ip`
- IPv6：PPPoE 获前缀，LAN 下发 GUA；客户端双栈
- 上游可能有光猫 / AC

### 核心结论（一句话）

| 现象 | 根因 | 处理 |
|------|------|------|
| Access Check 国内站超时 | CN DNS 仅走失效的 IPv6 DNS + `respect-rules` | CN/`direct-nameserver` 改用 IPv4 DNS |
| YouTube / Telegram「连不上」 | 精简规则时删掉专用 RULE-SET，流量变 DIRECT | 恢复 YouTube / Telegram 规则集 |
| 今日头条有字无图 | Reject 误杀 + 国内 CDN IPv6 被送进代理 | 字节系白名单 DIRECT + `china_ip6_route=1` |
| test-ipv6 主测「无 IPv6」 | filter 未覆盖子域 / 或 IPv6 TProxy 把流量送到 LuCI | `+.test-ipv6.com` + **IPv6 改 Redirect** |
| 「其他 IPv6 网站」大片失败 | `IP-CIDR6,::/0 → 代理`，节点无 IPv6 | 删除该条，默认 `MATCH,DIRECT` |
| 要假 IP 同时还能用 IPv6 | 无 `fake-ip-range6` 时不下发 AAAA | 启用非 ULA 的 `fake-ip-range6` |
| LAN 大文件下载卡住 | PREROUTING `redirect :7892` 对大流量长连接不稳 | **改用模式 B（TUN）** |

### 推荐流量模型

```text
客户端双栈
  ├─ IPv4：OpenClash 接管 → Clash rules（代理 / DIRECT）
  └─ IPv6：
        ├─ 国内前缀（china_ip6_route）→ 旁路直连，不进 Clash
        └─ 其余 → Redirect 进 Clash
              ├─ YouTube / Telegram / PROXY / … → 代理
              └─ 其余 → MATCH,DIRECT（原生拨号，不强制进节点）
```

DNS：`fake-ip` + `fake-ip-range6`；`fake-ip-filter`（blacklist）里的域名拿真实 IP。

### 不要做的事

- 不要用 **IPv6 TProxy**（本环境会把境外 HTTPS 送到 OpenWrt `uhttpd:443`，证书变成 `CN=OpenWrt`）。
- 不要用 `IP-CIDR6,::/0,代理`「一网打尽」——节点通常没有可用 IPv6。
- 不要把所有境外站塞进 `fake-ip-filter`；分流靠 **rules**，filter 只给「必须真实 IP」的域名。

### OpenClash UCI（模式 A）

```sh
uci set openclash.config.config_path='/etc/openclash/config/meta-ipv6.yaml'
uci set openclash.config.en_mode='fake-ip'
uci set openclash.config.operation_mode='fake-ip'
uci set openclash.config.proxy_mode='rule'

uci set openclash.config.ipv6_enable='1'
uci set openclash.config.ipv6_mode='1'          # Redirect，勿用 TProxy(0)
uci set openclash.config.china_ip6_route='1'
uci set openclash.config.ipv6_dns='1'
uci set openclash.config.fakeip_range6='2a0f:fafa:cafe::1/64'

uci set openclash.config.enable_redirect_dns='1'
uci set openclash.config.filter_aaaa_dns='0'
uci set openclash.config.enable_respect_rules='1'

uci commit openclash
/etc/init.d/openclash restart
```

---

## 模式 B：redir-host + TUN（`meta-ipv6-tun.yaml`）

### 为何需要 TUN

OpenClash 对 **LAN 客户端** 的外网 TCP 走：

```text
LAN 设备 → PREROUTING / openclash → redirect :7892 → Clash → FORWARD 回 LAN
```

路由器本机下载走 `OUTPUT`，不经 FORWARD，因此「路由器快、LAN 慢/断」是路径差异，不是 WAN 带宽问题。  
切换到 **TUN** 后，流量经 `utun` 虚拟网卡进 Clash 内核栈，大文件长连接明显改善。

社区相关讨论：[OpenClash #2761](https://github.com/vernesong/OpenClash/issues/2761)、[#5153](https://github.com/vernesong/OpenClash/issues/5153)、[#623](https://github.com/vernesong/OpenClash/issues/623)。

### yaml 配置要点

1. **不要**在 yaml 里手写 `tun:` 段——OpenClash 启动时会注入并覆盖。
2. DNS 用 `enhanced-mode: redir-host`（返回真实 IP，告别 `198.18.x` / `2a0f:fafa:cafe::` fake-ip）。
3. **必须**启用 `sniffer`（HTTP/TLS/QUIC），否则 redir-host 下按 IP 连接时分流不准。
4. 默认规则改为 `MATCH,代理`（境外 IPv6 也走节点）；国内仍靠 `GEOIP,CN` + `china_ip6_route` 旁路。
5. 大文件域名（如 `cursor.com`）可按需 `DIRECT` 绕过 TUN 长连接开销。
6. **删除** `IP-CIDR,198.18.0.1/16,REJECT`（redir-host 不再使用 fake-ip 段）。

### OpenClash UCI（模式 B）

```sh
uci set openclash.config.config_path='/etc/openclash/config/meta-ipv6-tun.yaml'
uci set openclash.config.en_mode='redir-host-tun'
uci set openclash.config.operation_mode='redir-host'
uci set openclash.config.proxy_mode='rule'

uci set openclash.config.ipv6_enable='1'
uci set openclash.config.china_ip6_route='1'
uci set openclash.config.ipv6_dns='1'
uci set openclash.config.enable_udp_proxy='1'

# TUN 栈：实测 system + MTU 1400 优于默认 gvisor + MTU 9000
uci set openclash.config.stack_type='system'

uci set openclash.config.enable_redirect_dns='1'
uci set openclash.config.enable_respect_rules='1'

uci commit openclash
/etc/init.d/openclash restart
```

### TUN MTU（无 UCI 项）

OpenClash 默认 `utun` MTU **9000**，在 PPPoE + TUN 叠加时易触发静默丢包。推荐 **1400**：

```sh
# 将 scripts/patch-tun-mtu.sh 复制到路由器后执行
sh patch-tun-mtu.sh 1400
/etc/init.d/openclash restart

# 验证
ip link show utun | grep mtu
grep -A3 '^tun:' /etc/openclash/meta-ipv6-tun.yaml
# 应看到 stack: system, mtu: 1400
```

或在 `/etc/openclash/custom/openclash_custom_overwrite.sh` 末尾（`exit 0` 前）加入：

```sh
ruby_edit "$CONFIG_FILE" "['tun']['mtu']" "1400"
```

### 推荐流量模型（TUN）

```text
LAN 客户端
  → dnsmasq → OpenClash DNS (redir-host, 真实 IP)
  → nft → TUN utun (system 栈, MTU 1400)
  → Clash rules
       ├─ GEOIP,CN / Domestic / 白名单 → DIRECT
       ├─ YouTube / Telegram / PROXY → 代理
       └─ MATCH → 代理（含境外 IPv6）
```

### 客户端注意事项

- **DNS 在路由器上**，不是 Windows 本机程序截获。截获发生在 `192.168.124.2` 的 dnsmasq → OpenClash。
- Windows Wi-Fi 若 IPv6 DNS 为 `fe80::1` 且查询超时，部分应用会解析失败。建议改为路由器 GUA（如 `240e:…::1`）或仅用 IPv4 DNS `192.168.124.2`。
- 浏览器「安全 DNS / DoH」若绕过路由器，可能导致分流失效。

### 自检（模式 B）

```sh
# 进程与 TUN
pgrep -a clash
ip link show utun

# DNS 应返回真实 IP，而非 198.18.x
dig @192.168.124.2 google.com A +short
dig @192.168.124.2 downloads.cursor.com A +short

# 大文件（在 LAN 客户端）
curl -4 -L -o /dev/null -w 'size=%{size_download} speed=%{speed_download}\n' \
  'https://downloads.cursor.com/production/<commit>/linux/x64/cursor-reh-linux-x64.tar.gz'
```

### 回滚到模式 A

```sh
cp /etc/config/openclash.bak.<date> /etc/config/openclash   # 若有备份
uci set openclash.config.config_path='/etc/openclash/config/meta-ipv6.yaml'
uci set openclash.config.en_mode='fake-ip'
uci set openclash.config.operation_mode='fake-ip'
uci delete openclash.config.stack_type   # 或设回 gvisor
uci commit openclash
/etc/init.d/openclash restart
```

---

## 共用规则与 DNS 要点

### DNS（两模式通用）

- `nameserver-policy: geosite:cn` 与 `direct-nameserver` 使用可用 **IPv4** DNS（运营商 + 114 / 223.5.5.5）。
- `respect-rules: true` 时，直连域名走 `direct-nameserver`，避免再走失效的 ISP IPv6 DNS。
- `fallback` 保留 DoH/DoT 用于境外解析。

### rule-providers（保留集）

Reject、AppleMusic、AppleTV、Apple、GoogleFCM、**YouTube**、**Telegram**、PROXY、Domestic。

**必须恢复 YouTube / Telegram**：通用 PROXY 列表不完整，删掉会导致 App「连不上」。

### rules 顺序（摘要）

1. 基础设施 / 内网 / NTP / test-ipv6 → DIRECT  
2. 办公、OneDrive、坚果等 → DIRECT  
3. 指定代理（OpenAI、Copilot 等）  
4. **头条/字节系 DIRECT（须在 Reject 之前）**  
5. Reject → REJECT  
6. YouTube / Telegram / Apple 媒体 → 代理；Apple / FCM → DIRECT  
7. PROXY → 代理；Domestic → DIRECT；GEOIP,CN → DIRECT  
8. 兜底：`MATCH,DIRECT`（模式 A）或 `MATCH,代理`（模式 B）

---

## 部署步骤

### 模式 A

1. 复制 `meta-ipv6.yaml` → `/etc/openclash/config/meta-ipv6.yaml`
2. 填入 `proxy-providers`、`secret`、`external-controller`
3. 按上文 UCI 设置 fake-ip + IPv6 Redirect
4. 重启并验证 test-ipv6 / YouTube / 国内站

### 模式 B

1. 复制 `meta-ipv6-tun.yaml` → `/etc/openclash/config/meta-ipv6-tun.yaml`
2. 填入订阅与密钥（同上）
3. 按上文 UCI 设置 `redir-host-tun` + `stack_type=system`
4. 运行 `scripts/patch-tun-mtu.sh 1400` 设置 MTU
5. 重启；在 LAN 客户端测大文件下载与 Google/YouTube

路径 `./rule_provider/`、`./providers/` 相对 OpenClash 工作目录；首次启动会自动拉取规则集与节点。

---

## 界面对照（UCI）

| UCI | 界面大致名称 |
|-----|----------------|
| `en_mode` | 运行模式（fake-ip / redir-host-tun） |
| `stack_type` | TUN 堆栈（system / gvisor / mixed） |
| `ipv6_enable` | 代理 IPv6 流量 |
| `ipv6_mode` | IPv6 代理模式（模式 A 用 Redirect=1） |
| `china_ip6_route` | 绕过中国大陆 IPv6 |
| `ipv6_dns` | IPv6 DNS 解析 |
| `fakeip_range6` | Fake-IP Range IPv6（仅模式 A） |

---

## License / 来源

规则集 URL 使用 [dler-io/Rules](https://github.com/dler-io/Rules)（jsDelivr）。配置结构供学习与自用，请自行替换订阅与隐私信息。
