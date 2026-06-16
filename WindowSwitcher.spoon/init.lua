--- === WindowSwitcher ===
---
--- 极简窗口切换器（纯 Hammerspoon 实现），用来替换系统 Cmd+Tab。
--- 只展示「光标所在桌面」的 app，一个 app 一个图标，排除隐藏/最小化窗口。
---
--- 用法（在 ~/.hammerspoon/init.lua 中）：
---   hs.loadSpoon("WindowSwitcher")
---   spoon.WindowSwitcher:start()
---
--- 可在 start() 之前覆盖配置，例如：
---   spoon.WindowSwitcher.iconSize = 96

local obj = {}
obj.__index = obj

-- 元数据
obj.name = "WindowSwitcher"
obj.version = "1.0.0"
obj.author = "MaoPingZou"
obj.license = "MIT - https://opensource.org/licenses/MIT"
obj.homepage = "https://github.com/MaoPingZou/WindowSwitcher"

-- ===== 可配置项 =====
obj.iconSize = 72   -- 图标尺寸
obj.padding = 16    -- 容器内边距
obj.gap = 14        -- 图标间距

-- ===== 内部状态 =====
function obj:init()
  self._level = hs.canvas.windowLevels.overlay
  -- 只匹配「当前空间」内「可见」（排除隐藏/最小化）的标准窗口
  self._wf = hs.window.filter.new(false)
  self._wf:setDefaultFilter({ visible = true, allowRoles = "AXStandardWindow" })
  self._wf:setCurrentSpace(true)
  self._state = { canvas = nil, entries = {}, idx = 1, watcher = nil, shiftDown = false }
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

function obj:_highlightFrame(i)
  return {
    x = self.padding + (i - 1) * (self.iconSize + self.gap) - 6,
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
      frame = { x = self.padding + (i - 1) * (self.iconSize + self.gap), y = self.padding, w = self.iconSize, h = self.iconSize },
    }
  end
  c:level(self._level)
  c:show()
  self._state.canvas = c
end

function obj:_updateHighlight()
  if self._state.canvas then
    self._state.canvas[2].frame = self:_highlightFrame(self._state.idx)
  end
end

function obj:_cancel()
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
    self._state.idx = 1
    self:_build()
  end
  local n = #self._state.entries
  self._state.idx = (self._state.idx - 1 + delta) % n + 1
  self:_updateHighlight()
end

function obj:next() self:_step(1) end
function obj:previous() self:_step(-1) end

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
      end
    end
    self._state.shiftDown = flags.shift or false
    return false
  end

  -- keyDown
  local flags = ev:getFlags()
  local key = hs.keycodes.map[ev:getKeyCode()]
  if key == "tab" and flags.cmd then
    self:next()
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
