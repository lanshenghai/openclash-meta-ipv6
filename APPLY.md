# 部署步骤

1. 复制 `meta-ipv6.yaml` 到软路由，例如：  
   `/etc/openclash/config/meta-ipv6.yaml`
2. 填入自己的 `proxy-providers` 订阅、`secret`、`external-controller` / `listen` 地址。
3. 按 `OPENCLASH-UCI.md` 设置 IPv6 Redirect + `china_ip6_route` + `fakeip_range6`。
4. OpenClash 选择该配置并重启。
5. 客户端 DNS 指向软路由（或 AC 上游指向软路由），避免公司电脑本地 DNS 劫持导致 AAAA 异常。
6. 验证：
   - https://www.test-ipv6.com/ （主测应能检测到 IPv6）
   - YouTube / Telegram
   - 国内站（百度等）与头条图文

路径 `./rule_provider/`、`./providers/` 相对 OpenClash 工作目录；首次启动会自动拉取规则集与节点。
