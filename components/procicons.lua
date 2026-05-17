local AddonName, SAO = ...
local Module = "procicons"
local LBG = LibStub and LibStub("LibButtonGlow-1.0", true)
local InCombatLockdown = InCombatLockdown

-- Minimal, universal "Blizzard-like" proc icon display.
-- Shows fixed-order icons for active proc overlays.

local DefaultOrderBySpec = {
  ["WARRIOR:71"] = {7384, 167105, 5308, 34428},
  ["WARRIOR:72"] = {190411, 5308, 184367},
  ["WARRIOR:73"] = {23922, 6572, 5308},
}
if (type(order) ~= "table" or #order == 0) and specKey and specKey:match("^WARRIOR:") then
  order = p.order["WARRIOR:71"]
end
-- Polling model: show icons when spells are usable (works even if overlay events are unreliable)
local POLL_INTERVAL = 0.10
local pollElapsed = 0

local function IsSpellReadyAndUsable(spellID)
  if type(spellID) ~= "number" then return false end
  if not (GetSpellInfo and GetSpellInfo(spellID)) then return false end

  local usable, noMana = IsUsableSpell and IsUsableSpell(spellID) or false, false
  if IsUsableSpell then
    usable, noMana = IsUsableSpell(spellID)
  end
  if not usable then
    return false
  end

  if GetSpellCooldown then
    local start, duration, enabled = GetSpellCooldown(spellID)
    if enabled == 0 then
      return false
    end
    if start and duration and start > 0 and duration > 0 then
      local remaining = (start + duration) - (GetTime and GetTime() or 0)
      if remaining > 0.05 then
        return false
      end
    end
  end

  return true
end

local function db()
  ProcSpellOverlayDB = ProcSpellOverlayDB or {}
  ProcSpellOverlayDB.procIcons = ProcSpellOverlayDB.procIcons or {}
  local p = ProcSpellOverlayDB.procIcons

  if p.enabled == nil then p.enabled = true end
  if p.locked == nil then p.locked = true end
  if p.size == nil then p.size = 56 end
  if p.point == nil then p.point = "CENTER" end
  if p.x == nil then p.x = 0 end
  if p.y == nil then p.y = -140 end
  if p.gap == nil then p.gap = 10 end
  if p.maxIcons == nil then p.maxIcons = 4 end
  if p.testMode == nil then p.testMode = false end
  p.maxIcons = math.max(1, math.floor(tonumber(p.maxIcons) or 4))
  p.order = p.order or {}
  for key, defaultOrder in pairs(DefaultOrderBySpec) do
    if type(p.order[key]) ~= "table" then
      p.order[key] = CopyTable(defaultOrder)
    end
  end

  return p
end

local function UpdateActiveFromUsability()
  local p = db()
  if not p.enabled then
    return false
  end

  -- Only poll in normal mode; test mode keeps its own behavior
  if p.testMode then
    return false
  end

  local specKey = GetCurrentClassSpecKey and GetCurrentClassSpecKey() or nil
  local order = specKey and p.order and p.order[specKey] or nil
  if type(order) ~= "table" or #order == 0 then
    return false
  end

  local changed = false

  -- We treat "active" as "usable now" for each ordered slot spellID
  for i = 1, p.maxIcons do
    local spellID = order[i]
    if type(spellID) == "number" then
      local shouldBeActive = false
		if type(GlowTrackerDB) == "table"
		and type(GlowTrackerDB.glows) == "table"
		and type(GlowTrackerDB.glows.WARRIOR) == "table"
		and type(GlowTrackerDB.glows.WARRIOR.ARMS) == "table"
		then
			shouldBeActive = GlowTrackerDB.glows.WARRIOR.ARMS[spellID] == true
		else
  -- fallback if GlowTracker isn't loaded
			shouldBeActive = IsSpellReadyAndUsable(spellID)
	  end
      local isActive = (activeDisplayRefCount[spellID] or 0) > 0

      if shouldBeActive and not isActive then
        activeDisplayRefCount[spellID] = 1
        changed = true
      elseif (not shouldBeActive) and isActive then
        activeDisplayRefCount[spellID] = nil
        changed = true
      end
    end
  end

  return changed
end

local activeByTrigger = {}       -- [triggerSpellID] = displaySpellID
local activeDisplayRefCount = {} -- [displaySpellID] = count
local pendingSecureAttributeRefresh = false
local GetCurrentClassSpecKey

local InternalAliasBySpec = {
  ["WARRIOR:71"] = {
    [60503] = 7384,   -- Taste for Blood -> Overpower
    [280776] = 5308,  -- Sudden Death -> Execute
    [199854] = 167105, -- Tactician -> Colossus Smash
  },
  ["WARRIOR:72"] = {
    [280776] = 5308, -- Sudden Death -> Execute
  },
  ["WARRIOR:73"] = {
    [280776] = 5308, -- Sudden Death -> Execute
  },
}

local function NormalizeSpellID(spellID)
  local id = tonumber(spellID)
  if not id then return nil end
  id = math.floor(id)
  if id <= 0 then return nil end
  return id
end

local function HasSpellInfo(spellID)
  return type(spellID) == "number" and GetSpellInfo and GetSpellInfo(spellID) ~= nil
end

local function IsPassiveSpellID(spellID)
  return type(IsPassiveSpell) == "function" and type(spellID) == "number" and IsPassiveSpell(spellID) or false
end

local function GetAliasValue(aliasTable, triggerSpellID)
  if type(aliasTable) ~= "table" then return nil end
  local value = aliasTable[triggerSpellID]
  if value == nil then
    value = aliasTable[tostring(triggerSpellID)]
  end
  return NormalizeSpellID(value)
end

local function ResolveDisplaySpellID(triggerSpellID)
  triggerSpellID = NormalizeSpellID(triggerSpellID)
  if not triggerSpellID then return nil end
  local specKey = GetCurrentClassSpecKey and GetCurrentClassSpecKey() or nil

  -- GlowTracker alias model (read-only):
  --  1) global:   GlowTrackerDB.alias[triggerSpellID] = displaySpellID
  --  2) per-spec: GlowTrackerDB.alias["CLASS:specID"][triggerSpellID] = displaySpellID
  -- Per-spec alias is preferred when present.
  local alias = type(GlowTrackerDB) == "table" and type(GlowTrackerDB.alias) == "table" and GlowTrackerDB.alias or nil
  local bySpecAlias = alias and specKey and GetAliasValue(alias[specKey], triggerSpellID) or nil
  local globalAlias = alias and GetAliasValue(alias, triggerSpellID) or nil
  local fallbackAlias = specKey and InternalAliasBySpec[specKey] and GetAliasValue(InternalAliasBySpec[specKey], triggerSpellID) or nil

  local candidates = {}
  local seen = {}
  for _, candidate in ipairs({bySpecAlias, globalAlias, fallbackAlias, triggerSpellID}) do
    if type(candidate) == "number" and not seen[candidate] then
      table.insert(candidates, candidate)
      seen[candidate] = true
    end
  end

  for _, candidate in ipairs(candidates) do
    if HasSpellInfo(candidate) and not IsPassiveSpellID(candidate) then
      return candidate
    end
  end
  for _, candidate in ipairs(candidates) do
    if HasSpellInfo(candidate) then
      return candidate
    end
  end
  return candidates[1]
