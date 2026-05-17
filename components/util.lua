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
local GetSpellInfo=GetSpellInfo
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
function SAO:IsTimeAlmostEqual(t1, t2, epsilon)
  if type(t1) ~= "number" or type(t2) ~= "number" then
    return false
  end
  epsilon = (type(epsilon) == "number") and epsilon or 0.05
  return math.abs(t1 - t2) <= epsilon
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
function SAO:HasUnknownEffectReporting()
return ProcSpellOverlayDB
and ProcSpellOverlayDB.dev
and ProcSpellOverlayDB.dev.reportUnknownEffects==true
end
local function getCurrentClassAndSpec()
local classFile=select(2,UnitClass("player")) or "UNKNOWN"
local specName="UNKNOWN"
if type(GetSpecialization)=="function" and type(GetSpecializationInfo)=="function" then
local specIndex=GetSpecialization()
if specIndex then
local _,name=GetSpecializationInfo(specIndex)
if type(name)=="string" and #name > 0 then
specName=strupper(name)
else
specName=tostring(specIndex)
end
end
end
return classFile,specName
end
function SAO:GlowTracker_TrackSpellID(spellID,classFile,specName)
if type(spellID)~="number" then return end
if type(GlowTrackerDB)~="table" then
GlowTrackerDB={}
end
GlowTrackerDB.glows=GlowTrackerDB.glows or {}
classFile=classFile or select(2,UnitClass("player")) or "UNKNOWN"
if not specName then
local _,resolvedSpecName=getCurrentClassAndSpec()
specName=resolvedSpecName
end
GlowTrackerDB.glows[classFile]=GlowTrackerDB.glows[classFile] or {}
GlowTrackerDB.glows[classFile][specName]=GlowTrackerDB.glows[classFile][specName] or {}
GlowTrackerDB.glows[classFile][specName][spellID]=true
end
function SAO:ReportUnknownEffect(prefix,spellID,texture,positions,scale,r,g,b)
if not self:AreEffectsInitialized() then return end
if not spellID then return end
if self:GetBucketBySpellID(spellID) then return end
if self:IsAka(spellID) then return end
local classFile,specName=getCurrentClassAndSpec()
if type(self.GlowTracker_TrackSpellID)=="function" then
self:GlowTracker_TrackSpellID(spellID,classFile,specName)
end
ProcSpellOverlayDB = ProcSpellOverlayDB or {}
ProcSpellOverlayDB.unknownProcs = ProcSpellOverlayDB.unknownProcs or {}
local key=table.concat({
tostring(spellID),
tostring(texture),
tostring(positions),
tostring(scale),
tostring(r),
tostring(g),
tostring(b),
}, "|")
local now=(type(time)=="function" and time()) or math.floor(GetTime())
local entry=ProcSpellOverlayDB.unknownProcs[key]
if entry then
entry.lastSeen=now
entry.count=(tonumber(entry.count) or 0)+1
else
ProcSpellOverlayDB.unknownProcs[key]={
spellID=spellID,
texture=texture,
positions=positions,
scale=scale,
r=r,
g=g,
b=b,
firstSeen=now,
lastSeen=now,
count=1,
class=classFile,
spec=specName,
}
end
end

-- Internal registry: _EventHandlerRegistry[frame][eventName] = true
-- Prevents duplicate frame:RegisterEvent() calls for the same (frame, eventName) pair.
SAO._EventHandlerRegistry = {}

function SAO:RegisterEventHandler(frame, eventName, fromTag)
    if not self._EventHandlerRegistry[frame] then
        self._EventHandlerRegistry[frame] = {}
    end
    if not self._EventHandlerRegistry[frame][eventName] then
        frame:RegisterEvent(eventName)
        self._EventHandlerRegistry[frame][eventName] = true
        if self:HasDebug() then
            self:Debug("events", "RegisterEventHandler("..tostring(eventName)..")"
                ..(fromTag and " ["..fromTag.."]" or ""))
        end
    end
end

function SAO:UnregisterEventHandler(frame, eventName, fromTag)
    if self._EventHandlerRegistry[frame] and self._EventHandlerRegistry[frame][eventName] then
        frame:UnregisterEvent(eventName)
        self._EventHandlerRegistry[frame][eventName] = nil
        if self:HasDebug() then
            self:Debug("events", "UnregisterEventHandler("..tostring(eventName)..")"
                ..(fromTag and " ["..fromTag.."]" or ""))
        end
    end
