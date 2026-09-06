# w-ui

sing-box 多服务器管理面板 —— 一个主控统一管理多台 sing-box 服务器：探针式实时监控、远程配置、入站/出站/路由可视化编辑、SSH 一键部署。

架构为 **主控（wui，Go 单二进制，前端已内嵌）+ Agent（wui-agent，装在每台 sing-box 服务器上）**。


## 功能特性

- 🖥️ **多服务器管理** —— 主控统一管理多台远程 sing-box 服务器，支持流量套餐（上限 / 已用 / 重置日 / 续费日期 / 价格）与周期用量统计
- 📊 **探针主页** —— 卡片 / 列表双视图，CPU / 内存 / 磁盘、网卡实时速率、周期流量进度条 1 秒刷新；自动探测公网 IPv4 / IPv6 并按国家显示国旗
- 🔌 **三种连接模式** —— `websocket`（Agent 主动拨号主控，NAT 友好）/ `http`（主控直连 Agent API）/ `pull`（Agent 心跳取命令队列），`auto` 模式自动回退，命令断线补发不丢
- 🔧 **远程配置** —— 在线编辑 sing-box 配置，应用前 `sing-box check` 校验、失败自动回滚、45 秒无确认死手保护，保留 50 条历史版本
- 📡 **入站 / 出站 / 路由可视化** —— vmess / vless / trojan / hysteria2 / tuic / shadowsocks / snell / mixed 等全字段表单（TLS / Reality / 传输层 / 多路复用），路由规则拖动排序，JSON 模式兜底
- 🔀 **端口转发** —— 一键生成转发规则（direct 入站 + 出站 + 路由），支持备注与 tag 自动命名
- 🚀 **一键部署 / 卸载** —— 面板通过 SSH 直装最新测试版 sing-box + Agent（自动识别架构、写 systemd 服务），或生成安装命令手动执行；Agent 可从面板远程卸载（连同 sing-box 一起清理）

## 架构

```
浏览器 ──HTTP/WS──► 主控 wui(:12781) ──WS/HTTP/Pull──► Agent(:12782) ──► sing-box
                     API+SQLite+部署器                  Clash API 采集 + systemd 控制
```

## 快速开始

### 1. 安装主控

在服务器上以 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/install.sh | bash
```

可选环境变量（`curl ... | WUI_PORT=8080 bash` 方式传入）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `WUI_PORT` | 12781 | 主控端口 |
| `WUI_DIR` | /opt/wui | 安装目录，数据在 `data/` 子目录 |
| `WUI_VERSION` | latest | 指定版本，如 `v0.1.0` |

脚本从 Releases 下载对应架构（linux amd64 / arm64）二进制，注册 systemd 服务 `wui` 并启动。防火墙 / 安全组记得放行主控端口。

### 2. 初始化

浏览器打开 `http://服务器IP:端口`，首次访问设置管理员账号。

### 3. 添加 sing-box 服务器

两种方式（都在面板内完成）：

1. **SSH 一键部署**：面板「部署」页填写 SSH 信息，主控自动在目标机安装最新测试版 sing-box + Agent 并上线
2. **手动安装**：面板「服务器」页添加服务器后复制安装命令，到目标机 root 执行：

   ```bash
   curl -fsSL 'http://<主控地址>/api/install.sh?token=<服务器令牌>' | bash
   ```

Agent 配置位于目标机 `/opt/wui/agent.json`：

```json
{
  "master_url": "http://主控地址:12781",
  "token": "服务器令牌",
  "mode": "auto",
  "listen": "0.0.0.0:12782",
  "singbox_config": "/etc/singbox/config.json",
  "singbox_service": "singbox"
}
```

## 更新 / 卸载

```bash
# 更新到最新版（数据保留，健康检查失败自动回滚旧版本）
curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/update.sh | bash

# 卸载主控（默认保留数据目录）
curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/uninstall.sh | bash

# 卸载并删除全部数据
curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/uninstall.sh | bash -s -- --purge
```

卸载主控不影响各服务器上的 Agent 与 sing-box；建议卸载前先在面板「服务器」页逐台远程卸载 Agent。

## 端口与文件

| 项 | 默认值 |
|---|---|
| 主控端口 | 12781（浏览器访问 + Agent 回连） |
| Agent HTTP 端口 | 12782（http / pull 模式） |
| 主控二进制 / 服务 | `/opt/wui/wui`，systemd 服务 `wui` |
| 主控数据 | `/opt/wui/data/config.json` + `wui.db`（SQLite） |
| Agent 二进制 | `/usr/local/bin/wui-agent` |
| Agent 配置 | `/opt/wui/agent.json` |
| sing-box 配置 | `/etc/singbox/config.json` |

## 数据备份

停服后打包数据目录即可（`wui.db` 为单文件 SQLite，包含服务器 / 指标 / 流量 / 配置历史）：

```bash
systemctl stop wui
tar czf wui-backup-$(date +%F).tgz -C /opt/wui data
systemctl start wui
```

恢复：解包回 `/opt/wui/data` 后启动服务。

## 说明

- 流量统计来源为 sing-box `experimental.clash_api`（一键部署会为缺省配置自动加上）；需要按入站 / 用户细分时可在配置中启用 `experimental.v2ray_api`
- 服务器流量套餐支持自然月 / 按续费日重置、上行 / 下行 / 双向三种统计口径、网卡 / 代理两种数据源
- 连接模式 `auto` 下 Agent 优先 WebSocket，不可用时自动回退 http / pull；命令经主控队列兜底，Agent 短暂掉线重连后自动补收
- 手动安装 Agent 的服务器需要能访问主控地址与 GitHub（下载 sing-box 内核）
- 管理面与 Agent 通信均使用令牌认证
- 本项目仅供学习与自用服务器管理，请遵守所在地法律法规
