{{- $GiB := 1073741824.0 -}}
{{- $used := printf "%.2f" (divf (add (.UserInfo.Download | default 0 | float64) (.UserInfo.Upload | default 0 | float64)) $GiB) -}}
{{- $traffic := (.UserInfo.Traffic | default 0 | float64) -}}
{{- $total := printf "%.2f" (divf $traffic $GiB) -}}

{{- $exp := "" -}}
{{- $expStr := printf "%v" .UserInfo.ExpiredAt -}}
{{- if regexMatch `^[0-9]+$` $expStr -}}
  {{- $ts := $expStr | float64 -}}
  {{- $sec := ternary (divf $ts 1000.0) $ts (ge (len $expStr) 13) -}}
  {{- $exp = (date "2006-01-02 15:04:05" (unixEpoch ($sec | int64))) -}}
{{- else -}}
  {{- $exp = $expStr -}}
{{- end -}}

{{- $supportedProxies := list -}}
{{- range $proxy := .Proxies -}}
  {{- if or (eq $proxy.Type "shadowsocks") (eq $proxy.Type "vmess") (eq $proxy.Type "trojan") (eq $proxy.Type "http") (eq $proxy.Type "https") (eq $proxy.Type "socks5") -}}
    {{- $supportedProxies = append $supportedProxies $proxy -}}
  {{- end -}}
{{- end -}}

{{- define "SurfboardProxy" -}}
{{- $proxy := .proxy -}}
{{- $server := $proxy.Server -}}
{{- $port := $proxy.Port -}}
{{- $name := $proxy.Name -}}
{{- $pwd := $.UserInfo.Password -}}
{{- $sni := or $proxy.SNI $server -}}

{{- if eq $proxy.Type "shadowsocks" -}}
{{- $method := default "aes-128-gcm" $proxy.Method -}}
{{- $password := $pwd -}}
{{- if $proxy.ServerKey -}}
  {{- $needBytes := ternary 16 32 (eq $proxy.Method "2022-blake3-aes-128-gcm") -}}
  {{- $cutLen := min $needBytes (len $pwd) | int -}}
  {{- $userCut := $pwd | trunc $cutLen -}}
  {{- $serverB64 := b64enc $proxy.ServerKey -}}
  {{- $userB64 := b64enc $userCut -}}
  {{- $password = printf "%s:%s" $serverB64 $userB64 -}}
{{- end -}}
{{ $name }} = ss, {{ $server }}, {{ $port }}, encrypt-method={{ $method }}, password={{ $password }}, udp-relay=true
{{- else if eq $proxy.Type "vmess" -}}
{{- $wsPath := default "/" $proxy.Path -}}
{{- $wsHeaders := "" -}}
{{- if $proxy.Host -}}
  {{- $wsHeaders = printf ", ws-headers=Host:%s" $proxy.Host -}}
{{- end -}}
{{- $tlsOpts := "" -}}
{{- if $proxy.TLS -}}
  {{- $tlsOpts = ", tls=true" -}}
  {{- if $proxy.AllowInsecure -}}
    {{- $tlsOpts = printf "%s, skip-cert-verify=true" $tlsOpts -}}
  {{- end -}}
  {{- if $sni -}}
    {{- $tlsOpts = printf "%s, sni=%s" $tlsOpts $sni -}}
  {{- end -}}
{{- end -}}
{{ $name }} = vmess, {{ $server }}, {{ $port }}, username={{ $pwd }}, udp-relay=true, ws=true, ws-path={{ $wsPath }}{{ $wsHeaders }}{{ $tlsOpts }}, vmess-aead=true
{{- else if eq $proxy.Type "trojan" -}}
{{- $wsOpts := "" -}}
{{- if or (eq $proxy.Transport "ws") (eq $proxy.Transport "websocket") -}}
  {{- $wsPath := default "/" $proxy.Path -}}
  {{- $wsOpts = printf ", ws=true, ws-path=%s" $wsPath -}}
  {{- if $proxy.Host -}}
    {{- $wsOpts = printf "%s, ws-headers=Host:%s" $wsOpts $proxy.Host -}}
  {{- end -}}
{{- end -}}
{{- $tlsOpts := ", tls=true" -}}
{{- if $proxy.AllowInsecure -}}
  {{- $tlsOpts = printf "%s, skip-cert-verify=true" $tlsOpts -}}
{{- end -}}
{{- if $sni -}}
  {{- $tlsOpts = printf "%s, sni=%s" $tlsOpts $sni -}}
{{- end -}}
{{ $name }} = trojan, {{ $server }}, {{ $port }}, password={{ $pwd }}, udp-relay=true{{ $wsOpts }}{{ $tlsOpts }}
{{- else if eq $proxy.Type "http" -}}
{{ $name }} = http, {{ $server }}, {{ $port }}, {{ $pwd }}, {{ $pwd }}
{{- else if eq $proxy.Type "https" -}}
{{- $tlsOpts := ", tls=true" -}}
{{- if $proxy.AllowInsecure -}}
  {{- $tlsOpts = printf "%s, skip-cert-verify=true" $tlsOpts -}}
{{- end -}}
{{- if $sni -}}
  {{- $tlsOpts = printf "%s, sni=%s" $tlsOpts $sni -}}
{{- end -}}
{{ $name }} = https, {{ $server }}, {{ $port }}, {{ $pwd }}, {{ $pwd }}{{ $tlsOpts }}
{{- else if eq $proxy.Type "socks5" -}}
{{ $name }} = socks5, {{ $server }}, {{ $port }}, {{ $pwd }}, {{ $pwd }}, udp-relay=true
{{- end -}}
{{- end -}}

