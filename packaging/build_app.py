# -*- coding: utf-8 -*-
"""在任意平台组装 macOS 的 .app 包并打成 zip（不需要 Mac）。

版本号唯一源头是仓库根的 VERSION 文件——本脚本读它，写进：
  · Contents/Info.plist 的 CFBundleShortVersionString / CFBundleVersion
  · Contents/Resources/VERSION（运行时可读，对话框标题显示用）
  · 随包 使用说明.txt 的开头与结尾

用法（仓库根目录）：
    python packaging/build_app.py

产物：
    dist/显示器切换-macOS-v<版本>.zip
      └─ 显示器切换-macOS/
           显示器切换.app/…
           使用说明.txt

注意：zip 里必须保留可执行位（0o755），否则解压后双击 app 会报"权限不足"。
这里用 ZipInfo.external_attr 显式写入 Unix 模式，create_system=3 标记为 Unix。
"""

import os
import shutil
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DIST = os.path.join(REPO, "dist")
BUNDLE = "显示器切换.app"
ROOT = "显示器切换-macOS"

PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>CFBundleDevelopmentRegion</key>
\t<string>zh_CN</string>
\t<key>CFBundleExecutable</key>
\t<string>MonitorSwitch</string>
\t<key>CFBundleIconFile</key>
\t<string>icon.icns</string>
\t<key>CFBundleIdentifier</key>
\t<string>com.monswitch.desktop</string>
\t<key>CFBundleInfoDictionaryVersion</key>
\t<string>6.0</string>
\t<key>CFBundleName</key>
\t<string>显示器切换</string>
\t<key>CFBundleDisplayName</key>
\t<string>显示器切换</string>
\t<key>CFBundlePackageType</key>
\t<string>APPL</string>
\t<key>CFBundleShortVersionString</key>
\t<string>{ver}</string>
\t<key>CFBundleVersion</key>
\t<string>{ver}</string>
\t<key>LSMinimumSystemVersion</key>
\t<string>12.0</string>
\t<key>NSHighResolutionCapable</key>
\t<true/>
\t<key>NSHumanReadableCopyright</key>
\t<string>MIT License</string>
</dict>
</plist>
"""


def read_version():
    with open(os.path.join(REPO, "VERSION"), encoding="utf-8") as f:
        v = f.read().strip()
    if not v:
        raise SystemExit("VERSION 文件是空的")
    return v


def stage(ver):
    if os.path.isdir(DIST):
        shutil.rmtree(DIST)
    base = os.path.join(DIST, "_stage", ROOT)
    contents = os.path.join(base, BUNDLE, "Contents")
    os.makedirs(os.path.join(contents, "MacOS"))
    os.makedirs(os.path.join(contents, "Resources"))

    with open(os.path.join(contents, "Info.plist"), "w", encoding="utf-8", newline="\n") as f:
        f.write(PLIST.format(ver=ver))
    with open(os.path.join(contents, "PkgInfo"), "w", encoding="ascii", newline="\n") as f:
        f.write("APPL????")
    with open(os.path.join(contents, "Resources", "VERSION"), "w", encoding="utf-8", newline="\n") as f:
        f.write(ver + "\n")

    shutil.copy(os.path.join(HERE, "app", "MonitorSwitch.sh"), os.path.join(contents, "MacOS", "MonitorSwitch"))
    shutil.copy(os.path.join(HERE, "icon.icns"), os.path.join(contents, "Resources", "icon.icns"))

    with open(os.path.join(HERE, "app", "使用说明.txt"), encoding="utf-8") as f:
        guide = f.read().replace("@@VERSION@@", ver)
    with open(os.path.join(base, "使用说明.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(guide)
    return base


def zip_up(stage_dir, ver):
    out = os.path.join(DIST, "%s-v%s.zip" % (ROOT, ver))
    exec_files = {
        BUNDLE + "/Contents/MacOS/MonitorSwitch": 0o755,
    }
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, dirnames, filenames in os.walk(stage_dir):
            dirnames.sort()
            for d in sorted(dirnames):
                full = os.path.join(dirpath, d)
                rel = os.path.relpath(full, stage_dir).replace(os.sep, "/")
                zi = zipfile.ZipInfo(ROOT + "/" + rel + "/")
                zi.create_system = 3
                zi.external_attr = (0o755 << 16) | 0x10
                z.writestr(zi, b"")
            for fn in sorted(filenames):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, stage_dir).replace(os.sep, "/")
                mode = exec_files.get(rel, 0o644)
                zi = zipfile.ZipInfo(ROOT + "/" + rel)
                zi.create_system = 3
                zi.external_attr = mode << 16
                zi.compress_type = zipfile.ZIP_DEFLATED
                with open(full, "rb") as f:
                    z.writestr(zi, f.read())
    return out


def main():
    ver = read_version()
    stage_dir = stage(ver)
    out = zip_up(stage_dir, ver)
    shutil.rmtree(os.path.join(DIST, "_stage"))
    print("VERSION = %s" % ver)
    print("zip     = %s  (%.1f KB)" % (out, os.path.getsize(out) / 1024.0))
    with zipfile.ZipFile(out) as z:
        for i in z.infolist():
            print("  %o  %6d  %s" % (i.external_attr >> 16, i.file_size, i.filename))


if __name__ == "__main__":
    main()
