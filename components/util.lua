local AddonName,SAO=...
local ShortAddonName=strlower(AddonName):sub(0,8)=="necrosis" and "Necrosis" or "SAO"
local Module="util"
local GetActionInfo=GetActionInfo
local GetMacroSpell=GetMacroSpell
local GetNumSpellTabs=GetNumSpellTabs
local GetNumTalents=GetNumTalents
local GetNumTalentTabs=GetNumTalentTabs
local GetSpellBookItemName=GetSpellBookItemName
local GetSpellTabInfo=GetSpellTabInfo
local GetTalentInfo=GetTalentInfo
local GetTalentTabInfo=GetTalentTabInfo
local GetTime=GetTime
local UnitAura=UnitAura
local UnitClassBase=UnitClassBase
local GetAuraDataBySpellName=C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
local GetPlayerAuraBySpellID=C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
local GetNumSpecializationsForClassID=C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
local GetSpecializationInfo=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
GetTalentInfo=C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo or GetTalentInfo
local IsEquippedItem=C_Item and C_Item.IsEquippedItem

-- Compat: WrapTextInColor was renamed/removed in later clients.
-- Use WrapTextInColorCode (available in modern clients) as fallback.
local function WrapTextInColorCompat(text,color)
  if type(WrapTextInColor)=="function" then
    return WrapTextInColor(text,color)
  end
  if type(WrapTextInColorCode)=="function" and type(color)=="table" and type(color.GenerateHexColor)=="function" then
    return WrapTextInColorCode(text,color:GenerateHexColor())
  end
  return text
end

function SAO:Error(prefix,msg,...)
print(WrapTextInColorCompat("**"..ShortAddonName.."** -"..prefix.."- "..msg,RED_FONT_COLOR),...)
end
function SAO:Warn(prefix,msg,...)
print(WrapTextInColorCompat("!"..ShortAddonName.."! -"..prefix.."- "..msg,WARNING_FONT_COLOR),...)
end
function SAO:Info(prefix,msg,...)
print(WrapTextInColorCompat(ShortAddonName.." -"..prefix.."- "..msg,LIGHTBLUE_FONT_COLOR),...)
end
function SAO:HasDebug()
return ProcSpellOverlayDB and ProcSpellOverlayDB.debug
end
function SAO:Debug(prefix,msg,...)
if ProcSpellOverlayDB and ProcSpellOverlayDB.debug then
print(WrapTextInColorCode("["..ShortAddonName.."@"..GetTime().."] -"..prefix.."- "..msg, "FFFFFFAA"),...)
end
end
function SAO:HasTrace(prefix)
return ProcSpellOverlayDB and ProcSpellOverlayDB.trace and ProcSpellOverlayDB.trace[prefix]
end
function SAO.Trace(self,prefix,msg,...)
if ProcSpellOverlayDB and ProcSpellOverlayDB.trace and ProcSpellOverlayDB.trace[prefix] then
print(WrapTextInColorCode("{"..ShortAddonName.."@"..GetTime().."} -"..prefix.."- "..msg, "FFAAFFCC"),...)
end
end
function SAO:LogPersistent(prefix,msg)
if ProcSpellOverlayDB then
local line="[@"..GetTime().."] :"..prefix..": "..msg
if not ProcSpellOverlayDB.logs then
ProcSpellOverlayDB.logs={line}
else
tinsert(ProcSpellOverlayDB.logs,line)
end
end
end
local timeOfLastTrace={}
function SAO.TraceThrottled(self,key,prefix,...)
key=tostring(key)..tostring(prefix)
if not timeOfLastTrace[key] or GetTime() > timeOfLastTrace[key]+1 then
self:Trace(prefix,...)
timeOfLastTrace[key]=GetTime()
end
end
function SAO:CanReport()
return SAO.IsProject(SAO.MOP_AND_ONWARD)
end
function SAO:HasReport()
return ProcSpellOverlayDB and ProcSpellOverlayDB.report~=false
end
function SAO:ReportUnknownEffect(prefix,spellID,texture,positions,scale,r,g,b)
if self:CanReport()
and self:HasReport()
and self:AreEffectsInitialized()
and spellID
and not self:GetBucketBySpellID(spellID)
and not self:IsAka(spellID)
then
if not self.UnknownNativeEffects then
self.UnknownNativeEffects={}
end
if not self.UnknownNativeEffects[spellID] then
local text=""
text=text..", ".."flavor="..tostring(self.GetFlavorName())
text=text..", ".."spell="..tostring(spellID).." ("..self:GetSpellName(spellID, "unknown spell")..")"
text=text..", ".."tex="..tostring(texture)
text=text..", ".."pos="..((type(positions)=='string') and ("'"..positions.."'") or tostring(positions))
text=text..", ".."scale="..tostring(scale)
text=text..", ".."r="..tostring(r)
text=text..", ".."g="..tostring(g)
text=text..", ".."b="..tostring(b)
self.UnknownNativeEffects[spellID]=text
self:Info(prefix, "Unknown proc effect"..text)
end
end
end

-- (rest of file unchanged)
