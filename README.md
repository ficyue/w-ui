# w-ui（仅二进制发布）

singbox 多服务器管理面板：主控 + Agent 架构。本仓库只提供编译产物，不含源码与安装脚本。

## 文件说明（v0.1.0）

| 文件 | 说明 |
|---|---|
| wui-linux-amd64 / wui-linux-arm64 | 主控面板（Linux 服务器运行） |
| wui-agent-linux-amd64 / arm64 / armv7 / 386 | Agent（随面板一键部署到 singbox 服务器） |

完整性校验：`sha256sums.txt`（sha256sum -c）

## 运行

主控：`./wui -data ./data -port 12781`，浏览器打开 `http://IP:12781` 初始化管理员。
Agent 由主控面板下发安装，不单独提供安装脚本。