{{- define "AllProxyNames" -}}
{{- $first := true -}}
{{- range $proxy := .Proxies -}}
  {{- if or (eq $proxy.Type "shadowsocks") (eq $proxy.Type "vmess") (eq $proxy.Type "trojan") (eq $proxy.Type "http") (eq $proxy.Type "https") (eq $proxy.Type "socks5") -}}
    {{- if $first -}}
      {{ $proxy.Name }}
      {{- $first = false -}}
    {{- else -}}
      , {{ $proxy.Name }}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}

#!MANAGED-CONFIG {{ .UserInfo.SubscribeURL }} interval=60 strict=true
# 订阅链接: {{ .UserInfo.SubscribeURL }}
# 流量用量: {{ $used }}GB / {{ $total }}GB
# 到期时间: {{ $exp }}
# 更新时间: {{ now | date "2006-01-02 15:04:05" }}

[General]
# DNS服务器配置
dns-server = 114.114.114.114, 223.5.5.5, 8.8.8.8, 8.8.4.4, 9.9.9.9:9953, system

# DoH服务器配置
doh-server = https://doh.pub/dns-query, https://dns.alidns.com/dns-query, https://9.9.9.9/dns-query

# 跳过代理的地址范围
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 100.64.0.0/10, 17.0.0.0/8, localhost, *.crashlytics.com, *.local, captive.apple.com, www.baidu.com

# 代理测试URL
proxy-test-url = http://www.gstatic.com/generate_204

# 直连测试URL
internet-test-url = http://www.gstatic.cn/generate_204

# 连接测试超时
test-timeout = 30

