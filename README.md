# WindowSwitcher

> 一个 **纯 [Hammerspoon](https://www.hammerspoon.org/)** 实现的、替换系统 `Cmd+Tab` 的极简窗口切换器。

比系统 `Cmd+Tab` 更克制、更聚焦「当前桌面」：只列出光标所在 Space 的 app，一个 app 一个图标，不被其他桌面或隐藏窗口干扰。

> 想要 Mission Control 风格、按窗口缩略图选择的切换器？见姊妹项目 [MyMissionControl](https://github.com/MaoPingZou/MyMissionControl)。

---

## 功能特性

| 特性 | 说明 |
| --- | --- |
| 替换系统 Cmd+Tab | 直接拦截 `Cmd+Tab`，用自绘浮层代替系统切换器 |
| 按桌面隔离 | 只列出当前 Space 内的 app，切到别的桌面显示对应桌面的 app |
| 按 app 去重 | 同一个 app 的多个窗口合并为一个图标，聚焦其最近使用的窗口 |
| 纯图标 UI | 居中浮层，圆角半透明背景，仅显示 app 图标 + 选中高亮框 |
| 排除隐藏窗口 | 基于 `visible=true` 过滤，隐藏 / 最小化的窗口不出现 |
| 跟随光标屏幕 | 浮层显示在鼠标当前所在的屏幕上 |

---

## 安装

### 前置：安装 Hammerspoon

```bash
brew install --cask hammerspoon
```

首次启动需在「系统设置 → 隐私与安全性 → 辅助功能」中授权。

### 安装 Spoon

**方式 A — 一键脚本**

```bash
git clone https://github.com/MaoPingZou/WindowSwitcher.git
cd WindowSwitcher
./install.sh
```

**方式 B — 手动复制**

```bash
git clone https://github.com/MaoPingZou/WindowSwitcher.git
cp -R WindowSwitcher/WindowSwitcher.spoon ~/.hammerspoon/Spoons/
```

### 启用（编辑 `~/.hammerspoon/init.lua`）

```lua
hs.loadSpoon("WindowSwitcher")
spoon.WindowSwitcher:start()
```

然后在 Hammerspoon 菜单栏点 **Reload Config**（或重启 Hammerspoon）。

---

## 使用

| 操作 | 按键 |
| --- | --- |
| 下一个 app | `Cmd+Tab`（按住 `Cmd` 连续 `Tab`） |
| 上一个 app | 按住 `Cmd` 时按 `Shift` |
| 确认切换 | 松开 `Cmd` |
| 取消 | `Esc` |

---

## 配置

在 `start()` **之前**覆盖默认值即可：

```lua
hs.loadSpoon("WindowSwitcher")
spoon.WindowSwitcher.iconSize = 96   -- 图标尺寸
spoon.WindowSwitcher.padding = 20    -- 容器内边距
spoon.WindowSwitcher.gap = 16        -- 图标间距
spoon.WindowSwitcher:start()
```

| 配置项 | 默认 | 说明 |
| --- | --- | --- |
| `iconSize` | `72` | app 图标尺寸 |
| `padding` | `16` | 浮层内边距 |
| `gap` | `14` | 图标之间的间距 |

---

## 卸载 / 停用

```lua
spoon.WindowSwitcher:stop()   -- 恢复系统 Cmd+Tab
```

或删除 `~/.hammerspoon/Spoons/WindowSwitcher.spoon` 并移除 init.lua 中的相关行。

---

## License

[MIT](LICENSE)
