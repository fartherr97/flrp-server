-- ==========================================================================
-- FLRP :: flrp_duty/server/exports.lua — public API
-- ==========================================================================
--   exports.flrp_duty:GetDuty(source)               -> { department, onDuty }
--   exports.flrp_duty:IsOnDuty(source, department?)  -> bool
--   exports.flrp_duty:SetDuty(source, dept, onDuty)  -> ok, err   (validated)
--   exports.flrp_duty:GoOffDuty(source)              -> ok
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

function SetDuty(source, department, onDuty)
  return FLRPD.SetDuty(source, department, onDuty)
end

function GoOffDuty(source)
  return FLRPD.GoOffDuty(source)
end
