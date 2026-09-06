#!/bin/bash
# w-ui 主控卸载：停止并移除 systemd 服务与主控二进制
# 默认保留数据目录（/opt/wui/data），加 --purge 一并删除
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/uninstall.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/ficyue/w-ui/main/scripts/uninstall.sh | bash -s -- --purge
set -eu

DIR=${WUI_DIR:-/opt/wui}
PURGE=0
for a in "$@"; do
  case $a in
    --purge|-p) PURGE=1 ;;
    *) echo "未知参数: $a"; exit 1 ;;
  esac
done

[ "$(id -u)" = 0 ] || { echo "!! 请用 root 运行"; exit 1; }

echo "==> 停止并移除 systemd 服务（wui）"
systemctl stop wui >/dev/null 2>&1 || true
systemctl disable wui >/dev/null 2>&1 || true
rm -f /etc/systemd/system/wui.service
systemctl daemon-reload >/dev/null 2>&1 || true

echo "==> 删除主控文件"
rm -f "$DIR/wui" "$DIR/wui.bak" "$DIR/wui.new"
rmdir "$DIR" 2>/dev/null || true

if [ "$PURGE" = 1 ]; then
  echo "==> 删除数据目录 $DIR/data"
  rm -rf "$DIR"
  echo
  echo "✔ 已完全卸载（含数据）"
else
  echo
  echo "✔ 卸载完成，数据目录已保留: $DIR/data"
  echo "  如需连同数据一起删除，请加 --purge 重新执行"
fi

echo
echo "说明: 各服务器上的 wui-agent 与 sing-box 不受本脚本影响；"
echo "      卸载主控前建议先在面板「服务器」页逐台远程卸载 Agent。"
