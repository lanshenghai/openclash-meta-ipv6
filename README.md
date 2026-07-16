# OpenClash / Mihomo `meta-ipv6` 调优记录

面向：**OpenWrt / OpenClash + Mihomo（fake-ip）+ 双栈 IPv6** 软路由场景。  
整理修复 Access Check、YouTube/Telegram、头条、test-ipv6、IPv6 代理模式等问题后的**可分享配置与结论**。

本仓库文件：

| 文件 | 说明 |
|------|------|
| `README.md` | 完整说明（本文） |
| `meta-ipv6.yaml` | 脱敏后的 Clash Meta 配置样例 |

> **安全：** `meta-ipv6.yaml` 中的订阅链接、API secret、内网 IP 已替换为占位符。请用你自己的订阅与密钥。

---

## 适用环境（参考）

- 软路由 OpenWrt + OpenClash
- 运行模式：`fake-ip`
- IPv6：PPPoE 获前缀，LAN 下发 GUA；客户端双栈
- 上游可能有光猫 / AC（本记录中为 H3C BR1008L + 软路由）

## 核心结论（一句话）

| 现象 | 根因 | 处理 |
|------|------|------|
| Access Check 国内站超时 | CN DNS 仅走失效的 IPv6 DNS + `respect-rules` | CN/`direct-nameserver` 改用 IPv4 DNS |
| YouTube / Telegram「连不上」 | 精简规则时删掉专用 RULE-SET，流量变 DIRECT | 恢复 YouTube / Telegram 规则集 |
| 今日头条有字无图 | Reject 误杀 + 国内 CDN IPv6 被送进代理 | 字节系白名单 DIRECT + `china_ip6_route=1` |
| test-ipv6 主测「无 IPv6」 | filter 未覆盖子域 / 或 IPv6 TProxy 把流量送到 LuCI | `+.test-ipv6.com` + **IPv6 改 Redirect** |
| 「其他 IPv6 网站」大片失败 | `IP-CIDR6,::/0 → 代理`，节点无 IPv6 | 删除该条，默认 `MATCH,DIRECT`，按规则决定 |
| 要假 IP 同时还能用 IPv6 | 无 `fake-ip-range6` 时不下发 AAAA | 启用非 ULA 的 `fake-ip-range6` |

## 当前推荐流量模型

```text
客户端双栈
  ├─ IPv4：OpenClash 接管 → Clash rules（代理 / DIRECT）
  └─ IPv6：
        ├─ 国内前缀（china_ip6_route）→ 旁路直连，不进 Clash
        └─ 其余 → Redirect 进 Clash
              ├─ YouTube / Telegram / PROXY / … → 代理
              └─ 其余 → MATCH,DIRECT（原生拨号，不强制进节点）
```

DNS：`fake-ip` + `fake-ip-range6`；`fake-ip-filter`（blacklist）里的域名拿真实 IP（含 `geosite:cn`、`+.test-ipv6.com` 等）。

## 不要做的事

- 不要用 **IPv6 TProxy**（本环境会把境外 HTTPS 送到 OpenWrt `uhttpd:443`，证书变成 `CN=OpenWrt`）。
- 不要用 `IP-CIDR6,::/0,代理`「一网打尽」——节点通常没有可用 IPv6。
- 不要把所有境外站塞进 `fake-ip-filter`；分流靠 **rules**，filter 只给「必须真实 IP」的域名。
- 分享到 GitHub 前务必去掉订阅 token。

---

## 改动清单

### 1. DNS（Access Check / 国内站解析）

- `nameserver-policy: geosite:cn`：由仅 `240e:` ISP IPv6 DNS 改为 IPv4（运营商 DNS + `114` / `223.5.5.5`）。
- 增加 `direct-nameserver`（同上 IPv4 集合），配合 `respect-rules: true`。
- `nameserver` 同步为可用 IPv4；`fallback` 保留 DoH/DoT。
- `dns.ipv6: true`；启用 `fake-ip-range6`（见下）。

### 2. fake-ip / IPv6 DNS 表现

- `fake-ip-filter` 使用 **blacklist**。
- 增加 `+.test-ipv6.com`（必须 `+.`，否则 `www` / `ipv6` 子域仍进 fake-ip，主测显示「无 IPv6」）。
- 保留 `geosite:cn`、办公/Nokia、坚果、NTP、MS 连通性探测等真实 IP 名单。
- 启用 `fake-ip-range6: 2a0f:fafa:cafe::/64`（避免常用 ULA `fdfe:` 在部分 Windows 客户端被丢掉 AAAA）。
- OpenClash UCI：`fakeip_range6` 与 yaml 一致；`ipv6_dns=1`；`filter_aaaa_dns=0`。

### 3. 代理组精简

- 删除未使用的 `US_PROXY` / `GlobalTV` / `ChinaTV` / `AdBlock` 等组。
- 保留：`自动选择`（url-test）→ `代理`（select：自动选择 / DIRECT）。
- 广告：`RULE-SET,Reject,REJECT`（不再经 AdBlock 组）。

### 4. rule-providers

**保留：** Reject、AppleMusic、AppleTV、Apple、GoogleFCM、YouTube、Telegram、PROXY、Domestic。

**删除/避免：**

- 行为与格式不匹配的 `DomesticIPs`（`ruleCount=0`）。
- 与 PROXY/Domestic/MATCH 重复的媒体/支付等集。
- 过宽的 ChatGPT 集（改为规则里内联 openai/chatgpt 等域名）。

**重要恢复：**

- **YouTube**：通用 PROXY 不含完整 youtube 域名。
- **Telegram**：含域名 + DC `IP-CIDR`/`IP-CIDR6`，否则 App 一直「连接中」。

