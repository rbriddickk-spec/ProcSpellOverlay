local AddonName,SAO=...
local iamNecrosis=strlower(AddonName):sub(0,8)=="necrosis"
local GetAddOnMetadata=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local function SetSliderText(slider, text)
  if not slider then return end
  text = tostring(text or "")

  if slider.Text and slider.Text.SetText then
    slider.Text:SetText(text)
    return
  end
  if slider.text and slider.text.SetText then
    slider.text:SetText(text)
    return
  end

  -- Older templates: <SliderName>Text is a global FontString
  local name = slider.GetName and slider:GetName()
  local fs = name and _G[name .. "Text"]
  if fs and fs.SetText then
    fs:SetText(text)
    return
  end

  -- Last resort: if the slider itself is a FontString-like object
  if slider.SetText then
    slider:SetText(text)
  end
end
function ProcSpellOverlayOptionsPanel_Init(self)
local shutdownCategory=SAO.Shutdown:GetCategory()
if shutdownCategory then
if shutdownCategory.Reason then
local globalOffReason=ProcSpellOverlayOptionsPanel.globalOff.reason
globalOffReason:SetText("("..shutdownCategory.Reason..")")
end
if shutdownCategory.Button then
local globalOffButton=ProcSpellOverlayOptionsPanel.globalOff.button
globalOffButton:SetText(shutdownCategory.Button.Text)
local estimatedWidth=(2+strlenutf8(shutdownCategory.Button.Text))*8
globalOffButton:SetWidth(estimatedWidth)
if estimatedWidth > 48 then
globalOffButton:SetHeight(globalOffButton:GetHeight()+ceil((estimatedWidth-32)/16))
end
globalOffButton:SetScript("OnClick",shutdownCategory.Button.OnClick)
globalOffButton:Show()
end
if shutdownCategory.DisableCondition then
local disableCondition=SAO.Shutdown:GetCategory().DisableCondition
local disableConditionButton=ProcSpellOverlayOptionsPanelDisableConditionButton
disableConditionButton.Text:SetText(disableCondition.Text)
disableConditionButton.OnValueChanged=function(self,checked)
if checked then
disableCondition.OnValueChanged(self,true)
ProcSpellOverlayOptionsPanel.globalOff:Show()
local testButton=ProcSpellOverlayOptionsPanelSpellAlertTestButton
if testButton.isTesting then
testButton:StopTest()
end
else
disableCondition.OnValueChanged(self,false)
ProcSpellOverlayOptionsPanel.globalOff:Hide()
end
end
disableConditionButton:SetChecked(SAO.Shutdown:IsAddonDisabled())
disableConditionButton:OnValueChanged(disableConditionButton:GetChecked())
if disableCondition.ShowIf==nil or disableCondition.ShowIf()then
disableConditionButton:Show()
end
else
ProcSpellOverlayOptionsPanel.globalOff:Show()
end
end
local mustDisableGlowForEveryone=false
if not shutdownCategory and mustDisableGlowForEveryone then
ProcSpellOverlayOptionsPanel.glowOff:Show()
else
ProcSpellOverlayOptionsPanel.glowOff:Hide()
end
local buildInfoLabel=ProcSpellOverlayOptionsPanelBuildInfo
local xSaoBuild=GetAddOnMetadata(AddonName, "X-SAO-Build")
if type(xSaoBuild)=='string' and #xSaoBuild > 0 then
local titleText=GetAddOnMetadata(AddonName, "Title")
if xSaoBuild=="universal" then
local universalText=SAO:gradientText(
SAO:universalBuild(),
{
{r=0.1,g=1,b=0.3},
{r=1,g=1,b=0.5},
{r=0.9,g=0.1,b=0},
{r=0.7,g=0,b=0.8},
{r=0,g=0.3,b=1},
}
)
buildInfoLabel:SetText(titleText.."\n"..universalText)
elseif xSaoBuild=="dev" then
local buildForDevs=SAO:gradientText(
"Build for Developers",
{
{r=0,g=0.3,b=1},
{r=1,g=1,b=1},
{r=0,g=0.3,b=1},
}
)
buildInfoLabel:SetText(titleText.."\n"..buildForDevs)
else
local addonBuild=SAO.GetFullProjectName(xSaoBuild)
local expectedBuild=SAO.GetFullProjectName(SAO.GetExpectedBuildID())
if addonBuild~=expectedBuild then
titleText=WrapTextInColorCode(titleText, "ffff0000")
addonBuild=WrapTextInColorCode(addonBuild, "ffff0000")
expectedBuild=WrapTextInColorCode(expectedBuild, "ffff0000")
buildInfoLabel:SetFontObject(GameFontNormalLarge)
SAO:Info("",SAO:compatibilityWarning(addonBuild,expectedBuild))
end
local optimizedForText
if xSaoBuild=="vanilla" then
if addonBuild==expectedBuild then
optimizedForText=SAO:optimizedFor(BNET_FRIEND_TOOLTIP_WOW_CLASSIC)
else
optimizedForText=SAO:optimizedFor(WrapTextInColorCode(BNET_FRIEND_TOOLTIP_WOW_CLASSIC, "ffff0000"))
end
else
local fmt = type(BNET_FRIEND_ZONE_WOW_CLASSIC)=="string" and BNET_FRIEND_ZONE_WOW_CLASSIC or "%s"
optimizedForText = SAO:optimizedFor(string.format(fmt, addonBuild))
end
local subProjectName=SAO.GetSubProjectName(xSaoBuild)
if subProjectName then
optimizedForText=optimizedForText .. " (" .. subProjectName .. ")"
end
buildInfoLabel:SetText(titleText.."\n"..optimizedForText)
end
end
local classInfoLabel=ProcSpellOverlayOptionsPanelClassInfo
if SAO.CurrentClass then
local className,classFile,classId=SAO.CurrentClass.Intrinsics[1],SAO.CurrentClass.Intrinsics[2],SAO.CurrentClass.Intrinsics[3]
local gradientColors
if classFile=="PRIEST" then
gradientColors={
{r=0.8,g=0.8,b=0.8},
RAID_CLASS_COLORS[classFile],
{r=0.9,g=0.9,b=0.9},
{r=0.7,g=0.7,b=0.7},
}
else
local function mixColors(color1,color2,t)
return {
r=color1.r * (1 - t) + color2.r * t,
g=color1.g * (1 - t) + color2.g * t,
b=color1.b * (1 - t) + color2.b * t,
}
end
local classColor=RAID_CLASS_COLORS[classFile]
gradientColors={
classColor,
mixColors(classColor,{r=1,g=1,b=1},0.25),
classColor,
mixColors(classColor,{r=0,g=0,b=0},0.15),
}
end
local classIcons={
["DEATHKNIGHT"]="Interface/Icons/Spell_Deathknight_ClassIcon",
["DRUID"]="Interface/Icons/ClassIcon_Druid",
["HUNTER"]="Interface/Icons/ClassIcon_Hunter",
["MAGE"]="Interface/Icons/ClassIcon_Mage",
["MONK"]="Interface/Icons/ClassIcon_Monk",
["PALADIN"]="Interface/Icons/ClassIcon_Paladin",
["PRIEST"]="Interface/Icons/ClassIcon_Priest",
["ROGUE"]="Interface/Icons/ClassIcon_Rogue",
["SHAMAN"]="Interface/Icons/ClassIcon_Shaman",
["WARLOCK"]="Interface/Icons/ClassIcon_Warlock",
["WARRIOR"]="Interface/Icons/ClassIcon_Warrior",
}
local classIcon=classIcons[classFile] or "Interface/Icons/INV_Misc_QuestionMark"
local classText=SAO:gradientText(className,gradientColors)
classInfoLabel:SetText(string.format("|T%s:16:16:0:0:512:512:32:480:32:480|t %s",classIcon,classText))
else
classInfoLabel:SetText("")
end
local opacitySlider=ProcSpellOverlayOptionsPanelSpellAlertOpacitySlider
SetSliderText(opacitySlider, SPELL_ALERT_OPACITY)
_G[opacitySlider:GetName().."Low"]:SetText(OFF)
opacitySlider:SetMinMaxValues(0,1)
opacitySlider:SetValueStep(0.05)
opacitySlider.initialValue=ProcSpellOverlayDB.alert.opacity
opacitySlider:SetValue(opacitySlider.initialValue)
opacitySlider.ApplyValueToEngine=function(self,value)
ProcSpellOverlayDB.alert.opacity=value
ProcSpellOverlayDB.alert.enabled=value > 0
SAO:ApplySpellAlertOpacity()
end
local scaleSlider=ProcSpellOverlayOptionsPanelSpellAlertScaleSlider
SetSliderText(scaleSlider, "Spell Alert Scale")
_G[scaleSlider:GetName().."Low"]:SetText(SMALL)
_G[scaleSlider:GetName().."High"]:SetText(LARGE)
scaleSlider:SetMinMaxValues(0.25,2.5)
scaleSlider:SetValueStep(0.05)
scaleSlider.initialValue=ProcSpellOverlayDB.alert.scale
scaleSlider:SetValue(scaleSlider.initialValue)
scaleSlider.ApplyValueToEngine=function(self,value)
ProcSpellOverlayDB.alert.scale=value
SAO:ApplySpellAlertGeometry()
end
local offsetSlider=ProcSpellOverlayOptionsPanelSpellAlertOffsetSlider
SetSliderText(offsetSlider, "Spell Alert Offset")
_G[offsetSlider:GetName().."Low"]:SetText(NEAR)
_G[offsetSlider:GetName().."High"]:SetText(FAR)
offsetSlider:SetMinMaxValues(-200,400)
offsetSlider:SetValueStep(20)
offsetSlider.initialValue=ProcSpellOverlayDB.alert.offset
offsetSlider:SetValue(offsetSlider.initialValue)
offsetSlider.ApplyValueToEngine=function(self,value)
ProcSpellOverlayDB.alert.offset=value
SAO:ApplySpellAlertGeometry()
end
local timerSlider=ProcSpellOverlayOptionsPanelSpellAlertTimerSlider
SetSliderText(timerSlider, "Spell Alert Progressive Timer")
_G[timerSlider:GetName().."Low"]:SetText(DISABLE)
_G[timerSlider:GetName().."High"]:SetText(ENABLE)
timerSlider:SetMinMaxValues(0,1)
timerSlider:SetValueStep(1)
timerSlider.initialValue=ProcSpellOverlayDB.alert.timer
timerSlider:SetValue(timerSlider.initialValue)
timerSlider.ApplyValueToEngine=function(self,value)
ProcSpellOverlayDB.alert.timer=value
SAO:ApplySpellAlertTimer()
end
local soundSlider=ProcSpellOverlayOptionsPanelSpellAlertSoundSlider
SetSliderText(soundSlider, "Spell Alert Sound Effect")
_G[soundSlider:GetName().."Low"]:SetText(DISABLE)
_G[soundSlider:GetName().."High"]:SetText(ENABLE)
soundSlider:SetMinMaxValues(0,1)
soundSlider:SetValueStep(1)
soundSlider.initialValue=ProcSpellOverlayDB.alert.sound
soundSlider:SetValue(soundSlider.initialValue)
soundSlider.ApplyValueToEngine=function(self,value)
ProcSpellOverlayDB.alert.sound=value
SAO:ApplySpellAlertSound()
end
local testButton=ProcSpellOverlayOptionsPanelSpellAlertTestButton
testButton:SetText("Toggle Test")
testButton.fakeSpellID=42
testButton.isTesting=false
local testTextureLeftRight=SAO.IsEra() and "echo_of_the_elements" or "imp_empowerment"
local testTextureTop=SAO.IsEra() and "fury_of_stormrage" or "brain_freeze"
local testPositionTop=SAO.IsCata() and "Top (CW)" or "Top"
testButton.StartTest=function(self)
if (not self.isTesting)then
self.isTesting=true
SAO:ActivateOverlay(0,self.fakeSpellID,SAO.TexName[testTextureLeftRight], "Left + Right (Flipped)",1,255,255,255,false,nil,GetTime()+5,false,{strata="DIALOG",level=9999})
SAO:ActivateOverlay(0,self.fakeSpellID,SAO.TexName[testTextureTop] ,testPositionTop ,1,255,255,255,false,nil,GetTime()+5,false,{strata="DIALOG",level=9999})
self.testTimerTicker=C_Timer.NewTicker(4.9,
function()
SAO:RefreshOverlayTimer(self.fakeSpellID,GetTime()+5)
end)
ProcSpellOverlayFrame_SetForceAlpha1(true)
end
end
testButton.StopTest=function(self)
if (self.isTesting)then
self.isTesting=false
self.testTimerTicker:Cancel()
SAO:DeactivateOverlay(self.fakeSpellID)
ProcSpellOverlayFrame_SetForceAlpha1(false)
end
end
testButton:SetEnabled(ProcSpellOverlayDB.alert.enabled)
SAO:MarkTexture(testTextureLeftRight)
SAO:MarkTexture(testTextureTop)
local debugButton=ProcSpellOverlayOptionsPanelSpellAlertDebugButton
debugButton.Text:SetText(SAO:optionDebugToChatbox())
debugButton:SetChecked(ProcSpellOverlayDB.debug==true)
local reportButton=ProcSpellOverlayOptionsPanelSpellAlertReportButton
if SAO:CanReport()then
reportButton.Text:SetText(SAO:reportUnsupportedOverlays())
reportButton:SetChecked(ProcSpellOverlayDB.report~=false)
else
reportButton:Hide()
end
local responsiveButton=ProcSpellOverlayOptionsPanelSpellAlertResponsiveButton
responsiveButton.Text:SetText(SAO:responsiveMode())
responsiveButton:SetChecked(ProcSpellOverlayDB.responsiveMode==true)
local askDisableGameAlertButton=ProcSpellOverlayOptionsPanelSpellAlertAskDisableGameAlertButton
if SAO:IsQuestionPossible(SAO.QUESTIONS.DISABLE_GAME_ALERT)then
askDisableGameAlertButton:Show()
askDisableGameAlertButton.Text:SetText(SAO:askToDisableGameAlerts())
askDisableGameAlertButton:SetChecked(not ProcSpellOverlayDB.questions or ProcSpellOverlayDB.questions.disableGameAlert~="no")
askDisableGameAlertButton.OnValueChanged=function(self,checked)
ProcSpellOverlayDB.questions=ProcSpellOverlayDB.questions or {}
if checked then
ProcSpellOverlayDB.questions.disableGameAlert=nil
SAO:AskQuestion(SAO.QUESTIONS.DISABLE_GAME_ALERT)
else
ProcSpellOverlayDB.questions.disableGameAlert="no"
SAO:CancelQuestion(SAO.QUESTIONS.DISABLE_GAME_ALERT)
end
end
else
askDisableGameAlertButton:Hide()
local anchorBuildInfo={ProcSpellOverlayOptionsPanelBuildInfo:GetPoint(1)}
ProcSpellOverlayOptionsPanelBuildInfo:SetPoint(anchorBuildInfo[1],anchorBuildInfo[2],anchorBuildInfo[3],anchorBuildInfo[4],anchorBuildInfo[5] - 24)
end
local glowingButtonCheckbox=ProcSpellOverlayOptionsPanelGlowingButtons
glowingButtonCheckbox.Text:SetText("Glowing Buttons")
glowingButtonCheckbox.initialValue=ProcSpellOverlayDB.glow.enabled
glowingButtonCheckbox:SetChecked(glowingButtonCheckbox.initialValue)
glowingButtonCheckbox.ApplyValueToEngine=function(self,checked)
ProcSpellOverlayDB.glow.enabled=checked
for _,checkbox in ipairs(ProcSpellOverlayOptionsPanel.additionalCheckboxes.glow or {})do
checkbox:ApplyParentEnabling()
end
SAO:ApplyGlowingButtonsToggle()
end
local classOptions=ProcSpellOverlayDB.classes and SAO.CurrentClass and ProcSpellOverlayDB.classes[SAO.CurrentClass.Intrinsics[2]]
if (classOptions)then
ProcSpellOverlayOptionsPanel.classOptions={initialValue=CopyTable(classOptions)}
else
ProcSpellOverlayOptionsPanel.classOptions={initialValue={}}
end
ProcSpellOverlayOptionsPanel.additionalCheckboxes={}
end
local function okayFunc(self)
local opacitySlider=ProcSpellOverlayOptionsPanelSpellAlertOpacitySlider
opacitySlider.initialValue=opacitySlider:GetValue()
local scaleSlider=ProcSpellOverlayOptionsPanelSpellAlertScaleSlider
scaleSlider.initialValue=scaleSlider:GetValue()
local offsetSlider=ProcSpellOverlayOptionsPanelSpellAlertOffsetSlider
offsetSlider.initialValue=offsetSlider:GetValue()
local timerSlider=ProcSpellOverlayOptionsPanelSpellAlertTimerSlider
timerSlider.initialValue=timerSlider:GetValue()
local soundSlider=ProcSpellOverlayOptionsPanelSpellAlertSoundSlider
soundSlider.initialValue=soundSlider:GetValue()
local glowingButtonCheckbox=ProcSpellOverlayOptionsPanelGlowingButtons
glowingButtonCheckbox.initialValue=glowingButtonCheckbox:GetChecked()
local classOptions=ProcSpellOverlayDB.classes and SAO.CurrentClass and ProcSpellOverlayDB.classes[SAO.CurrentClass.Intrinsics[2]]
if (classOptions)then
ProcSpellOverlayOptionsPanel.classOptions.initialValue=CopyTable(classOptions)
end
end
local function cancelFunc(self)
local opacitySlider=ProcSpellOverlayOptionsPanelSpellAlertOpacitySlider
local scaleSlider=ProcSpellOverlayOptionsPanelSpellAlertScaleSlider
local offsetSlider=ProcSpellOverlayOptionsPanelSpellAlertOffsetSlider
local timerSlider=ProcSpellOverlayOptionsPanelSpellAlertTimerSlider
local soundSlider=ProcSpellOverlayOptionsPanelSpellAlertSoundSlider
local glowingButtonCheckbox=ProcSpellOverlayOptionsPanelGlowingButtons
local classOptions=ProcSpellOverlayOptionsPanel.classOptions
self:applyAll(
opacitySlider.initialValue,
scaleSlider.initialValue,
offsetSlider.initialValue,
timerSlider.initialValue,
soundSlider.initialValue,
glowingButtonCheckbox.initialValue,
classOptions.initialValue
)
end
local function defaultFunc(self)
local defaultClassOptions=SAO.defaults.classes and SAO.CurrentClass and SAO.defaults.classes[SAO.CurrentClass.Intrinsics[2]]
self:applyAll(
1,
1,
0,
1,
SAO.IsCata() and 1 or 0,
true,
defaultClassOptions
)
end
local function applyAllFunc(self,opacityValue,scaleValue,offsetValue,timerValue,soundValue,isGlowEnabled,classOptions)
local opacitySlider=ProcSpellOverlayOptionsPanelSpellAlertOpacitySlider
opacitySlider:SetValue(opacityValue)
if (ProcSpellOverlayDB.alert.opacity~=opacityValue)then
ProcSpellOverlayDB.alert.opacity=opacityValue
ProcSpellOverlayDB.alert.enabled=opacityValue > 0
SAO:ApplySpellAlertOpacity()
end
local geometryChanged=false
local scaleSlider=ProcSpellOverlayOptionsPanelSpellAlertScaleSlider
scaleSlider:SetValue(scaleValue)
if (ProcSpellOverlayDB.alert.scale~=scaleValue)then
ProcSpellOverlayDB.alert.scale=scaleValue
geometryChanged=true
end
local offsetSlider=ProcSpellOverlayOptionsPanelSpellAlertOffsetSlider
offsetSlider:SetValue(offsetValue)
if (ProcSpellOverlayDB.alert.offset~=offsetValue)then
ProcSpellOverlayDB.alert.offset=offsetValue
geometryChanged=true
end
if (geometryChanged)then
SAO:ApplySpellAlertGeometry()
end
local timerSlider=ProcSpellOverlayOptionsPanelSpellAlertTimerSlider
timerSlider:SetValue(timerValue)
if (ProcSpellOverlayDB.alert.timer~=timerValue)then
ProcSpellOverlayDB.alert.timer=timerValue
SAO:ApplySpellAlertTimer()
end
local soundSlider=ProcSpellOverlayOptionsPanelSpellAlertSoundSlider
soundSlider:SetValue(soundValue)
if (ProcSpellOverlayDB.alert.sound~=soundValue)then
ProcSpellOverlayDB.alert.sound=soundValue
SAO:ApplySpellAlertSound()
end
local testButton=ProcSpellOverlayOptionsPanelSpellAlertTestButton
testButton:SetEnabled(ProcSpellOverlayDB.alert.enabled)
local glowingButtonCheckbox=ProcSpellOverlayOptionsPanelGlowingButtons
glowingButtonCheckbox:SetChecked(isGlowEnabled)
if (ProcSpellOverlayDB.glow.enabled~=isGlowEnabled)then
ProcSpellOverlayDB.glow.enabled=isGlowEnabled
glowingButtonCheckbox:ApplyValueToEngine(isGlowEnabled)
end
if (ProcSpellOverlayDB.classes and SAO.CurrentClass and ProcSpellOverlayDB.classes[SAO.CurrentClass.Intrinsics[2]] and classOptions)then
ProcSpellOverlayDB.classes[SAO.CurrentClass.Intrinsics[2]]=CopyTable(classOptions)
for _,checkbox in ipairs(ProcSpellOverlayOptionsPanel.additionalCheckboxes.alert or {})do
checkbox:ApplyValue()
end
for _,checkbox in ipairs(ProcSpellOverlayOptionsPanel.additionalCheckboxes.glow or {})do
checkbox:ApplyValue()
end
end
end
local InterfaceOptions_AddCategory=InterfaceOptions_AddCategory
local InterfaceOptionsFrame_OpenToCategory=InterfaceOptionsFrame_OpenToCategory
if Settings and Settings.RegisterCanvasLayoutCategory then
InterfaceOptions_AddCategory=function(frame,addOn,position)
frame.OnCommit=frame.okay
frame.OnDefault=frame.default
frame.OnRefresh=frame.refresh
if frame.parent then
local category=Settings.GetCategory(frame.parent)
local subcategory,layout=Settings.RegisterCanvasLayoutSubcategory(category,frame,frame.name,frame.name)
subcategory.ID=frame.name
return subcategory,category
else
local category,layout=Settings.RegisterCanvasLayoutCategory(frame,frame.name,frame.name)
category.ID=frame.name
Settings.RegisterAddOnCategory(category)
return category
end
end
InterfaceOptionsFrame_OpenToCategory=function(categoryIDOrFrame)
if type(categoryIDOrFrame)=="table" then
local categoryID=categoryIDOrFrame.name
return Settings.OpenToCategory(categoryID)
else
return Settings.OpenToCategory(categoryIDOrFrame)
end
end
end
function ProcSpellOverlayOptionsPanel_OnLoad(self)
self.name=AddonName
self.okay=okayFunc
self.cancel=cancelFunc
self.default=defaultFunc
self.applyAll=applyAllFunc
InterfaceOptions_AddCategory(self)
SAO.OptionsPanel=self
end
local optionsLoaded=false
function ProcSpellOverlayOptionsPanel_OnShow(self)
if optionsLoaded then
return
end
for _,classDef in ipairs({SAO.CurrentClass,SAO.SharedClass})do
if classDef and type(classDef.LoadOptions)=='function' then
classDef.LoadOptions(SAO)
end
end
SAO:AddEffectOptions()
for _,optionType in ipairs({"alert", "glow"})do
if (type(ProcSpellOverlayOptionsPanel.additionalCheckboxes[optionType])=="nil")then
local className=SAO.CurrentClass and SAO.CurrentClass.Intrinsics[1] or select(1,UnitClass("player"))
local classFile=SAO.CurrentClass and SAO.CurrentClass.Intrinsics[2] or select(2,UnitClass("player"))
local dimFactor=0.7
local dimmedTextColor=CreateColor(dimFactor,dimFactor,dimFactor)
local dimmedClassColor=CreateColor(dimFactor*RAID_CLASS_COLORS[classFile].r,dimFactor*RAID_CLASS_COLORS[classFile].g,dimFactor*RAID_CLASS_COLORS[classFile].b)
local text=WrapTextInColor(string.format("%s (%s)",NONE,WrapTextInColor(className,dimmedClassColor)),dimmedTextColor)
ProcSpellOverlayOptionsPanel[optionType.."None"]:SetText(text)
end
end
optionsLoaded=true
end
if not iamNecrosis then
SLASH_SAO1="/sao"
SLASH_SAO2="/ProcSpellOverlay"
SlashCmdList.SAO=function(msg,editBox)
InterfaceOptionsFrame_OpenToCategory(SAO.OptionsPanel)
InterfaceOptionsFrame_OpenToCategory(SAO.OptionsPanel)
end
end
