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
| 延迟字母提示 | 按住 `Cmd` 超过 350ms，图标右上角才出现字母；快速 `Cmd+Tab` 时界面和原来完全一样 |
| `Cmd+字母` 直接跳转 | 切换器打开后按 `Cmd+字母` 立即切到对应 app，不必先松开 `Cmd`；不等提示出现也能按 |
| 稳定的字母映射 | `appKeys` 固定常用 app 的字母；其余按名称自动分配，只取决于 app 集合，不随 MRU 顺序变化 |
| 左手单手切换 | 自动分配优先用左手 home 行 `F D S A`，其次上排 `R E W Q`、下排 `V C X Z`；拇指按住 `Cmd`，其余四指不用离开原位 |

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
| 上一个 app | 按住 `Cmd` 时按 `Shift`，或 `Cmd+Shift+Tab` |
| 确认切换 | 松开 `Cmd` |
| 直接跳到某个 app | 按住 `Cmd` 时按该 app 的字母 |
| 取消 | `Esc` |

切换器打开期间，没有对应 app 的 `Cmd+字母` 也会被吞掉，不会误触发前台 app 的 `Cmd+Q` / `Cmd+W`。

### 字母分配规则

左手拇指按住 `Cmd` 时，最顺手的是左手区的 12 个键（`T` / `G` / `B` 需要食指横向伸展，不优先使用）：

```
上排   Q  W  E  R  ·T
home   A  S  D  F  ·G     ← 优先级最高
下排   Z  X  C  V  ·B
```

1. `appKeys` 里配置的字母优先，并且**全局保留**：即使该 app 没开，这个字母也不会分给别人。
2. 其余 app 按 `.app` 文件名排序（微信是 `WeChat.app`），分多轮认领字母，每轮只处理还没分到的 app：
   1. 名称**首字母**中落在左手区的（含驼峰，`Google Chrome` → `c`，`Safari` → `s`）
   2. 名称其余字母中落在左手区的（`iTerm` → `e`）
   3. 左手区按 `F D S A → R E W Q → V C X Z` 顺序取第一个空闲键（`Notion` 名字里没有左手区字母，F 被 Finder 占了就取 `d`）
   4. 左手区用完后：名称里的任意字母，再按 `T G B → 右手由近到远` 兜底
3. 纯中文名取不到字母时，退到 bundleID 末段（`com.tencent.WeWorkMac` → `WeWorkMac`）。
4. 只用 `a`–`z`，超过 26 个 app 时多出来的不显示字母。

建议 `appKeys` 里固定的字母也放在左手区，这样所有常用 app 都能单手切换。

---

## 配置

在 `start()` **之前**覆盖默认值即可：

```lua
hs.loadSpoon("WindowSwitcher")
spoon.WindowSwitcher.iconSize = 96   -- 图标尺寸
spoon.WindowSwitcher.padding = 20    -- 容器内边距
spoon.WindowSwitcher.gap = 16        -- 图标间距
spoon.WindowSwitcher.hintDelay = 0.35  -- 字母提示延迟（秒）
spoon.WindowSwitcher.appKeys = {      -- 固定字母
  ["com.google.Chrome"] = "c",
  ["com.tencent.xinWeChat"] = "w",
  ["com.googlecode.iterm2"] = "e",
}
spoon.WindowSwitcher:start()
```

查 app 的 bundleID：`osascript -e 'id of app "Google Chrome"'`。

| 配置项 | 默认 | 说明 |
| --- | --- | --- |
| `iconSize` | `72` | app 图标尺寸 |
| `padding` | `16` | 浮层内边距 |
| `gap` | `14` | 图标之间的间距 |
| `hintDelay` | `0.35` | 按住 `Cmd` 多久后显示字母（秒），`nil` 不显示（`Cmd+字母` 仍可用） |
| `hintSize` | `22` | 字母角标尺寸 |
| `appKeys` | `{}` | 固定字母 `{ [bundleID] = "c" }` |
| `preferredKeys` | `"fdsarewqvcxz"` | 自动分配优先使用的字母，按优先级排列 |
| `fallbackKeys` | `"tgbyhnujmikolp"` | 优先字母用完后的兜底顺序 |

---

## 卸载 / 停用

```lua
spoon.WindowSwitcher:stop()   -- 恢复系统 Cmd+Tab
```

或删除 `~/.hammerspoon/Spoons/WindowSwitcher.spoon` 并移除 init.lua 中的相关行。

---

## License

[MIT](LICENSE)
