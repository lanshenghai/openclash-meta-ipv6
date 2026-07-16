# OpenClash / Mihomo `meta-ipv6` 调优记录

面向：**FriendlyWrt / OpenClash + Mihomo（fake-ip）+ 双栈 IPv6** 软路由场景。  
本目录整理会话中修复 Access Check、YouTube/Telegram、头条、test-ipv6、IPv6 代理模式等问题后的**可分享配置与结论**。

## 目录内容

| 文件 | 说明 |
|------|------|
| `README.md` | 本说明（问题 → 根因 → 改动） |
| `CHANGELOG.md` | 按主题汇总的改动清单 |
| `meta-ipv6.yaml` | 脱敏后的 Clash Meta 配置样例 |
| `OPENCLASH-UCI.md` | 必须配合的 OpenClash 界面 / UCI 项 |
| `APPLY.md` | 部署步骤 |

> **安全：** `meta-ipv6.yaml` 中的订阅链接、API secret、内网 IP 已替换为占位符。请用你自己的订阅与密钥。

## 适用环境（参考）

- 软路由 OpenWrt/FriendlyWrt + OpenClash
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

## License / 来源

规则集 URL 使用 [dler-io/Rules](https://github.com/dler-io/Rules)（jsDelivr）。配置结构供学习与自用，请自行替换订阅与隐私信息。
