#!/bin/bash
# 显示器切换 · macOS
# 通过 m1ddc（DDC/CI）切换显示器输入源
#   --auto / --hdmi  静默切到 HDMI-1（Mac 画面），供登录自启调用
#   --dp             静默切到 DisplayPort（Windows 画面）
#   无参数           弹出选择窗口

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/bin:$PATH"

APP_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.monswitch.autostart.plist"
SELF="$APP_DIR/Contents/MacOS/MonitorSwitch"
VER="$(cat "$APP_DIR/Contents/Resources/VERSION" 2>/dev/null | tr -d '[:space:]')"
[ -z "$VER" ] && VER="?"

find_m1ddc() {
    for p in /opt/homebrew/bin/m1ddc /usr/local/bin/m1ddc "$HOME/bin/m1ddc"; do
        [ -x "$p" ] && { printf '%s' "$p"; return 0; }
    done
    command -v m1ddc 2>/dev/null
}

alert() {
    /usr/bin/osascript - "$1" "${2:-note}" <<'AS' >/dev/null 2>&1
on run argv
    display dialog (item 1 of argv) buttons {"好"} default button 1 with title "显示器切换" with icon (item 2 of argv)
end run
AS
}

choose_action() {
    /usr/bin/osascript <<AS
try
    set r to display dialog "选择要让显示器显示的画面：" with title "显示器切换 v$VER" ¬
        buttons {"设置", "切到 Windows", "切到 Mac"} default button "切到 Mac" ¬
        with icon note giving up after 60
    return button returned of r
on error
    return "取消"
end try
AS
}

choose_setting() {
    /usr/bin/osascript <<'AS'
try
    set r to display dialog "登录 Mac 后要自动切到哪块画面？" with title "显示器切换 · 设置" ¬
        buttons {"取消", "不自动切换", "自动切到 Mac"} default button "自动切到 Mac" ¬
        with icon note
    return button returned of r
on error
    return "取消"
end try
AS
}

install_m1ddc() {
    if ! command -v brew >/dev/null 2>&1; then
        alert "还没有安装 Homebrew，无法自动安装所需组件。

请先在「终端」里运行下面这条命令安装 Homebrew：
/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"

装好后重新打开本程序即可。" stop
        return 1
    fi
    /usr/bin/osascript -e 'display notification "正在安装 m1ddc，请稍候…" with title "显示器切换"' >/dev/null 2>&1
    brew install m1ddc >/tmp/monswitch-install.log 2>&1
    if [ -z "$(find_m1ddc)" ]; then
        alert "自动安装失败，请打开「终端」手动执行：
brew install m1ddc

日志：/tmp/monswitch-install.log" stop
        return 1
    fi
    return 0
}

ensure_m1ddc() {
    [ -n "$(find_m1ddc)" ] && return 0
    local ans
    ans=$(/usr/bin/osascript <<'AS'
try
    set r to display dialog "首次使用需要安装一个很小的开源组件 m1ddc（用于控制显示器）。现在安装吗？" ¬
        with title "显示器切换" buttons {"取消", "现在安装"} default button "现在安装" with icon caution
    return button returned of r
on error
    return "取消"
end try
AS
)
    [ "$ans" = "现在安装" ] || return 1
    install_m1ddc
}

do_switch() {
    local m1 value label quiet i
    m1="$(find_m1ddc)"
    value="$1"
    label="$2"
    quiet="$3"
    for i in 1 2 3; do
        "$m1" set input "$value" >/dev/null 2>&1 && return 0
        sleep 1
    done
    [ "$quiet" = "quiet" ] && return 1
    alert "切换失败：显示器没有响应。

可能原因：
· 显示器 OSD 菜单里的 DDC/CI 被关闭
· 视频线只支持充电/数据，不透传 DDC
· 经拓展坞连接时，个别拓展坞不透传 DDC 通道

可以先用显示器机身上的 INPUT 键手动切换。" caution
    return 1
}

write_autostart() {
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.monswitch.autostart</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$SELF</string>
        <string>--auto</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null
    launchctl load "$PLIST" 2>/dev/null
}

remove_autostart() {
    launchctl unload "$PLIST" 2>/dev/null
    rm -f "$PLIST"
}

# ---------------------------------------------------------------- 入口

case "$1" in
    --version|-v)
        printf '显示器切换 · macOS 端 v%s\n' "$VER"
        exit 0
        ;;
    --auto|--hdmi|--mac|--hdmi1)
        [ -n "$(find_m1ddc)" ] || exit 0
        do_switch 17 "HDMI-1" quiet
        exit $?
        ;;
    --dp|--win|--windows)
        [ -n "$(find_m1ddc)" ] || exit 0
        do_switch 15 "DisplayPort" quiet
        exit $?
        ;;
esac

ensure_m1ddc || exit 0

action="$(choose_action)"
case "$action" in
    "切到 Mac")
        do_switch 17 "HDMI-1"
        ;;
    "切到 Windows")
        do_switch 15 "DisplayPort"
        ;;
    "设置")
        s="$(choose_setting)"
        case "$s" in
            "自动切到 Mac")
                write_autostart
                alert "已设置：登录 Mac 后自动切到 Mac 画面。"
                ;;
            "不自动切换")
                remove_autostart
                alert "已取消开机自动切换。"
                ;;
        esac
        ;;
esac

exit 0
