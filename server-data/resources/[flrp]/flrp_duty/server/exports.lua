-- ==========================================================================
-- FLRP :: flrp_duty/server/exports.lua — public API (read-only adapter)
-- ==========================================================================
--   exports.flrp_duty:GetDuty(source)              -> { department, onDuty }
--   exports.flrp_duty:IsOnDuty(source, department?) -> bool
--
-- Backed by nex-duty (duty_members). nex-duty owns changing duty; there is no
-- SetDuty/GoOffDuty here anymore (use the nex-duty /duty menu).
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
-- Live roster read from nex-duty's duty_members (see FLRPD.GetRoster).
function GetOnDutyRoster()
  return FLRPD.GetRoster()
end
