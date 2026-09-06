#!/bin/bash
# w-ui 主控更新：下载最新版替换二进制并重启，数据保留，健康检查失败自动回滚
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/update.sh | bash
# 可选环境变量同 install.sh: WUI_PORT / WUI_DIR / WUI_VERSION / WUI_REPO
set -eu

REPO=${WUI_REPO:-ficyue/w-ui}
PORT=${WUI_PORT:-12781}
DIR=${WUI_DIR:-/opt/wui}
VERSION=${WUI_VERSION:-latest}

[ "$(id -u)" = 0 ] || { echo "!! 请用 root 运行"; exit 1; }
[ -f "$DIR/wui" ] || { echo "!! 未检测到已安装的主控（$DIR/wui 不存在），请先执行安装脚本"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "!! 缺少 curl，请先安装"; exit 1; }

ARCH=$(uname -m)
case $ARCH in
  x86_64) AGO=amd64 ;;
  aarch64|arm64) AGO=arm64 ;;
  *) echo "!! 不支持的架构: $ARCH"; exit 1 ;;
esac

if [ "$VERSION" = latest ]; then
  DL_URL="https://github.com/$REPO/releases/latest/download/wui-linux-$AGO"
else
  DL_URL="https://github.com/$REPO/releases/download/$VERSION/wui-linux-$AGO"
fi

echo "==> 下载新版本（$ARCH → $AGO）"
curl -fL --retry 3 -o "$DIR/wui.new" "$DL_URL" || {
  echo "!! 下载失败：请确认服务器能访问 github.com"
  rm -f "$DIR/wui.new"; exit 1
}
chmod +x "$DIR/wui.new"

if ! systemctl cat wui >/dev/null 2>&1; then
  echo "==> 补写 systemd 服务（wui，端口 $PORT）"
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
fi

echo "==> 替换二进制并重启服务"
cp -f "$DIR/wui" "$DIR/wui.bak"
systemctl stop wui >/dev/null 2>&1 || true
mv -f "$DIR/wui.new" "$DIR/wui"
systemctl start wui
sleep 2

if ! curl -fsS -o /dev/null --max-time 10 "http://127.0.0.1:$PORT/"; then
  echo "!! 健康检查失败，回滚旧版本："
  journalctl -u wui -n 20 --no-pager
  mv -f "$DIR/wui.bak" "$DIR/wui"
  systemctl restart wui
  exit 1
fi
rm -f "$DIR/wui.bak"
echo
echo "✔ 更新完成: http://<服务器IP>:$PORT/（数据目录 $DIR/data 未受影响）"
