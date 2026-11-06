# 变更记录

双端统一版本号：**Mac（本仓库）与 Windows（monitor-switch-win）同号同发**。
版本号的唯一源头是本仓库根目录的 `VERSION` 文件，Windows 端的源头是
`源码/monitor_switch_gui.py` 的 `APP_VERSION`——两边必须写同一个数，否则视为发版未完成。

## v2.3.0 — 2026-11-06

双端对齐版本，Mac 端首次对外标注版本号。

**新增**
- `VERSION` 文件（`2.3.0`），与 Windows 端同号。
- `1-切到Windows.command` / `2-切到Mac.command` 运行时会打印 `显示器切换 · Mac 端 v2.3.0 → 输入源 …`，出问题时一眼能看出跑的哪一版。
- `8-卸载全部.command`：完整卸载。清掉三个 LaunchAgent（开机自启 / 保持唤醒 / 唤醒监听）和 `~/.monswitch`，`m1ddc` 单独询问、默认保留。只动本程序装过的东西。
- `packaging/`：`.app` 打包流程入库（`build_app.py` + 图标 + 主程序脚本 + 随包说明），在任意平台都能出 `dist/显示器切换-macOS-v2.3.0.zip`，版本号自动取自 `VERSION`。
- 分发包 `显示器切换.app` 的版本号从 1.0 提到 2.3.0：Finder 简介、对话框标题、`--version` 三处一致。
- `CHANGELOG.md`（本文件）。

**说明**
- 本端只有一套代码路径，不涉及 Windows 端 2.2 的「连续切换后按钮失效」问题（那是 GUI 状态机的事）。
- 仓库根 `VERSION` 与 Windows 仓 tag 必须同名，发版时两边都打 `v2.3.0`。

## v1.0.0 — 2026-11-01

- 首版：m1ddc 一键切信号源（DP 15 / HDMI-1 17）、保持唤醒、UDP 9998 唤醒监听、黑屏排查手册。