# 真实IP域名
always-real-ip = *.lan, *.localdomain, *.example, *.invalid, *.localhost, *.test, *.local, *.home.arpa, time.*.com, time.*.gov, time.*.edu.cn, time.*.apple.com, time1.*.com, time2.*.com, time3.*.com, time4.*.com, time5.*.com, time6.*.com, time7.*.com, ntp.*.com, ntp1.*.com, ntp2.*.com, ntp3.*.com, ntp4.*.com, ntp5.*.com, ntp6.*.com, ntp7.*.com, *.time.edu.cn, *.ntp.org.cn, +.pool.ntp.org, time1.cloud.tencent.com, music.163.com, *.music.163.com, *.126.net, musicapi.taihe.com, music.taihe.com, songsearch.kugou.com, trackercdn.kugou.com, *.kuwo.cn, api-jooxtt.sanook.com, api.joox.com, joox.com, y.qq.com, *.y.qq.com, streamoc.music.tc.qq.com, mobileoc.music.tc.qq.com, isure.stream.qqmusic.qq.com, dl.stream.qqmusic.qq.com, aqqmusic.tc.qq.com, amobile.music.tc.qq.com, *.xiami.com, *.music.migu.cn, music.migu.cn, *.msftconnecttest.com, *.msftncsi.com, msftconnecttest.com, msftncsi.com, localhost.ptlogin2.qq.com, localhost.sec.qq.com, +.srv.nintendo.net, +.stun.playstation.net, xbox.*.microsoft.com, *.*.xboxlive.com, +.battlenet.com.cn, +.wotgame.cn, +.wggames.cn, +.wowsgame.cn, +.wargaming.net, proxy.golang.org, stun.*.*, stun.*.*.*, +.stun.*.*, +.stun.*.*.*, +.stun.*.*.*.*, heartbeat.belkin.com, *.linksys.com, *.linksyssmartwifi.com, *.router.asus.com, mesu.apple.com, swscan.apple.com, swquery.apple.com, swdownload.apple.com, swcdn.apple.com, swdist.apple.com, lens.l.google.com, stun.l.google.com, +.nflxvideo.net, *.square-enix.com, *.finalfantasyxiv.com, *.ffxiv.com, *.mcdn.bilivideo.cn

# HTTP代理监听端口
http-listen = 0.0.0.0:1234

# SOCKS5代理监听端口
socks5-listen = 127.0.0.1:1235

# UDP策略
udp-policy-not-supported-behaviour = DIRECT

[Host]
localhost = 127.0.0.1

[Proxy]
# 内置策略
DIRECT = direct
REJECT = reject

{{- range $proxy := $supportedProxies }}
{{ template "SurfboardProxy" (dict "proxy" $proxy "UserInfo" $.UserInfo) }}
{{- end }}

[Proxy Group]
# 主要策略组
{{- if gt (len $supportedProxies) 0 }}
🔰节点选择 = select, {{ template "AllProxyNames" . }}, DIRECT

⚓️其他流量 = select, 🔰节点选择, 🚀直接连接, {{ template "AllProxyNames" . }}
{{- else }}
🔰节点选择 = select, DIRECT

⚓️其他流量 = select, 🔰节点选择, 🚀直接连接
{{- end }}

# 应用分组
{{- if gt (len $supportedProxies) 0 }}
✈️Telegram = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎙Discord = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

📘Facebook = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

📕Reddit = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🤖OpenAI = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🤖Claude = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🤖Gemini = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接
{{- else }}
✈️Telegram = select, 🔰节点选择, 🚀直接连接

🎙Discord = select, 🔰节点选择, 🚀直接连接

📘Facebook = select, 🔰节点选择, 🚀直接连接

📕Reddit = select, 🔰节点选择, 🚀直接连接

🤖OpenAI = select, 🔰节点选择, 🚀直接连接

🤖Claude = select, 🔰节点选择, 🚀直接连接

🤖Gemini = select, 🔰节点选择, 🚀直接连接
{{- end }}

{{- if gt (len $supportedProxies) 0 }}
🎬Youtube = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎬TikTok = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎬Netflix = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎬DisneyPlus = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎬哔哩哔哩 = select, 🚀直接连接, 🔰节点选择, {{ template "AllProxyNames" . }}
{{- else }}
🎬Youtube = select, 🔰节点选择, 🚀直接连接

🎬TikTok = select, 🔰节点选择, 🚀直接连接

🎬Netflix = select, 🔰节点选择, 🚀直接连接

🎬DisneyPlus = select, 🔰节点选择, 🚀直接连接

🎬哔哩哔哩 = select, 🚀直接连接, 🔰节点选择
{{- end }}

{{- if gt (len $supportedProxies) 0 }}
🎬国外媒体 = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎧Spotify = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🎮Steam = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

💻Microsoft = select, 🚀直接连接, 🔰节点选择, {{ template "AllProxyNames" . }}

☁OneDrive = select, 🚀直接连接, 🔰节点选择, {{ template "AllProxyNames" . }}

