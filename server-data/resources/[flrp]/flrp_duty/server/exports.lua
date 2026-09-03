-- ==========================================================================
-- FLRP :: flrp_duty/server/exports.lua — public API (read-only adapter)
-- ==========================================================================
--   exports.flrp_duty:GetDuty(source)              -> { department, onDuty }
--   exports.flrp_duty:IsOnDuty(source, department?) -> bool
--
-- Backed by flrp_onduty (flrp_duty_members). flrp_onduty owns changing duty;
-- there is no SetDuty/GoOffDuty here (use its /duty menu or its exports).
-- ==========================================================================

function GetDuty(source)
  return FLRPD.Get(source)
end

function IsOnDuty(source, department)
  local d = FLRPD.Get(source)
  if not d.onDuty then return false end
  if department == nil then return true end
  return string.upper(tostring(department)) == string.upper(tostring(d.department or ''))
end

--   exports.flrp_duty:GetOnDutyRoster() -> array of
--     { src, online, name, license, entity, department, callsign }
-- Live roster read from flrp_onduty's flrp_duty_members (see FLRPD.GetRoster).
function GetOnDutyRoster()
  return FLRPD.GetRoster()
end

--   exports.flrp_duty:Invalidate(source?) -> drop the cached duty for one player
--   (or everyone) so the next lookup re-reads the registry. flrp_onduty calls
--   this the moment someone goes on/off duty so counters update instantly.
function Invalidate(source)
  FLRPD.Invalidate(source)
end
