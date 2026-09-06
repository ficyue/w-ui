#!/bin/bash
# w-ui 主控一键安装：从 GitHub Releases 下载最新主控二进制，注册 systemd 服务并启动
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/install.sh | bash
# 可选环境变量:
#   WUI_PORT=12781       主控端口
#   WUI_DIR=/opt/wui     安装目录（数据在其下 data/）
#   WUI_VERSION=latest   指定版本，如 v0.1.0
#   WUI_REPO=ficyue/w-ui
set -eu

REPO=${WUI_REPO:-ficyue/w-ui}
PORT=${WUI_PORT:-12781}
DIR=${WUI_DIR:-/opt/wui}
VERSION=${WUI_VERSION:-latest}
RAW_PREFIX="https://raw.githubusercontent.com/$REPO/main/scripts"

[ "$(id -u)" = 0 ] || { echo "!! 请用 root 运行（curl ... | sudo bash）"; exit 1; }
command -v systemctl >/dev/null 2>&1 || { echo "!! 需要 systemd 的 Linux 系统（Debian/Ubuntu/CentOS 等）"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "!! 缺少 curl，请先安装"; exit 1; }

if [ -f "$DIR/wui" ] || systemctl cat wui >/dev/null 2>&1; then
  echo "!! 检测到 w-ui 已安装，请改用更新脚本:"
  echo "   curl -fsSL $RAW_PREFIX/update.sh | bash"
  exit 1
fi

ARCH=$(uname -m)
case $ARCH in
  x86_64) AGO=amd64 ;;
  aarch64|arm64) AGO=arm64 ;;
  *) echo "!! 不支持的架构: $ARCH（Releases 仅提供 linux amd64 / arm64）"; exit 1 ;;
esac

if [ "$VERSION" = latest ]; then
  DL_URL="https://github.com/$REPO/releases/latest/download/wui-linux-$AGO"
else
  DL_URL="https://github.com/$REPO/releases/download/$VERSION/wui-linux-$AGO"
fi

echo "==> 下载主控（$ARCH → $AGO）"
mkdir -p "$DIR/data"
curl -fL --retry 3 -o "$DIR/wui.new" "$DL_URL" || {
  echo "!! 下载失败：请确认服务器能访问 github.com（可配置代理后重试）"
  rm -f "$DIR/wui.new"; exit 1
}
chmod +x "$DIR/wui.new"
mv -f "$DIR/wui.new" "$DIR/wui"

echo "==> 写入 systemd 服务（wui，端口 $PORT）"
cat > /etc/systemd/system/wui.service <<UNIT
[Unit]
Description=w-ui singbox master panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=$DIR/wui -data $DIR/data -port $PORT
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable wui >/dev/null 2>&1 || true
systemctl restart wui
sleep 2

if ! systemctl is-active --quiet wui; then
  echo "!! 服务启动失败："
  journalctl -u wui -n 20 --no-pager
  exit 1
fi
if ! curl -fsS -o /dev/null --max-time 10 "http://127.0.0.1:$PORT/"; then
  echo "!! 健康检查失败："
  journalctl -u wui -n 20 --no-pager
  systemctl stop wui
  exit 1
fi

echo
echo "✔ 安装完成: http://<服务器IP>:$PORT/"
echo "  首次访问请在页面里初始化管理员账号"
echo "  数据目录: $DIR/data（config.json 面板配置 / wui.db 业务数据）"
echo "  常用命令: systemctl status|restart|stop wui"
echo "  提醒: 防火墙/安全组需放行 $PORT 端口"