end

local function GetSpellTextureCompat(spellID)
  if type(spellID) ~= "number" then return nil end
  local texture = GetSpellTexture and GetSpellTexture(spellID) or nil
  if texture then
    return texture
  end
  local _, _, iconTexture = GetSpellInfo and GetSpellInfo(spellID) or nil
  return iconTexture
end

local PLACEHOLDER_ALPHA = 0.5
local BORDER_R, BORDER_G, BORDER_B, BORDER_A = 0.82, 0.82, 0.82, 0.9
local GLOW_SCALE = 1.75

local container = CreateFrame("Frame", "SAO_ProcIconsContainer", UIParent)
container:SetClampedToScreen(true)
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
  local p = db()
  if not p.locked then self:StartMoving() end
end)
container:SetScript("OnUpdate", function(_, elapsed)
  pollElapsed = (pollElapsed or 0) + (elapsed or 0)
  if pollElapsed < POLL_INTERVAL then return end
  pollElapsed = 0

  if UpdateActiveFromUsability() then
    Refresh()
  end
end)
container:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p = db()
  local point, _, _, x, y = self:GetPoint(1)
  p.point, p.x, p.y = point, x, y
end)


local function CreateIconFrame(name)
  local f = CreateFrame("Button", name, container, "SecureActionButtonTemplate")
  f:Hide()
  f:RegisterForClicks("LeftButtonUp")

  f.fill = f:CreateTexture(nil, "BACKGROUND")
  f.fill:SetAllPoints(true)
  f.fill:SetColorTexture(0, 0, 0, PLACEHOLDER_ALPHA)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(true)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.icon:SetVertexColor(1, 1, 1, 1)

  f.fallbackGlow = f:CreateTexture(nil, "OVERLAY", nil, 7)
  f.fallbackGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.fallbackGlow:SetBlendMode("ADD")
  f.fallbackGlow:SetAlpha(0)
  f.fallbackGlow:Hide()

  f.fallbackGlowAnim = f.fallbackGlow:CreateAnimationGroup()
  f.fallbackGlowAnim:SetLooping("REPEAT")
  local glowAlphaIn = f.fallbackGlowAnim:CreateAnimation("Alpha")
  glowAlphaIn:SetOrder(1)
  glowAlphaIn:SetDuration(0.55)
  glowAlphaIn:SetFromAlpha(0.35)
  glowAlphaIn:SetToAlpha(0.95)
  local glowAlphaOut = f.fallbackGlowAnim:CreateAnimation("Alpha")
  glowAlphaOut:SetOrder(2)
  glowAlphaOut:SetDuration(0.55)
  glowAlphaOut:SetFromAlpha(0.95)
  glowAlphaOut:SetToAlpha(0.35)

  f:SetScript("OnSizeChanged", function(self, w, h)
    if self.fallbackGlow then
      local s = math.max(w or 0, h or 0)
      self.fallbackGlow:ClearAllPoints()
      self.fallbackGlow:SetPoint("CENTER", self, "CENTER", 0, 0)
      self.fallbackGlow:SetSize(s * GLOW_SCALE, s * GLOW_SCALE)
    end
  end)

  f.borderTop = f:CreateTexture(nil, "OVERLAY")
  f.borderRight = f:CreateTexture(nil, "OVERLAY")
  f.borderBottom = f:CreateTexture(nil, "OVERLAY")
  f.borderLeft = f:CreateTexture(nil, "OVERLAY")
  for _, border in ipairs({f.borderTop, f.borderRight, f.borderBottom, f.borderLeft}) do
    border:SetColorTexture(BORDER_R, BORDER_G, BORDER_B, BORDER_A)
  end

  -- Ensure no default button normal/highlight/pushed textures create an inner rectangle.
  if type(f.GetNormalTexture) == "function" then
    local normal = f:GetNormalTexture()
    if normal then
      normal:SetTexture(nil)
      normal:Hide()
    end
  end
  if type(f.SetNormalTexture) == "function" then
    f:SetNormalTexture(nil)
  end
  if type(f.SetHighlightTexture) == "function" then
    f:SetHighlightTexture(nil)
  end
  if type(f.GetHighlightTexture) == "function" then
    local highlight = f:GetHighlightTexture()
    if highlight then
      highlight:SetTexture(nil)
      highlight:Hide()
    end
  end
  if type(f.SetPushedTexture) == "function" then
    f:SetPushedTexture(nil)
  end
  if type(f.GetPushedTexture) == "function" then
    local pushed = f:GetPushedTexture()
    if pushed then
      pushed:SetTexture(nil)
      pushed:Hide()
    end
  end

  f:SetScript("OnEnter", function(self)
    local tooltipSpellID = self.displaySpellID
    if type(tooltipSpellID) ~= "number" then
      return
    end
    local spellName = GetSpellInfo and GetSpellInfo(tooltipSpellID) or nil
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(spellName or ("Spell "..tostring(tooltipSpellID)), 1, 1, 1)
    GameTooltip:AddLine("Spell ID: "..tostring(tooltipSpellID), 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return f
end

local iconFrames = {}

local function EnsureIconFrames(count)
  for i = #iconFrames + 1, count do
    iconFrames[i] = CreateIconFrame("SAO_ProcIcon"..tostring(i))
  end
end

function GetCurrentClassSpecKey()
  local _, classFile = UnitClass("player")
  if not classFile then return nil end
  local spec = GetSpecialization and GetSpecialization()
  local specID = spec and GetSpecializationInfo and GetSpecializationInfo(spec) or nil
  if specID then
    return classFile..":"..tostring(specID)
  end
  return classFile..":0"
end

local function ResetActive()
  wipe(activeByTrigger)
  wipe(activeDisplayRefCount)
end

local function ApplyLayout()
  local p = db()
  EnsureIconFrames(p.maxIcons)
  local point = p.point or "CENTER"

  container:ClearAllPoints()
  container:SetPoint(point, UIParent, point, p.x, p.y)

  local size = p.size
  local gap = p.gap
  local maxIcons = p.maxIcons
  local borderSize = math.max(1, math.floor(size * 0.04 + 0.5))

  container:SetSize(size * maxIcons + gap * (maxIcons - 1), size)
  for i = 1, maxIcons do
    local icon = iconFrames[i]
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    if i == 1 then
      icon:SetPoint("LEFT", container, "LEFT", 0, 0)
    else
      icon:SetPoint("LEFT", iconFrames[i-1], "RIGHT", gap, 0)
    end

    icon.borderTop:ClearAllPoints()
    icon.borderTop:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    icon.borderTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
    icon.borderTop:SetHeight(borderSize)

    icon.borderBottom:ClearAllPoints()
    icon.borderBottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
    icon.borderBottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    icon.borderBottom:SetHeight(borderSize)

    icon.borderLeft:ClearAllPoints()
    icon.borderLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, -borderSize)
    icon.borderLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, borderSize)
    icon.borderLeft:SetWidth(borderSize)

    icon.borderRight:ClearAllPoints()
    icon.borderRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, -borderSize)
    icon.borderRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, borderSize)
    icon.borderRight:SetWidth(borderSize)

    icon.fallbackGlow:ClearAllPoints()
    icon.fallbackGlow:SetPoint("CENTER", icon, "CENTER")
    icon.fallbackGlow:SetSize(size * GLOW_SCALE, size * GLOW_SCALE)

    local hasLBG = LBG and type(LBG.ShowOverlayGlow) == "function" and type(LBG.HideOverlayGlow) == "function"
    if hasLBG and icon.__saoProcGlowShown then
      LBG.HideOverlayGlow(icon)
      LBG.ShowOverlayGlow(icon)
    end
    if icon.__saoProcFallbackGlowShown then
      icon.fallbackGlowAnim:Stop()
      icon.fallbackGlow:Hide()
      icon.fallbackGlow:Show()
      icon.fallbackGlowAnim:Play()
    end
  end