📧OutLook = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🤖Copilot = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🧧Paypal = select, 🔰节点选择, {{ template "AllProxyNames" . }}, 🚀直接连接

🚚Amazon = select, 🚀直接连接, 🔰节点选择, {{ template "AllProxyNames" . }}

📡Speedtest = select, 🚀直接连接, 🔰节点选择, {{ template "AllProxyNames" . }}

🍎苹果服务 = select, 🚀直接连接, 🔰节点选择, {{ template "AllProxyNames" . }}
{{- else }}
🎬国外媒体 = select, 🔰节点选择, 🚀直接连接

🎧Spotify = select, 🔰节点选择, 🚀直接连接

🎮Steam = select, 🔰节点选择, 🚀直接连接

💻Microsoft = select, 🚀直接连接, 🔰节点选择

☁OneDrive = select, 🚀直接连接, 🔰节点选择

📧OutLook = select, 🔰节点选择, 🚀直接连接

🤖Copilot = select, 🔰节点选择, 🚀直接连接

🧧Paypal = select, 🔰节点选择, 🚀直接连接

🚚Amazon = select, 🚀直接连接, 🔰节点选择

📡Speedtest = select, 🚀直接连接, 🔰节点选择

🍎苹果服务 = select, 🚀直接连接, 🔰节点选择
{{- end }}

🚀直接连接 = select, DIRECT



[Rule]
# 本地网络直连
DOMAIN-SUFFIX,smtp,DIRECT
DOMAIN-KEYWORD,aria2,DIRECT
DOMAIN,clash.razord.top,DIRECT
DOMAIN-SUFFIX,lancache.steamcontent.com,DIRECT

# 管理面板
DOMAIN,yacd.haishan.me,🔰节点选择
DOMAIN-SUFFIX,appinn.com,🔰节点选择

# AI服务规则
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/OpenAI.list,🤖OpenAI,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Claude.list,🤖Claude,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Gemini.list,🤖Gemini,enhanced-mode

# 下载工具直连
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/DownLoadClient.list,DIRECT
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/ProxyClient.list,DIRECT

# 广告拦截
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/AdBlock.list,REJECT

# 苹果服务
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Apple.list,🍎苹果服务,enhanced-mode

# 各大平台规则
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Amazon.list,🚚Amazon,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Bilibili.list,🎬哔哩哔哩,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/GitHub.list,🔰节点选择,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Google.list,🔰节点选择,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Copilot.list,🤖Copilot,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/OneDrive.list,☁OneDrive,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/OutLook.list,📧OutLook,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Microsoft.list,💻Microsoft,enhanced-mode

# 流媒体规则
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Netflix.list,🎬Netflix,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/DisneyPlus.list,🎬DisneyPlus,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/TikTok.list,🎬TikTok,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/YouTube.list,🎬Youtube,enhanced-mode

# 社交媒体规则
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Telegram.list,✈️Telegram,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Discord.list,🎙Discord,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Facebook.list,📘Facebook,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Reddit.list,📕Reddit,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Twitter.list,🔰节点选择,enhanced-mode

# 其他服务规则
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Speedtest.list,📡Speedtest,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Steam.list,🎮Steam,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Spotify.list,🎧Spotify,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/PayPal.list,🧧Paypal,enhanced-mode

# 腾讯服务直连
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Tencent.list,🚀直接连接

# 代理和直连规则
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Proxy.list,🔰节点选择,enhanced-mode
RULE-SET,https://cdn.jsdmirror.com/gh/Ember-Moth/Surfboard-Template-Config@master/Filter/Direct.list,DIRECT

# 本地域名直连
DOMAIN-SUFFIX,live.cn,🚀直接连接

# 地理位置规则
GEOIP,CN,DIRECT

# 最终规则
FINAL,⚓️其他流量

[Panel]
PanelA = title="订阅信息", content="流量用量: {{ $used }}GB / {{ $total }}GB\n到期时间: {{ $exp }}\n更新时间: {{ now | date "2006-01-02 15:04:05" }}", style=info