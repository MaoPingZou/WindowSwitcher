--- === WindowSwitcher ===
---
--- 极简窗口切换器（纯 Hammerspoon 实现），用来替换系统 Cmd+Tab。
--- 只展示「光标所在桌面」的 app，一个 app 一个图标，排除隐藏/最小化窗口。
--- 按住 Cmd 稍等，图标右上角会出现字母，Cmd+字母 直接跳转。
---
--- 用法（在 ~/.hammerspoon/init.lua 中）：
---   hs.loadSpoon("WindowSwitcher")
---   spoon.WindowSwitcher:start()
---
--- 可在 start() 之前覆盖配置，例如：
---   spoon.WindowSwitcher.iconSize = 96
---   spoon.WindowSwitcher.appKeys = { ["com.google.Chrome"] = "c" }

local obj = {}
obj.__index = obj

-- 元数据
obj.name = "WindowSwitcher"
obj.version = "1.1.0"
obj.author = "MaoPingZou"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/MaoPingZou/WindowSwitcher"

-- ===== 可配置项 =====
obj.iconSize = 72   -- 图标尺寸
obj.padding = 16    -- 容器内边距
obj.gap = 14        -- 图标间距
obj.hintDelay = 0.35  -- 按住 Cmd 多久后显示字母角标（秒），nil 则不显示（Cmd+字母 跳转仍可用）
obj.hintSize = 22     -- 字母角标尺寸
obj.appKeys = {}      -- 固定字母 { [bundleID] = "c" }；未配置的 app 按名称自动分配

-- ===== 内部状态 =====
function obj:init()
  self._level = hs.canvas.windowLevels.overlay
  -- 只匹配「当前空间」内「可见」（排除隐藏/最小化）的标准窗口
  self._wf = hs.window.filter.new(false)
  self._wf:setDefaultFilter({ visible = true, allowRoles = "AXStandardWindow" })
  self._wf:setCurrentSpace(true)
  self._state = { canvas = nil, entries = {}, idx = 1, watcher = nil, shiftDown = false, shiftStepped = false,
                  hintTimer = nil }
  return self
end