路径统一为 `./rule_provider/...`。

### 5. rules 顺序与语义

1. 基础设施 / 内网 / NTP / `test-ipv6.com` → DIRECT  
2. 办公、坚果等 → DIRECT  
3. 指定代理（Copilot、OpenAI 等）  
4. **头条/字节系白名单 DIRECT（须在 Reject 之前）**  
5. Reject → REJECT  
6. YouTube / Telegram / Apple 媒体 → 代理；Apple / FCM → DIRECT  
7. PROXY → 代理；Domestic → DIRECT；GEOIP,CN → DIRECT  
8. **`MATCH,DIRECT`**（已删除 `IP-CIDR6,::/0,代理`）

### 6. OpenClash IPv6 运行参数（非 yaml）

| 项 | 推荐值 | 说明 |
|----|--------|------|
| 代理 IPv6 流量 | 开 | `ipv6_enable=1` |
| IPv6 代理模式 | **Redirect** | `ipv6_mode=1`（勿用 TProxy=0） |
| 中国 IPv6 绕过 | 开 | `china_ip6_route=1`（界面：实验性绕过中国大陆 IPv6 / 区域绕过） |
| IPv6 DNS 解析 | 开 | `ipv6_dns=1` |
| Fake-IP Range6 | `2a0f:fafa:cafe::1/64` | 与 yaml 一致 |

**TProxy 坑：** 本环境 IPv6 TProxy + `local default` fwmark 路由会导致境外 HTTPS 落到 **uhttpd:443**，浏览器看到 `CN=OpenWrt` 自签证书 → test-ipv6 / 境外站失败。Redirect 可避免。

### 7. 未改动的个人化内容（分享时需自备）

- `proxy-providers` 订阅 URL / token  
- `secret`、控制器地址  
- 内网监听 IP（样例中已占位）  
- Nokia / 坚果等个人直连域名（可删可留）

---

## OpenClash UCI / 界面配套项

以下与 `meta-ipv6.yaml` **一起**生效；只更新 yaml 不够。

### 推荐设置

```sh
uci set openclash.config.enable='1'
uci set openclash.config.config_path='/etc/openclash/config/meta-ipv6.yaml'   # 按实际路径
uci set openclash.config.en_mode='fake-ip'
uci set openclash.config.proxy_mode='rule'

# IPv6（关键）
uci set openclash.config.ipv6_enable='1'
uci set openclash.config.ipv6_mode='1'          # 0=TProxy 1=Redirect 2=TUN 3=Mix；请用 1
uci set openclash.config.china_ip6_route='1'
uci set openclash.config.ipv6_dns='1'
uci set openclash.config.enable_v6_udp_proxy='1'
uci set openclash.config.fakeip_range6='2a0f:fafa:cafe::1/64'

# DNS
uci set openclash.config.enable_redirect_dns='1'
uci set openclash.config.filter_aaaa_dns='0'
uci set openclash.config.enable_respect_rules='1'

uci commit openclash
/etc/init.d/openclash restart
```

### 界面对照（中文）

| UCI | 界面大致名称 |
|-----|----------------|
| `ipv6_enable` | 代理 IPv6 流量 |
| `ipv6_mode=1` | IPv6 代理模式 → **Redirect 模式** |
| `china_ip6_route=1` | 实验性：绕过中国大陆 IPv6 / 概览「区域绕过→大陆」相关 |
| `ipv6_dns` | IPv6 DNS 解析 |
| `fakeip_range6` | Fake-IP Range (IPv6) |

### 自检

```sh
uci get openclash.config.ipv6_mode          # 应为 1
uci get openclash.config.china_ip6_route    # 应为 1
grep -nE 'fake-ip-range6|MATCH,DIRECT|Telegram|YouTube' /etc/openclash/config/meta-ipv6.yaml

# IPv6 测站（应直连成功，且证书不是 OpenWrt）
curl -6 -sS -o /dev/null -w '%{http_code} %{remote_ip}\n' --connect-timeout 8 https://ipv6.test-ipv6.com/

# 应走代理规则的服务
curl -sS -o /dev/null -w 'yt=%{http_code}\n' --connect-timeout 10 https://www.youtube.com/generate_204
curl -sS -o /dev/null -w 'tg=%{http_code}\n' --connect-timeout 10 https://api.telegram.org/
```

若 `curl -6` 到境外站拿到 **OpenWrt 自签证书**，说明仍在用坏的 TProxy 路径：把 `ipv6_mode` 改为 `1` 并重启。

---

## 部署步骤

1. 复制 `meta-ipv6.yaml` 到软路由，例如：  
   `/etc/openclash/config/meta-ipv6.yaml`
2. 填入自己的 `proxy-providers` 订阅、`secret`、`external-controller` / `listen` 地址。
3. 按上文「OpenClash UCI」设置 IPv6 Redirect + `china_ip6_route` + `fakeip_range6`。
4. OpenClash 选择该配置并重启。
5. 客户端 DNS 指向软路由（或 AC 上游指向软路由），避免公司电脑本地 DNS 劫持导致 AAAA 异常。
6. 验证：
   - https://www.test-ipv6.com/ （主测应能检测到 IPv6）
   - YouTube / Telegram
   - 国内站（百度等）与头条图文

路径 `./rule_provider/`、`./providers/` 相对 OpenClash 工作目录；首次启动会自动拉取规则集与节点。

---

## License / 来源

规则集 URL 使用 [dler-io/Rules](https://github.com/dler-io/Rules)（jsDelivr）。配置结构供学习与自用，请自行替换订阅与隐私信息。