end

local function SetIconSecureAction(iconFrame, spellID)
  if type(iconFrame.SetAttribute) ~= "function" then return true end
  if InCombatLockdown and InCombatLockdown() then
    pendingSecureAttributeRefresh = true
    return false
  end

  if type(spellID) == "number" then
    local spellName = GetSpellInfo and GetSpellInfo(spellID) or nil
    iconFrame:SetAttribute("type", "spell")
    iconFrame:SetAttribute("spell", spellName or spellID)
  else
    iconFrame:SetAttribute("type", nil)
    iconFrame:SetAttribute("spell", nil)
  end
  return true
end

local function SetFallbackGlow(iconFrame, shouldGlow)
  if shouldGlow then
    if not iconFrame.__saoProcFallbackGlowShown then
      iconFrame.fallbackGlow:Show()
      iconFrame.fallbackGlowAnim:Play()
      iconFrame.__saoProcFallbackGlowShown = true
    end
  elseif iconFrame.__saoProcFallbackGlowShown then
    iconFrame.fallbackGlowAnim:Stop()
    iconFrame.fallbackGlow:Hide()
    iconFrame.__saoProcFallbackGlowShown = nil
  end
end

local function SetIcon(iconFrame, spellID, isPlaceholder)
  if not spellID and not isPlaceholder then
    iconFrame:Hide()
    iconFrame.displaySpellID = nil
    iconFrame.spellID = nil
    SetIconSecureAction(iconFrame, nil)
    iconFrame.icon:SetTexture(nil)
    iconFrame.icon:Hide()
    iconFrame.fill:Hide()
    return
  end

  local tex = spellID and GetSpellTextureCompat(spellID) or nil
  local showPlaceholder = isPlaceholder or not tex

  iconFrame.icon:SetShown(not showPlaceholder)
  iconFrame.fill:SetShown(showPlaceholder)
  if showPlaceholder then
    iconFrame.icon:SetTexture(nil)
    iconFrame.icon:SetVertexColor(1, 1, 1, 1)
    iconFrame.fill:SetColorTexture(0, 0, 0, PLACEHOLDER_ALPHA)
    iconFrame.fill:SetVertexColor(1, 1, 1, 1)
    iconFrame.displaySpellID = nil
    iconFrame.spellID = nil
    SetIconSecureAction(iconFrame, nil)
  else
    iconFrame.icon:SetTexture(tex)
    iconFrame.icon:SetVertexColor(1, 1, 1, 1)
    iconFrame.displaySpellID = spellID
    iconFrame.spellID = spellID
    SetIconSecureAction(iconFrame, spellID)
  end
  iconFrame:Show()
