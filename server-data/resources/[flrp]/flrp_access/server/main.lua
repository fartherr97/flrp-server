-- ==========================================================================
-- FLRP :: flrp_access/server/main.lua — connection gate
-- ==========================================================================
-- The deferral flow:
--   connect -> identify FiveM player -> get Discord ID -> fetch guild member
--   -> verify membership -> verify Community Member role -> read roles ->
--   hand roles to flrp_permissions -> allow. Otherwise DENY.
-- See docs/DISCORD_INTEGRATION.md for the exact sequence + failure modes.
-- ==========================================================================

local function denyMessage(reason)
  local invite = FLRPA.Config.inviteUrl or ''
  return ('[FLRP] Connection denied: %s\n\nJoin & verify in our Discord: %s')
    :format(reason, invite)
end

-- Fire a #blocked-connection-logs entry. Best-effort; never breaks the gate.
-- The player isn't fully connected here, so the name/Discord id go in the body
-- rather than the "[id] rank | name" footer.
local function logBlocked(name, discordId, reason)
  pcall(function()
    exports.flrp_logs:Send('blocked', {
      description = ('**%s** was denied — %s'):format(name or 'Unknown', reason),
      fields = discordId and { { name = 'Discord ID', value = ('`%s`'):format(discordId), inline = true } } or nil,
    })
  end)
end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
  local source = source
  deferrals.defer()
  Wait(0)

  -- If the gate is disabled entirely (dev), allow with base membership only.
  if not FLRPA.Config.enabled then
    FLRP.Logger.Warn('access', 'Gate DISABLED (flrp_access_enabled=false); allowing', { name = name })
    local license = FLRP.Identity.GetLicense(source)
    if license then TriggerEvent('flrp_access:discordRolesResolved', license, {}) end
    deferrals.done()
    return
  end

  deferrals.update('[FLRP] Verifying your Discord membership...')

  -- 1. Identify player / Discord ID (server-derived).
  local discordId = FLRP.Identity.GetDiscordId(source)
  local license = FLRP.Identity.GetLicense(source)

  if not license then
    deferrals.done(denyMessage('could not read your FiveM license'))
    return
  end
  if not discordId then
    logBlocked(name, nil, 'no Discord account linked to FiveM client')
    deferrals.done(denyMessage(
      'no Discord account is linked to your FiveM client. Open the FiveM/Discord ' ..
      'integration (Discord > Settings > Connections, and link FiveM), then reconnect.'))
    return
  end

  -- If Discord isn't configured yet, honour fail-open/closed policy.
  if not FLRPA.Config.configured then
    if FLRPA.Config.failOpen then
      FLRP.Logger.Warn('access', 'Discord not configured; failing OPEN (base member only)')
      TriggerEvent('flrp_access:discordRolesResolved', license, {})
      deferrals.done()
    else
      FLRP.Logger.Error('access', 'Discord not configured; failing CLOSED (denying)')
      deferrals.done(denyMessage('the server\'s Discord verification is not configured yet. ' ..
        'Please try again later.'))
    end
    return
  end

  -- 2/3. Fetch guild member -> membership check.
  local status, member = FLRPA.Discord.GetGuildMember(FLRPA.Config.guildId, discordId)

  if status == 'not_member' then
    logBlocked(name, discordId, 'not a member of the FLRP Discord')
    deferrals.done(denyMessage('you are not a member of the FLRP Discord'))
    return
  elseif status == 'rate_limited' then
    deferrals.done(denyMessage('Discord verification is busy right now — please reconnect in a moment'))
    return
  elseif status ~= 'ok' then
    -- API/auth/error: honour fail-open/closed.
    if FLRPA.Config.failOpen then
      FLRP.Logger.Warn('access', 'Discord check failed; failing OPEN', { status = status })
      TriggerEvent('flrp_access:discordRolesResolved', license, {})
      deferrals.done()
    else
      FLRP.Logger.Error('access', 'Discord check failed; failing CLOSED', { status = status })
      deferrals.done(denyMessage('we could not verify your Discord membership right now'))
    end
    return
  end

  -- 4. Verify required Community Member / verification role (if configured).
  if FLRPA.Config.IsCommunityRoleRequired() then
    if not FLRPA.Discord.MemberHasRole(member, FLRPA.Config.communityRole) then
      logBlocked(name, discordId, 'missing Community Member (verification) role')
      deferrals.done(denyMessage(
        'you have not completed verification. Get the Community Member role in our Discord first'))
      return
    end
  end

  -- 5. Read roles -> hand to flrp_permissions (server event; not client-facing).
  local roleIds = member.roles or {}
  TriggerEvent('flrp_access:discordRolesResolved', license, roleIds)
  FLRP.Logger.Info('access', 'Player verified', {
    name = name, discordId = discordId, roleCount = #roleIds })

  -- 6. Allow.
  deferrals.done()
end)

-- Re-read convars if secrets are reloaded.
RegisterCommand('flrp_reload_access', function(source)
  if source ~= 0 then return end
  FLRPA.Config.Reload()
  FLRP.Logger.Info('access', 'Access config reloaded', { configured = FLRPA.Config.configured })
end, true)

CreateThread(function()
  while not (exports.flrp_core and exports.flrp_core:IsReady()) do Wait(500) end
  FLRP.Logger.Info('access', 'flrp_access ready', {
    enabled = FLRPA.Config.enabled, configured = FLRPA.Config.configured,
    failOpen = FLRPA.Config.failOpen })
end)
