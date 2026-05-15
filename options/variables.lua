local AddonName,SAO=...
function SAO.ApplyAllVariables(self)
self:ApplySpellAlertOpacity()
self:ApplySpellAlertGeometry()
self:ApplySpellAlertTimer()
self:ApplySpellAlertSound()
self:ApplyGlowingButtonsToggle()
end
function SAO.ApplySpellAlertOpacity(self)
ProcSpellOverlayContainerFrame:SetShown(ProcSpellOverlayDB.alert.enabled)
ProcSpellOverlayContainerFrame:SetAlpha(ProcSpellOverlayDB.alert.opacity)
end
function SAO.ApplySpellAlertGeometry(self)
ProcSpellOverlayAddonFrame.scale=ProcSpellOverlayDB.alert.scale
ProcSpellOverlayAddonFrame.offset=ProcSpellOverlayDB.alert.offset
ProcSpellOverlay_OnChangeGeometry(ProcSpellOverlayAddonFrame)
end
function SAO.ApplySpellAlertTimer(self)
ProcSpellOverlayAddonFrame.useTimer=ProcSpellOverlayDB.alert.timer~=0
ProcSpellOverlay_OnChangeTimerVisibility(ProcSpellOverlayAddonFrame)
end
function SAO.ApplySpellAlertSound(self)
ProcSpellOverlayAddonFrame.useSound=ProcSpellOverlayDB.alert.sound~=0
ProcSpellOverlay_OnChangeSoundToggle(ProcSpellOverlayAddonFrame)
end
function SAO.ApplyGlowingButtonsToggle(self)
self:ForEachBucket(function(bucket)
bucket:reset()
bucket.trigger:manualCheckAll()
end)
end