end

-- Legion/WoD compatibility helpers --
function SAO:gradientText(text, ...)
  return tostring(text or "")
end
-- Returns a hash name string for the given aura stack count.
-- Used by class files to build setupHash/testHash overlay options.
-- Defers actual hash building to runtime so aurastacks variable is already registered.
function SAO:HashNameFromStacks(stacks)
    if stacks == nil then return nil end
    stacks = tonumber(stacks)
    if stacks == nil then return nil end
    local h = SAO.Hash:new()
    h:setAuraStacks(stacks)
    return h:toString()
end

-- Returns a hash name string from a raw numeric hash value.
-- Used internally by effect.lua when building overlay options.
function SAO:HashNameFromHashNumber(hashNumber)
    if type(hashNumber) ~= 'number' then return nil end
    return SAO.Hash:new(hashNumber):toString()
end

-- Maps an action bar slot to its associated spellID.
-- Handles direct spell slots and macro slots (via GetMacroSpell).
-- Compatible with Legion/WoD clients where GetActionInfo exists.
function SAO:GetSpellIDByActionSlot(slot)
    if type(slot) ~= 'number' then return nil end
    local actionType, id = GetActionInfo(slot)
    if actionType == 'spell' then
        return id
    elseif actionType == 'macro' then
        local macroSpellID = GetMacroSpell(id)
        if macroSpellID then return macroSpellID end
    end
    return nil
end

-- Returns the current global cooldown duration in seconds.
-- Uses spell 61304 (GCD placeholder) when available, otherwise falls back to 1.5s.
function SAO:GetGCD()
    local start, duration = SAO:GetSpellCooldown(61304)
    if type(duration) == 'number' and duration > 0 then
        return duration
    end
    return 1.5
end

function SAO:IsTimeAlmostEqual(t1,t2,epsilon)
    if type(t1)~='number' or type(t2)~='number' then
        return false
    end
    epsilon=math.abs(tonumber(epsilon) or 0)
    return math.abs(t1-t2) <= epsilon
end

-- Returns the stack count (and auraInstanceID if available) of a player aura by spellID.
-- Uses the modern C_UnitAuras API when available (Dragonflight+), otherwise falls back
-- to classic UnitAura scanning compatible with Legion/WoD clients.
function SAO:GetPlayerAuraStacksBySpellID(spellID)
    if not spellID then return nil, nil end
    -- Modern API (Dragonflight+)
    if GetPlayerAuraBySpellID then
        local aura = GetPlayerAuraBySpellID(spellID)
        if aura then
            return aura.applications or 0, aura.auraInstanceID
        end
        return nil, nil
    end
    -- Legacy UnitAura scanning (WoD/Legion era)
    local spellName = GetSpellInfo and GetSpellInfo(spellID) or nil
    for i = 1, 40 do
        local name, _, _, count, _, _, _, _, _, _, auraSpellID = UnitAura("player", i, "HELPFUL")
        if not name then break end
        if auraSpellID == spellID or (spellName and name == spellName) then
            return (count or 0), nil
        end
    end
    for i = 1, 40 do
        local name, _, _, count, _, _, _, _, _, _, auraSpellID = UnitAura("player", i, "HARMFUL")
        if not name then break end
        if auraSpellID == spellID or (spellName and name == spellName) then
            return (count or 0), nil
        end
    end
    return nil, nil
end

-- Returns true if responsive mode is enabled (more frequent polling).
-- Safe default is false; reads ProcSpellOverlayDB.responsiveMode when available.
function SAO:IsResponsiveMode()
    return ProcSpellOverlayDB and ProcSpellOverlayDB.responsiveMode == true
end

-- Returns a human-readable name string for a talent/spell ID, used by the options UI.
-- Minimal Legion/WoD-safe implementation: returns the spell name or empty string.
function SAO:GetTalentText(talentOrSpellID)
  if not talentOrSpellID then
    return ""
  end

  if type(talentOrSpellID) == "number" then
    local name = GetSpellInfo(talentOrSpellID)
    return name or ""
  end

  return tostring(talentOrSpellID)
end
