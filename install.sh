#!/usr/bin/env bash
# 安装 WindowSwitcher.spoon 到 ~/.hammerspoon/Spoons/
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPOON="WindowSwitcher.spoon"
DEST="$HOME/.hammerspoon/Spoons"

if [ ! -d "$SRC_DIR/$SPOON" ]; then
  echo "错误：找不到 $SRC_DIR/$SPOON" >&2
  exit 1
fi

mkdir -p "$DEST"
rm -rf "$DEST/$SPOON"
cp -R "$SRC_DIR/$SPOON" "$DEST/$SPOON"
echo "✅ 已安装到 $DEST/$SPOON"

cat <<'EOF'

下一步：在 ~/.hammerspoon/init.lua 中加入

    hs.loadSpoon("WindowSwitcher")
    spoon.WindowSwitcher:start()

然后在 Hammerspoon 菜单栏点 Reload Config。
EOF