end

local function SetIconGlow(iconFrame, shouldGlow)
  local hasLBG = LBG and type(LBG.ShowOverlayGlow) == "function" and type(LBG.HideOverlayGlow) == "function"

  if hasLBG then
    if shouldGlow then
      if not iconFrame.__saoProcGlowShown then
        LBG.ShowOverlayGlow(iconFrame)
        iconFrame.__saoProcGlowShown = true
      end
    elseif iconFrame.__saoProcGlowShown then
      LBG.HideOverlayGlow(iconFrame)
      iconFrame.__saoProcGlowShown = nil
    end
  end

  SetFallbackGlow(iconFrame, shouldGlow and not iconFrame.__saoProcGlowShown)
end

local function Refresh()
  local p = db()
  ApplyLayout()
  if not p.enabled then
    for i = 1, #iconFrames do
      SetIconGlow(iconFrames[i], false)
      iconFrames[i]:Hide()
    end
    if pendingSecureAttributeRefresh and (not InCombatLockdown or not InCombatLockdown()) then
      local refreshed = true
      for i = 1, #iconFrames do
        if not SetIconSecureAction(iconFrames[i], nil) then
          refreshed = false
        end
      end
      if refreshed then
        pendingSecureAttributeRefresh = false
      end
    end
    container:Hide()
    return
  end

  local orderKey = GetCurrentClassSpecKey()
  local order = orderKey and p.order and p.order[orderKey] or nil
  local hasFixedOrder = type(order) == "table" and #order > 0
  local activeSpellIDs = {}
  for spellID, count in pairs(activeDisplayRefCount) do
    if count and count > 0 then
      table.insert(activeSpellIDs, spellID)
    end
  end
  table.sort(activeSpellIDs)
  local hasVisibleIcon = false
  if p.testMode then
    local usedSpellIDs = {}
    local activeIndex = 1

    for i = 1, p.maxIcons do
      local spellID = hasFixedOrder and order[i] or nil
      if spellID then
        usedSpellIDs[spellID] = true
      else
        while activeSpellIDs[activeIndex] and usedSpellIDs[activeSpellIDs[activeIndex]] do
          activeIndex = activeIndex + 1
        end
        spellID = activeSpellIDs[activeIndex]
        if spellID then
          usedSpellIDs[spellID] = true
          activeIndex = activeIndex + 1
        end
      end

      if spellID then
        SetIcon(iconFrames[i], spellID)
        SetIconGlow(iconFrames[i], true)
        hasVisibleIcon = true
      else
        SetIcon(iconFrames[i], nil, true)
        SetIconGlow(iconFrames[i], true)
        hasVisibleIcon = true
      end
    end
  elseif hasFixedOrder then
    for i = 1, p.maxIcons do
      local spellID = order[i]
      if spellID and (activeDisplayRefCount[spellID] or 0) > 0 then
        SetIcon(iconFrames[i], spellID)
        SetIconGlow(iconFrames[i], true)
        hasVisibleIcon = true
      else
        SetIconGlow(iconFrames[i], false)
        SetIcon(iconFrames[i], nil)
      end
    end
  else
    for i = 1, p.maxIcons do
      local spellID = activeSpellIDs[i]
      if spellID then
        SetIcon(iconFrames[i], spellID)
        SetIconGlow(iconFrames[i], true)
        hasVisibleIcon = true
      else
        SetIconGlow(iconFrames[i], false)
        SetIcon(iconFrames[i], nil)
      end
    end
  end
  for i = p.maxIcons + 1, #iconFrames do
    SetIconGlow(iconFrames[i], false)
    iconFrames[i]:Hide()
  end

  if pendingSecureAttributeRefresh and (not InCombatLockdown or not InCombatLockdown()) then
    local refreshed = true
    for i = 1, #iconFrames do
      local icon = iconFrames[i]
      local secureSpellID = icon:IsShown() and icon.spellID or nil
      if not SetIconSecureAction(icon, secureSpellID) then
        refreshed = false
      end
    end
    if refreshed then
      pendingSecureAttributeRefresh = false
    end
  end

  container:SetShown(hasVisibleIcon or p.testMode)
