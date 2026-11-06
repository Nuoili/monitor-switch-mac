#!/bin/bash
# 卸载 Mac 端：移除全部后台项 + 配置目录，可选卸载 m1ddc
#
# 只动本程序自己装的东西，别的一概不碰：
#   ~/Library/LaunchAgents/com.monswitch.*.plist   三个 LaunchAgent（开机自启 / 保持唤醒 / 唤醒监听）
#   ~/.monswitch/                                  配置与日志
#   m1ddc                                          单独询问，默认保留
#
# 本仓库目录不会被自动删除（脚本删不掉自己所在的文件夹），卸载完手动拖进废纸篓即可。

set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
VER="$(cat "$DIR/VERSION" 2>/dev/null | tr -d '[:space:]')"
[ -z "$VER" ] && VER="?"
LA="$HOME/Library/LaunchAgents"
CONF="$HOME/.monswitch"
LABELS="com.monswitch.autostart com.monswitch.awake com.monswitch.wakelistener"

say() { osascript -e "display dialog \"$1\" buttons {\"好\"} default button 1 ${2:-}"; }

ans="$(osascript -e "button returned of (display dialog \"卸载 Mac 端 v$VER ？\n\n将移除：\n· 开机自启（登录后自动切 HDMI）\n· 保持唤醒（caffeinate）\n· 唤醒监听（UDP 9998）\n· ~/.monswitch 里的配置与日志\n\nm1ddc 会再问你一次，默认保留。\" buttons {\"取消\", \"开始卸载\"} default button 2 with icon caution)" 2>/dev/null)"
case "$ans" in
  *开始卸载*) : ;;
  *) echo "已取消"; exit 0 ;;
esac

echo "== 移除 LaunchAgent =="
for L in $LABELS; do
  launchctl bootout "gui/$UID/$L" 2>/dev/null
  launchctl unload "$LA/$L.plist" 2>/dev/null
  rm -f "$LA/$L.plist"
  echo "  $L"
done

echo "== 结束常驻进程 =="
pkill -f mac_wake_listener.py 2>/dev/null
pkill -f "caffeinate -d -i -s" 2>/dev/null
echo "  ok"

echo "== 清理配置与日志 =="
rm -rf "$CONF"
echo "  $CONF"

# m1ddc 单独处理：可能是 brew 装的，也可能是直接下载的二进制
M1DDC="$(command -v m1ddc 2>/dev/null)"
if [ -n "$M1DDC" ]; then
  ans2="$(osascript -e "button returned of (display dialog \"是否一并卸载 m1ddc？\n\n它只是发 DDC 命令的小工具（$M1DDC），保留也不占资源；以后想再用本程序就需要它。\" buttons {\"保留\", \"卸载 m1ddc\"} default button 1)" 2>/dev/null)"
  case "$ans2" in
    *卸载*)
      if brew list --formula m1ddc >/dev/null 2>&1; then
        brew uninstall m1ddc && echo "  brew uninstall m1ddc 完成"
      else
        rm -f "$M1DDC" 2>/dev/null || sudo rm -f "$M1DDC"
        echo "  已删除 $M1DDC"
      fi
      ;;
    *) echo "  已保留 m1ddc" ;;
  esac
else
  echo "  未安装 m1ddc，跳过"
fi

say "卸载完成（v$VER）。\n\n本文件夹可以手动拖进废纸篓了；配置文件与后台项都已清除。"

# 打开所在目录，方便直接拖走
open -R "$DIR" 2>/dev/null
