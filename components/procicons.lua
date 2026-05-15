local AddonName, SAO = ...
local Module = "procicons"

-- Minimal, universal "Blizzard-like" proc icon display.
-- Shows up to 2 large icons based on SPELL_ACTIVATION_OVERLAY_SHOW/HIDE.

local function db()
  SpellActivationOverlayDB = SpellActivationOverlayDB or {}
  SpellActivationOverlayDB.procIcons = SpellActivationOverlayDB.procIcons or {}
  local p = SpellActivationOverlayDB.procIcons

  if p.enabled == nil then p.enabled = true end
  if p.locked == nil then p.locked = true end
  if p.size == nil then p.size = 80 end
  if p.point == nil then p.point, p.x, p.y = "CENTER", 0, -80 end
  if p.gap == nil then p.gap = 10 end

  return p
end

local active = {}     -- [spellID] = true
local order = {}      -- array of spellIDs, most-recent-last

local function tremoveValue(t, v)
  for i = #t, 1, -1 do
    if t[i] == v then
      table.remove(t, i)
    end
  end
end

local function touchOrder(spellID)
  tremoveValue(order, spellID)
  table.insert(order, spellID)
end

local function getMostRecentActive()
  for i = #order, 1, -1 do
    local id = order[i]
    if active[id] then
      return id
    end
  end
end

local function getSecondMostRecentActive(exclude)
  for i = #order, 1, -1 do
    local id = order[i]
    if id ~= exclude and active[id] then
      return id
    end
  end
end

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

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetAllPoints(true)
  f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.border = f:CreateTexture(nil, "OVERLAY")
  f.border:SetAllPoints(true)
  f.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

  return f
end

local icon1 = CreateIconFrame("SAO_ProcIcon1")
local icon2 = CreateIconFrame("SAO_ProcIcon2")

local function ApplyLayout()
  local p = db()

  container:ClearAllPoints()
  container:SetPoint(p.point, UIParent, p.point, p.x, p.y)

  local size = p.size
  local gap = p.gap

  container:SetSize(size * 2 + gap, size)

  icon1:SetSize(size, size)
  icon2:SetSize(size, size)

  icon1:ClearAllPoints()
  icon2:ClearAllPoints()

  icon1:SetPoint("LEFT", container, "LEFT", 0, 0)
  icon2:SetPoint("LEFT", icon1, "RIGHT", gap, 0)
end

local function SetIcon(iconFrame, spellID)
  if not spellID then
    iconFrame:Hide()
    iconFrame.spellID = nil
    return
  end

  local tex = GetSpellTexture(spellID)
  iconFrame.icon:SetTexture(tex)
  iconFrame.spellID = spellID
  iconFrame:Show()
end

local function Refresh()
  local p = db()
  if not p.enabled then
    container:Hide()
    return
  end

  local s1 = getMostRecentActive()
  local s2 = getSecondMostRecentActive(s1)

  SetIcon(icon1, s1)
  SetIcon(icon2, s2)

  if s1 or s2 then
    container:Show()
  else
    container:Hide()
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")

-- Some clients use the *_GLOW_* variants; registering them doesn't hurt.
pcall(function() ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") end)
pcall(function() ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE") end)

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    ApplyLayout()
    Refresh()
    return
  end

  local spellID = ...
  if type(spellID) ~= "number" then return end

  if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    active[spellID] = true
    touchOrder(spellID)
  elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    active[spellID] = nil
  end

  Refresh()
end)