-- 收集当前桌面的 app（按最近使用排序，并按 app 去重）
function obj:_collect()
  local wins = self._wf:getWindows(hs.window.filter.sortByFocusedLast)
  local entries, seen = {}, {}
  for _, w in ipairs(wins) do
    local app = w:application()
    if app then
      local pid = app:pid()
      if not seen[pid] then
        seen[pid] = true
        entries[#entries + 1] = { app = app, win = w }
      end
    end
  end
  return entries
end

-- 名称中的候选字母：先单词首字母（含驼峰，如 WeChat -> w, c），再其余字母
local function keyCandidates(name, out)
  local initials, others = {}, {}
  local prev = ""
  for ch in name:gmatch(".") do
    if ch:match("[A-Za-z]") then
      local isInitial = not prev:match("[A-Za-z]") or (ch:match("%u") and prev:match("%l"))
      table.insert(isInitial and initials or others, ch:lower())
    end
    prev = ch
  end
  for _, ch in ipairs(initials) do out[#out + 1] = ch end
  for _, ch in ipairs(others) do out[#out + 1] = ch end
end

-- 给 entries 分配字母（e.key）。appKeys 里的字母全局保留，保证固定映射不被抢；
-- 其余 app 按名称排序后依次取名称里第一个空闲字母，结果只取决于 app 集合，不随 MRU 顺序变化
function obj:_assignKeys(entries)
  local used, auto = {}, {}
  for _, k in pairs(self.appKeys) do used[k:lower()] = true end
  for _, e in ipairs(entries) do
    local bid = e.app:bundleID()
    local fixed = bid and self.appKeys[bid]
    if fixed then
      e.key = fixed:lower()
    else
      -- .app 文件名一般是英文（如 微信 -> WeChat.app），优先用它取字母
      local path = e.app:path()
      e.label = (path and path:match("([^/]+)%.app/?$")) or e.app:name() or bid or ""
      auto[#auto + 1] = e
    end
  end
  table.sort(auto, function(a, b) return a.label < b.label end)
  for _, e in ipairs(auto) do
    local cands = {}
    keyCandidates(e.label, cands)
    keyCandidates(e.app:name() or "", cands)
    -- 纯中文名（如 企业微信.app）取不到字母时，退到 bundleID 末段（com.tencent.WeWorkMac -> WeWorkMac）
    keyCandidates((e.app:bundleID() or ""):match("[^.]*$"), cands)
    keyCandidates("abcdefghijklmnopqrstuvwxyz", cands)
    for _, ch in ipairs(cands) do
      if not used[ch] then
        e.key, used[ch] = ch, true
        break
      end
    end
  end
end

function obj:_iconX(i)
  return self.padding + (i - 1) * (self.iconSize + self.gap)
end

function obj:_highlightFrame(i)
  return {
    x = self:_iconX(i) - 6,
    y = self.padding - 6,
    w = self.iconSize + 12,
    h = self.iconSize + 12,
  }
end

function obj:_build()
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  local sf = screen:frame()
  local n = #self._state.entries
  local w = self.padding * 2 + n * self.iconSize + (n - 1) * self.gap
  local h = self.padding * 2 + self.iconSize
  local x = sf.x + (sf.w - w) / 2
  local y = sf.y + (sf.h - h) / 2

  local c = hs.canvas.new({ x = x, y = y, w = w, h = h })
  -- 背景
  c[1] = {
    type = "rectangle",
    action = "fill",
    roundedRectRadii = { xRadius = 18, yRadius = 18 },
    fillColor = { black = 1, alpha = 0.6 },
  }
  -- 选中高亮（元素 2，后续只更新它的 frame）
  c[2] = {
    type = "rectangle",
    action = "fill",
    roundedRectRadii = { xRadius = 12, yRadius = 12 },
    fillColor = { white = 1, alpha = 0.28 },
    frame = self:_highlightFrame(self._state.idx),
  }
  -- app 图标
  for i, e in ipairs(self._state.entries) do
    local img
    local bid = e.app:bundleID()
    if bid then img = hs.image.imageFromAppBundle(bid) end
    c[#c + 1] = {
      type = "image",
      image = img,
      frame = { x = self:_iconX(i), y = self.padding, w = self.iconSize, h = self.iconSize },
    }
  end
  c:level(self._level)
  c:show()
  self._state.canvas = c

  -- 按住 Cmd 超过 hintDelay 才显示字母，快速 Cmd+Tab 时界面与原来一致
  if self.hintDelay then
    self._state.hintTimer = hs.timer.doAfter(self.hintDelay, function()
      self._state.hintTimer = nil
      self:_showHints()
    end)
  end
end

-- 在图标右上角追加字母角标（样式与 WindowGrid 的字母提示一致）
function obj:_showHints()
  local c = self._state.canvas
  if not c then return end
  local sz = self.hintSize
  for i, e in ipairs(self._state.entries) do
    if e.key then
      local hx, hy = self:_iconX(i) + self.iconSize - sz + 4, self.padding - 4
      c[#c + 1] = {
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 5, yRadius = 5 },
        fillColor = { red = 1, green = 0.8, blue = 0.1, alpha = 0.95 },
        frame = { x = hx, y = hy, w = sz, h = sz },
      }
      c[#c + 1] = {
        type = "text",
        text = string.upper(e.key),
        textColor = { black = 1, alpha = 1 },
        textSize = 14,
        textFont = "Menlo-Bold",
        textAlignment = "center",
        frame = { x = hx, y = hy + 2, w = sz, h = sz },
      }
    end
  end
end

function obj:_updateHighlight()
  if self._state.canvas then
    self._state.canvas[2].frame = self:_highlightFrame(self._state.idx)
  end
end

function obj:_cancel()
  if self._state.hintTimer then self._state.hintTimer:stop(); self._state.hintTimer = nil end
  if self._state.canvas then self._state.canvas:delete(); self._state.canvas = nil end
  self._state.entries = {}
end

function obj:_commit()
  local e = self._state.entries[self._state.idx]
  self:_cancel()
  if e and e.win then
    e.win:focus()
  elseif e and e.app then
    e.app:activate()
  end
end

-- delta: 1 下一个 / -1 上一个
function obj:_step(delta)
  if not self._state.canvas then
    self._state.entries = self:_collect()
    if #self._state.entries == 0 then return end
    self:_assignKeys(self._state.entries)
    self._state.idx = 1
    self:_build()
  end
  local n = #self._state.entries
  self._state.idx = (self._state.idx - 1 + delta) % n + 1
  self:_updateHighlight()
end

function obj:next() self:_step(1) end
function obj:previous() self:_step(-1) end

-- Cmd+字母：直接切到对应 app，不必先松开 Cmd
function obj:_jump(key)
  for i, e in ipairs(self._state.entries) do
    if e.key == key then
      self._state.idx = i
      self:_commit()
      return
    end
  end
end

-- 事件处理：直接拦截 Cmd+Tab（hs.hotkey 抢不过系统切换器，必须用 eventtap 吞事件）
function obj:_handleEvent(ev)
  local types = hs.eventtap.event.types
  local t = ev:getType()

  if t == types.flagsChanged then
    local flags = ev:getFlags()
    if self._state.canvas then
      if not flags.cmd then
        -- 松开 Cmd：确认选中
        self._state.shiftDown = false
        self:_commit()
      elseif flags.shift and not self._state.shiftDown then
        -- 按住 Cmd 时点一下 Shift：往回退一个（边沿触发）
        self:previous()
        self._state.shiftStepped = true
      end
    end
    self._state.shiftDown = flags.shift or false
    if not self._state.shiftDown then self._state.shiftStepped = false end
    return false
  end

  -- keyDown
  local flags = ev:getFlags()
  local key = hs.keycodes.map[ev:getKeyCode()]
  if key == "tab" and flags.cmd then
    if not flags.shift then
      self:next()
    elseif self._state.shiftStepped then
      -- 按下 Shift 时已经退过一个，这次 Shift+Tab 不再重复退
      self._state.shiftStepped = false
    else
      self:previous()
    end
    return true -- 吞掉事件，阻止系统切换器
  end
  -- 切换器打开时，吞掉 Shift 抬起时可能发出的 Ctrl+Space（输入法切换键），
  -- 否则叠加正按住的 Cmd 会变成 Ctrl+Cmd+Space 弹出字符检视器
  if self._state.canvas and key == "space" and flags.ctrl then
    return true
  end
  if key == "escape" and self._state.canvas then
    self:_cancel()
    return true
  end
  -- 切换器打开时吞掉所有 Cmd+字母，没有对应 app 的字母也不会漏给前台 app（比如 Cmd+Q / Cmd+W）
  if self._state.canvas and flags.cmd and key and key:match("^[a-z]$") then
    self:_jump(key)
    return true
  end
  return false
end

--- WindowSwitcher:start()
--- Method
--- 启动切换器（开始拦截 Cmd+Tab）。
function obj:start()
  if self._state.watcher then return self end
  local types = hs.eventtap.event.types
  self._state.watcher = hs.eventtap.new({ types.keyDown, types.flagsChanged }, function(ev)
    return self:_handleEvent(ev)
  end)
  self._state.watcher:start()
  return self
end

--- WindowSwitcher:stop()
--- Method
--- 停止切换器（恢复系统 Cmd+Tab）。
function obj:stop()
  if self._state.watcher then self._state.watcher:stop(); self._state.watcher = nil end
  self:_cancel()
  return self
end

return obj
