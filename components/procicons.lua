local AddonName, SAO = ...
local Module = "procicons"
local LBG = LibStub and LibStub("LibButtonGlow-1.0", true)

-- Minimal, universal "Blizzard-like" proc icon display.
-- Shows fixed-order icons for active proc overlays.

local DefaultOrderBySpec = {
  ["WARRIOR:72"] = {190411, 5308, 184367},
}

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

local active = {}     -- [spellID] = true
local function ResolveDisplaySpellID(triggerSpellID)
  return (type(GlowTrackerDB)=="table" and type(GlowTrackerDB.alias)=="table" and GlowTrackerDB.alias[triggerSpellID]) or triggerSpellID
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

local container = CreateFrame("Frame", "SAO_ProcIconsContainer", UIParent)
container:SetClampedToScreen(true)
container:SetMovable(true)
container:EnableMouse(true)
container:RegisterForDrag("LeftButton")
container:SetScript("OnDragStart", function(self)
  local p = db()
  if not p.locked then self:StartMoving() end
end)
container:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p = db()
  local point, _, _, x, y = self:GetPoint(1)
  p.point, p.x, p.y = point, x, y
end)

local function CreateIconFrame(name)
  local f = CreateFrame("Frame", name, container)
  f:Hide()

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

  return f
end

local iconFrames = {}

local function EnsureIconFrames(count)
  for i = #iconFrames + 1, count do
    iconFrames[i] = CreateIconFrame("SAO_ProcIcon"..tostring(i))
  end
end

local function GetCurrentClassSpecKey()
  local _, classFile = UnitClass("player")
  if not classFile then return nil end
  local spec = GetSpecialization and GetSpecialization()
  local specID = spec and GetSpecializationInfo and GetSpecializationInfo(spec) or nil
  if specID then
    return classFile..":"..tostring(specID)
  end
  return classFile..":0"
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
    icon.fallbackGlow:SetSize(size * 1.75, size * 1.75)
  end
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
    iconFrame.spellID = nil
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
    iconFrame.spellID = nil
  else
    iconFrame.icon:SetTexture(tex)
    iconFrame.icon:SetVertexColor(1, 1, 1, 1)
    iconFrame.spellID = spellID
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
    container:Hide()
    return
  end

  local orderKey = GetCurrentClassSpecKey()
  local order = orderKey and p.order and p.order[orderKey] or nil
  local hasFixedOrder = type(order) == "table" and #order > 0
  local activeSpellIDs = {}
  for spellID in pairs(active) do
    table.insert(activeSpellIDs, spellID)
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
      if spellID and active[spellID] then
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

  container:SetShown(hasVisibleIcon or p.testMode)
end

function SAO:ProcIcons_Activate(spellID)
  if type(spellID) ~= "number" then return end
  active[ResolveDisplaySpellID(spellID)] = true
  Refresh()
end

function SAO:ProcIcons_Deactivate(spellID)
  if type(spellID) ~= "number" then return end
  active[ResolveDisplaySpellID(spellID)] = nil
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
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
    ApplyLayout()
    Refresh()
    return
  end

  local spellID = ...
  if type(spellID) ~= "number" then return end

  if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    SAO:ProcIcons_Activate(spellID)
  elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    SAO:ProcIcons_Deactivate(spellID)
  end
end)