end

function SAO:ProcIcons_Activate(spellID)
  if type(spellID) ~= "number" then return end
  local displaySpellID = ResolveDisplaySpellID(spellID)
  if type(displaySpellID) ~= "number" then return end
  local previousDisplaySpellID = activeByTrigger[spellID]
  if previousDisplaySpellID == displaySpellID then
    Refresh()
    return
  end
  if type(previousDisplaySpellID) == "number" then
    local previousCount = (activeDisplayRefCount[previousDisplaySpellID] or 0) - 1
    if previousCount > 0 then
      activeDisplayRefCount[previousDisplaySpellID] = previousCount
    else
      activeDisplayRefCount[previousDisplaySpellID] = nil
    end
  end
  activeByTrigger[spellID] = displaySpellID
  activeDisplayRefCount[displaySpellID] = (activeDisplayRefCount[displaySpellID] or 0) + 1
  Refresh()
end

function SAO:ProcIcons_Deactivate(spellID)
  if type(spellID) ~= "number" then return end
  local displaySpellID = activeByTrigger[spellID] or ResolveDisplaySpellID(spellID)
  activeByTrigger[spellID] = nil
  if type(displaySpellID) == "number" then
    local count = (activeDisplayRefCount[displaySpellID] or 0) - 1
    if count > 0 then
      activeDisplayRefCount[displaySpellID] = count
    else
      activeDisplayRefCount[displaySpellID] = nil
    end
  end
  Refresh()
