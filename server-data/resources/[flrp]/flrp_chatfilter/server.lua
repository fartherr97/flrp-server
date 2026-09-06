-- ==========================================================================
-- FLRP :: flrp_chatfilter/server.lua — slur matcher + enforcement
-- ==========================================================================
-- Public API (called by flrp_chat and flrp_messages):
--   exports.flrp_chatfilter:Check(msg)      -> matched root | nil   (no side effects)
--   exports.flrp_chatfilter:Scan(src, msg)  -> true if blocked      (kicks + logs)
--   exports.flrp_chatfilter:Punish(src, root, msg)                   (kick + log)
-- ==========================================================================

local CF = FLRP_CHATFILTER

-- Common leetspeak -> letters, so obfuscated slurs still resolve.
local LEET = {
  ['@'] = 'a', ['4'] = 'a', ['8'] = 'b', ['3'] = 'e', ['1'] = 'i', ['!'] = 'i',
  ['|'] = 'i', ['0'] = 'o', ['$'] = 's', ['5'] = 's', ['7'] = 't', ['+'] = 't',
  ['9'] = 'g', ['2'] = 'z',
}
local function deleet(s)
  return (s:lower():gsub('.', function(ch) return LEET[ch] or ch end))
end

-- Build a per-root pattern: each letter as `x+` (repeats collapse), with any
-- run of non-letters allowed between letters, anchored at word boundaries.
-- "nigger" -> %f[%a]n+[^%a]*i+[^%a]*g+[^%a]*g+[^%a]*e+[^%a]*r+%f[%A]
-- Requires the real letters in order (so "Niger"/"Nigeria" — one g — never hit).
local SEP = '[^%a]*'
local function buildPattern(root)
  root = root:lower():gsub('[^%a]', '')
  if root == '' then return nil end
  local parts = {}
  for i = 1, #root do parts[i] = root:sub(i, i) .. '+' end
  return '%f[%a]' .. table.concat(parts, SEP) .. '%f[%A]'
end

local patterns = {}
for _, root in ipairs(CF.Banned or {}) do
  local p = buildPattern(root)
  if p then patterns[#patterns + 1] = { root = root, pat = p } end
end

-- Returns the matched banned root, or nil. No side effects.
local function check(msg)
  if not CF.Enabled or type(msg) ~= 'string' or msg == '' then return nil end
  local norm = deleet(msg)
  for _, e in ipairs(patterns) do
    if norm:find(e.pat) then return e.root end
  end
  return nil
end
exports('Check', check)

local function pname(src) return GetPlayerName(src) or ('Player ' .. tostring(src)) end

local function staffRole()
  local c = GetConvar('flrp_staff_role_id', '')
  if c ~= '' then return c end
  return (CF.StaffRoleId and CF.StaffRoleId ~= '') and CF.StaffRoleId or nil
end

-- Log to Discord (pinging the staff role above the embed) + kick.
local function punish(src, root, msg)
  local rid = staffRole()
  pcall(function()
    exports.flrp_logs:Send(CF.LogCategory or 'chatfilter', {
      player      = src,
      title       = 'SLUR FILTER — AUTO KICK',
      color       = 0xe74c3c,
      description = ('**%s** said a prohibited slur in chat and was **auto-kicked**.'):format(pname(src)),
      fields      = {
        { name = 'What they typed', value = ('```%s```'):format(tostring(msg):sub(1, 400)), inline = false },
        { name = 'Matched',         value = ('||%s||'):format(root), inline = true },
      },
      content      = rid and ('<@&%s>'):format(rid) or nil,   -- ping ABOVE the embed
      mentionRoles = rid and { rid } or nil,
    })
  end)
  if CF.KickPlayer and type(src) == 'number' and src > 0 then
    DropPlayer(src, CF.KickMessage or 'Kicked for a prohibited slur.')
  end
end
exports('Punish', punish)

-- Check + enforce; returns true if the message must be blocked.
local function scan(src, msg)
  local root = check(msg)
  if not root then return false end
  punish(src, root, msg)
  return true
end
exports('Scan', scan)

CreateThread(function()
  Wait(1200)
  print(('[flrp_chatfilter] %s — %d banned root(s), kick=%s, staff-role=%s')
    :format(CF.Enabled and 'ACTIVE' or 'DISABLED', #patterns,
      tostring(CF.KickPlayer), staffRole() and 'set' or 'UNSET'))
end)
