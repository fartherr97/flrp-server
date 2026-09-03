-- ==========================================================================
-- FLRP :: flrp_interact/client/menu.lua — native-style menu (vMenu look)
-- ==========================================================================
-- Self-contained scaleform-free menu drawn with GTA draw natives: a coloured
-- banner, subtitle bar with a counter, dark rows with a light selected row, a
-- description box and a bottom hint bar. Keyboard + mouse-wheel navigation,
-- submenus with a back stack, disabled items, and per-item value text.
--
-- Exposed to the rest of the resource (same client Lua state) as `FLRPMenu`:
--   local m = FLRPMenu.New('Title', 'SUBTITLE')
--   m:Item({ label=, desc=, right=, disabled=, sub=<menu>, onSelect=fn, close=bool })
--   m:Clear()
--   FLRPMenu.Open(m) / FLRPMenu.Close() / FLRPMenu.IsOpen()
--   FLRPMenu.OnClose(fn)   -- called whenever the menu fully closes
-- ==========================================================================

FLRPMenu = FLRPMenu or {}

local T          = FLRP_INTERACT.Theme
local stack      = {}          -- open submenu stack; stack[#stack] is visible
local visible    = false
local closeCbs   = {}
local VISIBLE_ROWS = 10

-- ---- geometry (screen fractions, origin top-left) ------------------------
local X, Y, W = 0.055, 0.045, 0.205    -- top-left corner + width
local BANNER_H = 0.055
local SUB_H    = 0.030
local ROW_H    = 0.030
local DESC_H   = 0.040
local HINT_H   = 0.026
local PAD      = 0.006
local CX       = X + W / 2

-- ---- draw helpers --------------------------------------------------------
local function rect(cx, cy, w, h, c)
  DrawRect(cx, cy, w, h, c[1], c[2], c[3], c[4] or 255)
end

local function text(str, x, y, scale, c, opt)
  opt = opt or {}
  SetTextFont(opt.font or 0)
  SetTextScale(0.0, scale)
  SetTextColour(c[1], c[2], c[3], c[4] or 255)
  if opt.center then SetTextCentre(true) end
  if opt.right then SetTextRightJustify(true); SetTextWrap(0.0, opt.edge or x) end
  if opt.wrap then SetTextWrap(opt.wrapL or 0.0, opt.wrapR or 1.0) end
  BeginTextCommandDisplayText('STRING')
  AddTextComponentSubstringPlayerName(tostring(str))
  EndTextCommandDisplayText(x, y)
end

local function sound(name)
  PlaySoundFrontend(-1, name, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

-- ---- menu object ---------------------------------------------------------
local MenuMT = {}
MenuMT.__index = MenuMT

function FLRPMenu.New(title, subtitle)
  return setmetatable({
    title = title or FLRP_INTERACT.Title,
    subtitle = subtitle or '',
    items = {}, index = 1, offset = 0,
  }, MenuMT)
end

function MenuMT:Item(o)
  self.items[#self.items + 1] = o or {}
  return self
end

function MenuMT:Clear()
  self.items, self.index, self.offset = {}, 1, 0
  return self
end

-- ---- open / close --------------------------------------------------------
function FLRPMenu.IsOpen() return visible end

function FLRPMenu.OnClose(fn) closeCbs[#closeCbs + 1] = fn end

local function fullClose()
  visible = false
  stack = {}
  for _, fn in ipairs(closeCbs) do pcall(fn) end
end

function FLRPMenu.Close()
  if not visible then return end
  fullClose()
  sound('BACK')
end

function FLRPMenu.Open(menu)
  if not menu then return end
  menu.index, menu.offset = 1, 0
  stack = { menu }
  visible = true
  sound('SELECT')
end

local function current() return stack[#stack] end

local function moveIndex(dir)
  local m = current(); if not m or #m.items == 0 then return end
  local n = #m.items
  local start = m.index
  repeat
    m.index = m.index + dir
    if m.index < 1 then m.index = n elseif m.index > n then m.index = 1 end
  until (not m.items[m.index].disabled) or m.index == start
  -- keep the selection inside the visible window
  if m.index - 1 < m.offset then m.offset = m.index - 1 end
  if m.index > m.offset + VISIBLE_ROWS then m.offset = m.index - VISIBLE_ROWS end
  sound('NAV_UP_DOWN')
end

local function select()
  local m = current(); if not m then return end
  local it = m.items[m.index]; if not it or it.disabled then sound('ERROR'); return end
  if it.sub then
    it.sub.index, it.sub.offset = 1, 0
    stack[#stack + 1] = it.sub
    sound('SELECT')
    return
  end
  sound('SELECT')
  if it.onSelect then pcall(it.onSelect, it) end
  if it.close then FLRPMenu.Close() end
end

local function back()
  if #stack > 1 then
    stack[#stack] = nil
    sound('BACK')
  else
    FLRPMenu.Close()
  end
end

-- ---- render + input loop -------------------------------------------------
-- Controls interfere with play; disable the ones that would fire while the
-- player is navigating, leave frontend nav controls (172-177) usable.
local BLOCK = {
  24, 25, 47, 58, 140, 141, 142, 143, 257, 263, 264, -- attack / aim / melee / throw
  22, 44, 37, 157, 158, 159, 160, 161, 162, 163, 164, 165, -- jump / cover / weapon wheel + select
  1, 2,                                                 -- look LR/UD (freezes camera drift)
}

local function draw()
  local m = current(); if not m then return end
  local n = #m.items
  local y = Y

  -- banner
  rect(CX, y + BANNER_H / 2, W, BANNER_H, T.banner)
  text(m.title, CX, y + 0.006, 0.62, T.accent, { center = true, font = 1 })
  if m.subtitle and m.subtitle ~= '' then
    text(m.subtitle, CX, y + 0.034, 0.30, T.textIdle, { center = true, font = 0 })
  end
  -- accent underline
  rect(CX, y + BANNER_H, W, 0.003, T.accent)
  y = y + BANNER_H + 0.003

  -- subtitle / counter bar
  rect(CX, y + SUB_H / 2, W, SUB_H, T.subtitle)
  text('BROWSE', X + PAD, y + 0.005, 0.28, T.accent, { font = 0 })
  if n > 0 then
    text(('%d / %d'):format(m.index, n), X + W - PAD, y + 0.005, 0.28, T.textIdle, { right = true, edge = X + W - PAD })
  end
  y = y + SUB_H

  -- rows (windowed)
  if m.index - 1 < m.offset then m.offset = m.index - 1 end
  if m.index > m.offset + VISIBLE_ROWS then m.offset = m.index - VISIBLE_ROWS end
  local first = m.offset + 1
  local last  = math.min(n, m.offset + VISIBLE_ROWS)

  if n == 0 then
    rect(CX, y + ROW_H / 2, W, ROW_H, T.rowIdle)
    text('Nothing available', X + PAD, y + 0.005, 0.30, T.textDim, { font = 0 })
    y = y + ROW_H
  else
    for i = first, last do
      local it = m.items[i]
      local sel = (i == m.index)
      rect(CX, y + ROW_H / 2, W, ROW_H, sel and T.rowSel or T.rowIdle)
      local tc = it.disabled and T.textDim or (sel and T.textSel or T.textIdle)
      text(it.label or '—', X + PAD, y + 0.005, 0.30, tc, { font = 0 })
      local rt = it.right or (it.sub and '›' or nil)
      if rt then
        text(rt, X + W - PAD, y + 0.005, 0.30, tc, { right = true, edge = X + W - PAD, font = 0 })
      end
      y = y + ROW_H
    end
    -- scroll indicator
    if n > VISIBLE_ROWS then
      rect(CX, y + 0.011, W, 0.022, T.subtitle)
      text(('▲ ▼   %d more'):format(n - VISIBLE_ROWS), CX, y + 0.003, 0.26, T.textDim, { center = true })
      y = y + 0.022
    end
  end

  -- description box
  local desc = (n > 0 and m.items[m.index] and m.items[m.index].desc) or nil
  if desc then
    y = y + 0.004
    rect(CX, y + DESC_H / 2, W, DESC_H, T.desc)
    text(desc, X + PAD, y + 0.006, 0.28, T.descText, { wrap = true, wrapL = X + PAD, wrapR = X + W - PAD, font = 0 })
    y = y + DESC_H
  end

  -- hint bar
  y = y + 0.004
  rect(CX, y + HINT_H / 2, W, HINT_H, T.banner)
  text('Enter Select   ·   Backspace Back   ·   ' .. FLRP_INTERACT.Key .. ' Close',
       CX, y + 0.005, 0.26, T.textDim, { center = true })
end

-- key-repeat state for held up/down
local repeatAt = 0

CreateThread(function()
  while true do
    if visible then
      draw()

      -- block interfering controls this frame
      for _, c in ipairs(BLOCK) do DisableControlAction(0, c, true) end
      DisableFirstPersonCamThisFrame()

      local up   = IsControlJustPressed(0, 172) or IsControlJustPressed(0, 241) -- FrontendUp / wheel up
      local down = IsControlJustPressed(0, 173) or IsControlJustPressed(0, 242) -- FrontendDown / wheel down
      -- held repeat
      local now = GetGameTimer()
      if IsControlPressed(0, 172) or IsControlPressed(0, 173) then
        if now >= repeatAt then
          if IsControlPressed(0, 172) then up = true elseif IsControlPressed(0, 173) then down = true end
          repeatAt = now + 140
        end
      else
        repeatAt = 0
      end

      if up then moveIndex(-1) end
      if down then moveIndex(1) end
      if IsControlJustPressed(0, 176) or IsControlJustPressed(0, 201) then select() end -- FrontendAccept / Enter
      if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then back()   end -- FrontendCancel / Backspace/Esc

      Wait(0)
    else
      Wait(150)
    end
  end
end)