end

function SAO:ProcIcons_SetTestMode(on)
  local p = db()
  p.testMode = on == true
  Refresh()
  return p.testMode
end

function SAO:ProcIcons_ToggleTestMode()
  return self:ProcIcons_SetTestMode(not db().testMode)
end

function SAO:ProcIcons_ApplyLayoutAndRefresh()
  ApplyLayout()
  Refresh()
end

local ev = CreateFrame("Frame")
local sawGlowEvents = false
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
--ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
--ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")
--ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
--ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
    if event ~= "PLAYER_LOGIN" then
      ResetActive()
	  ev.__saoGlowShowSeen = false
	  ev.__saoGlowHideSeen = false
      sawGlowEvents = false
    end
    ApplyLayout()
    Refresh()
    return
  end
  if event == "PLAYER_REGEN_DISABLED" then
    for i = 1, #iconFrames do
      iconFrames[i]:RegisterForClicks()
    end
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    for i = 1, #iconFrames do
      iconFrames[i]:RegisterForClicks("LeftButtonUp")
    end
    if pendingSecureAttributeRefresh then
      Refresh()
    end
    return
  end

  local spellID = ...
  if type(spellID) ~= "number" then return end

  -- Prefer glow lifecycle only once we have evidence it's complete/reliable.
  -- Some servers emit a stray *_GLOW_* event, then mostly use SHOW/HIDE.
  -- If we lock onto glow too early, we stop seeing real procs.
  local isGlowShow = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  local isGlowHide = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  local isGlowEvent = isGlowShow or isGlowHide

  -- Persist across events
  ev.__saoGlowShowSeen = ev.__saoGlowShowSeen or false
  ev.__saoGlowHideSeen = ev.__saoGlowHideSeen or false

  if isGlowShow then
    ev.__saoGlowShowSeen = true
  elseif isGlowHide then
    ev.__saoGlowHideSeen = true
  end

  local trustGlow = ev.__saoGlowShowSeen and ev.__saoGlowHideSeen

  -- Only ignore SHOW/HIDE once we've seen BOTH glow show + glow hide at least once
  if (not isGlowEvent) and trustGlow then
    return
  end

  if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    SAO:ProcIcons_Activate(spellID)
  elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    SAO:ProcIcons_Deactivate(spellID)
  end
end)
