# OpenClash UCI / 界面配套项

以下与 `meta-ipv6.yaml` **一起**生效；只更新 yaml 不够。

## 推荐设置

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

## 界面对照（中文）

| UCI | 界面大致名称 |
|-----|----------------|
| `ipv6_enable` | 代理 IPv6 流量 |
| `ipv6_mode=1` | IPv6 代理模式 → **Redirect 模式** |
| `china_ip6_route=1` | 实验性：绕过中国大陆 IPv6 / 概览「区域绕过→大陆」相关 |
| `ipv6_dns` | IPv6 DNS 解析 |
| `fakeip_range6` | Fake-IP Range (IPv6) |

## 自检

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
