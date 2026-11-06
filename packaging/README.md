# 打包 macOS .app

在 Windows / Linux 上也能完成，不需要 Mac。

```bash
python packaging/build_app.py
# 产物：dist/显示器切换-macOS-v<版本>.zip
```

## 为什么要有这个目录

`.app` 本质是个目录：`Contents/Info.plist` + `Contents/MacOS/<可执行脚本>` + 图标。
这里的脚本就是把这个目录组装出来并压成 zip，所以打包机不需要 macOS，
只要把可执行位写对（zip 里 `0o755`，`create_system=3`）就行。

## 版本号怎么进来的

只读仓库根的 `VERSION`，写进三处：

| 落点 | 用途 |
|---|---|
| `Info.plist` 的 `CFBundleShortVersionString` / `CFBundleVersion` | Finder「显示简介」里看到的版本 |
| `Contents/Resources/VERSION` | 运行时读，对话框标题显示 `显示器切换 v2.3.0` |
| 随包 `使用说明.txt` 首尾 | 给用户看的版本 |

换版本只改 `VERSION`，然后重跑本脚本。

## 文件

```
packaging/
  build_app.py              组装 + 打包
  icon.icns                 应用图标
  app/MonitorSwitch.sh      app 的主程序（bash，用 m1ddc 发 DDC）
  app/使用说明.txt          随包说明（@@VERSION@@ 会被替换）
```

## 验证过什么

- `bash -n app/MonitorSwitch.sh` 语法通过
- 解压后 `Contents/MacOS/MonitorSwitch --version` 输出 `显示器切换 · macOS 端 v2.3.0`
- `Info.plist` 用 `plistlib` 能解析，版本号 = 2.3.0
- zip 内 `MonitorSwitch` 权限位 = 755，其余 644

**没验证**：真机 macOS 双击运行、osascript 对话框、m1ddc 实际切换。
这部分只能在 Mac 上验。
