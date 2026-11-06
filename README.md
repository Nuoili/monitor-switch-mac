# 显示器切换 · Mac 端

**v2.3.0** — 与 Windows 端 [monitor-switch-win](https://github.com/Nuoili/monitor-switch-win) 同号发布，两端版本号必须保持一致（见仓库根 `VERSION` 文件）。

同一台显示器接 Windows 主机和 MacBook，在 Mac 上一键把信号源切过去（或切回来），不用按显示器背面的按钮。

- 走 [`m1ddc`](https://github.com/waydabber/m1ddc) 发 DDC/CI 指令（VCP `0x60` 写输入源）。
- 全部是 `.command` 脚本，双击就能跑，不需要装 Xcode、不需要编译。
- 显示器实测型号：AOC Q24G2（DP = Windows，HDMI-1 = Mac）。
- Windows 端在另一个仓库：[monitor-switch-win](https://github.com/Nuoili/monitor-switch-win)。

## 快速开始

```bash
git clone git@github.com:Nuoili/monitor-switch-mac.git
cd monitor-switch-mac
chmod +x *.command
open .
```

然后**按序号双击**：

| 步骤 | 文件 | 作用 |
|---|---|---|
| 1 | `0-安装m1ddc.command` | 装 m1ddc（前缀 brew，失败回退到直接下载），装完立刻验证能否读到显示器 |
| 2 | `1-切到Windows.command` / `2-切到Mac.command` | 切信号源 |
| 3 | `3-设置开机自启.command` | 登录后自动切回 Mac |

可选（解决"久不切回来就黑屏"）：

| 文件 | 作用 |
|---|---|
| `4-保持Mac唤醒.command` | `caffeinate -d -i -s` 常驻，禁止关屏和空闲睡眠，Mac 持续往 HDMI 送信号 |
| `5-取消保持唤醒.command` | 一键卸载，恢复原样 |
| `6-安装唤醒监听.command` | 装 LaunchAgent：监听 UDP 9998，收到 Windows 的 `WAKE` 就重放一次显示配置 |
| `7-卸载唤醒监听.command` | 只卸载监听 |
| `8-卸载全部.command` | **完整卸载**：三个 LaunchAgent + `~/.monswitch` 一起清掉，m1ddc 单独询问（默认保留） |

## 目录

```
0..8-*.command          一键脚本（安装 / 切换 / 自启 / 保持唤醒 / 唤醒监听 / 卸载）
VERSION                 版本号，与 Windows 仓同号
CHANGELOG.md            版本变更记录
diagnose.py             体检脚本：读显示器、查 DDC、看 pmset、盯显示配置变化
mac_wake_listener.py    唤醒监听本体（LaunchAgent 常驻）
Mac端-HDMI黑屏修复.md    黑屏排查手册 + 三套方案
```

## macOS .app 分发包

`.command` 脚本够用，但想要一个躺在「应用程序」里的图标版本，用 `dist/` 里的 zip：

```bash
python packaging/build_app.py     # 在 Windows/Linux 上也能打包，不需要 Mac
```

产物 `dist/显示器切换-macOS-v2.3.0.zip`：解压得到 `显示器切换.app`（已含图标与版本号）
+ `使用说明.txt`。打包细节见 [`packaging/README.md`](packaging/README.md)。

## 卸载

双击 `8-卸载全部.command`，一键清干净：

| 清除项 | 说明 |
|---|---|
| `~/Library/LaunchAgents/com.monswitch.autostart.plist` | 登录后自动切 HDMI |
| `~/Library/LaunchAgents/com.monswitch.awake.plist` | `caffeinate` 保持唤醒 |
| `~/Library/LaunchAgents/com.monswitch.wakelistener.plist` | UDP 9998 唤醒监听 |
| `~/.monswitch/` | 配置、stdout / stderr 日志 |
| `m1ddc` | 单独弹窗询问，默认**保留**（只是个发 DDC 命令的小工具） |

脚本不会删自己所在的文件夹——卸载完把仓库目录拖进废纸篓即可。

## 体检脚本

```bash
python3 diagnose.py            # 一次性体检，输出 KEY=VALUE + 结论
python3 diagnose.py --watch    # 持续监视显示配置变化
```

`--watch` 是关键：切回去黑屏的瞬间，外接屏是否还在系统列表里，是"坞没拉起 HDMI"和"显示器锁存"的分水岭。

## 与 Windows 端的协议

Windows 端点「切到 Mac」时会先发一个 UDP 包：

- 端口 **9998**，负载 ASCII `WAKE`，广播（全局 + 各网段定向各一份，因为有 VPN 时全局广播可能从虚拟网卡溜走）
- 监听端在 Mac：`mac_wake_listener.py` 收到后 `caffeinate -u` 唤醒显示，再用 `displayplacer` 重放当前显示配置，人为制造一次 HPD 边沿
- 0.4 秒后 Windows 才发 DDC 切换命令，给显示器留出重新锁定时钟的窗口

监听脚本对任何来源的 `WAKE` 都响应，不校验 IP——同一局域网即可。

## 为什么需要"保持唤醒"和"唤醒监听"

macOS 关屏后 GPU 会停止向外接口送信号；显示器在 HDMI 口重新上电时只有 1–3 秒的检测窗口，错过就判"无信号"并锁存待机。而 Mac 侧 HPD 一直是高电平，认为外接屏工作正常，永远不会重新协商链路——两边谁也不动，切回去就是黑的。

- 方案 A（`4-保持Mac唤醒`）：让 Mac 一直有信号输出，根本不给它断流的机会。
- 方案 C（`6-安装唤醒监听`）：切回来之前主动踢一脚，制造一次 HPD 边沿。

详细机制和排查步骤见 [`Mac端-HDMI黑屏修复.md`](Mac端-HDMI黑屏修复.md)。

## License

MIT
