# 改动清单（CHANGELOG）

## 1. DNS（Access Check / 国内站解析）

- `nameserver-policy: geosite:cn`：由仅 `240e:` ISP IPv6 DNS 改为 IPv4（运营商 DNS + `114` / `223.5.5.5`）。
- 增加 `direct-nameserver`（同上 IPv4 集合），配合 `respect-rules: true`。
- `nameserver` 同步为可用 IPv4；`fallback` 保留 DoH/DoT。
- `dns.ipv6: true`；启用 `fake-ip-range6`（见下）。

## 2. fake-ip / IPv6 DNS 表现

- `fake-ip-filter` 使用 **blacklist**。
- 增加 `+.test-ipv6.com`（必须 `+.`，否则 `www` / `ipv6` 子域仍进 fake-ip，主测显示「无 IPv6」）。
- 保留 `geosite:cn`、办公/Nokia、坚果、NTP、MS 连通性探测等真实 IP 名单。
- 启用 `fake-ip-range6: 2a0f:fafa:cafe::/64`（避免常用 ULA `fdfe:` 在部分 Windows 客户端被丢掉 AAAA）。
- OpenClash UCI：`fakeip_range6` 与 yaml 一致；`ipv6_dns=1`；`filter_aaaa_dns=0`。

## 3. 代理组精简

- 删除未使用的 `US_PROXY` / `GlobalTV` / `ChinaTV` / `AdBlock` 等组。
- 保留：`自动选择`（url-test）→ `代理`（select：自动选择 / DIRECT）。
- 广告：`RULE-SET,Reject,REJECT`（不再经 AdBlock 组）。

## 4. rule-providers

**保留：** Reject、AppleMusic、AppleTV、Apple、GoogleFCM、YouTube、Telegram、PROXY、Domestic。

**删除/避免：**

- 行为与格式不匹配的 `DomesticIPs`（`ruleCount=0`）。
- 与 PROXY/Domestic/MATCH 重复的媒体/支付等集。
- 过宽的 ChatGPT 集（改为规则里内联 openai/chatgpt 等域名）。

**重要恢复：**

- **YouTube**：通用 PROXY 不含完整 youtube 域名。
- **Telegram**：含域名 + DC `IP-CIDR`/`IP-CIDR6`，否则 App 一直「连接中」。

路径统一为 `./rule_provider/...`。

## 5. rules 顺序与语义

1. 基础设施 / 内网 / NTP / `test-ipv6.com` → DIRECT  
2. 办公、坚果等 → DIRECT  
3. 指定代理（Copilot、OpenAI 等）  
4. **头条/字节系白名单 DIRECT（须在 Reject 之前）**  
5. Reject → REJECT  
6. YouTube / Telegram / Apple 媒体 → 代理；Apple / FCM → DIRECT  
7. PROXY → 代理；Domestic → DIRECT；GEOIP,CN → DIRECT  
8. **`MATCH,DIRECT`**（已删除 `IP-CIDR6,::/0,代理`）

## 6. OpenClash IPv6 运行参数（非 yaml）

| 项 | 推荐值 | 说明 |
|----|--------|------|
| 代理 IPv6 流量 | 开 | `ipv6_enable=1` |
| IPv6 代理模式 | **Redirect** | `ipv6_mode=1`（勿用 TProxy=0） |
| 中国 IPv6 绕过 | 开 | `china_ip6_route=1`（界面：实验性绕过中国大陆 IPv6 / 区域绕过） |
| IPv6 DNS 解析 | 开 | `ipv6_dns=1` |
| Fake-IP Range6 | `2a0f:fafa:cafe::1/64` | 与 yaml 一致 |

**TProxy 坑：** 本环境 IPv6 TProxy + `local default` fwmark 路由会导致境外 HTTPS 落到 **uhttpd:443**，浏览器看到 `CN=OpenWrt` 自签证书 → test-ipv6 / 境外站失败。Redirect 可避免。

## 7. 未改动的个人化内容（分享时需自备）

- `proxy-providers` 订阅 URL / token  
- `secret`、控制器地址  
- 内网监听 IP（样例中已占位）  
- Nokia / 坚果等个人直连域名（可删可留）
