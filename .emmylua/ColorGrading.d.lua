---@meta

--- Auto-generated from Graphics/ColorGrading

---@class ColorGrading : Component
---@field LUT ColorLUT
---@field lutIntensity number
---@field secondaryLUT ColorLUT
---@field lutBlendFactor number
---@field exposure number
---@field temperature number
---@field tint number
---@field globalSaturation number
---@field globalContrast number
---@field globalGamma number
---@field globalGain number
---@field globalOffset number
---@field shadowsSaturation number
---@field shadowsContrast number
---@field shadowsGamma number
---@field shadowsGain number
---@field shadowsOffset number
---@field shadowsTint Color
---@field shadowsTintIntensity number
---@field midtonesSaturation number
---@field midtonesContrast number
---@field midtonesGamma number
---@field midtonesGain number
---@field midtonesOffset number
---@field midtonesTint Color
---@field midtonesTintIntensity number
---@field highlightsSaturation number
---@field highlightsContrast number
---@field highlightsGamma number
---@field highlightsGain number
---@field highlightsOffset number
---@field highlightsTint Color
---@field highlightsTintIntensity number
---@field shadowsMax number
---@field highlightsMin number
---@field colorGradingEnabled boolean
ColorGrading = {}

---@param lut ColorLUT
---@return nil
function ColorGrading:SetLUT(lut) end

---@return ColorLUT
function ColorGrading:GetLUT() end

---@param intensity number
---@return nil
function ColorGrading:SetLUTIntensity(intensity) end

---@return number
function ColorGrading:GetLUTIntensity() end

---@param lut ColorLUT
---@return nil
function ColorGrading:SetSecondaryLUT(lut) end

---@return ColorLUT
function ColorGrading:GetSecondaryLUT() end

---@param factor number
---@return nil
function ColorGrading:SetLUTBlendFactor(factor) end

---@return number
function ColorGrading:GetLUTBlendFactor() end

---@param target ColorLUT
---@param duration number
---@return nil
function ColorGrading:BlendToLUT(target, duration) end

---@param exposure number
---@return nil
function ColorGrading:SetExposure(exposure) end

---@return number
function ColorGrading:GetExposure() end

---@param temp number
---@return nil
function ColorGrading:SetTemperature(temp) end

---@return number
function ColorGrading:GetTemperature() end

---@param tint number
---@return nil
function ColorGrading:SetTint(tint) end

---@return number
function ColorGrading:GetTint() end

---@param value number
---@return nil
function ColorGrading:SetGlobalSaturation(value) end

---@return number
function ColorGrading:GetGlobalSaturation() end

---@param value number
---@return nil
function ColorGrading:SetGlobalContrast(value) end

---@return number
function ColorGrading:GetGlobalContrast() end

---@param value number
---@return nil
function ColorGrading:SetGlobalGamma(value) end

---@return number
function ColorGrading:GetGlobalGamma() end

---@param value number
---@return nil
function ColorGrading:SetGlobalGain(value) end

---@return number
function ColorGrading:GetGlobalGain() end

---@param value number
---@return nil
function ColorGrading:SetGlobalOffset(value) end

---@return number
function ColorGrading:GetGlobalOffset() end

---@param value number
---@return nil
function ColorGrading:SetShadowsSaturation(value) end

---@return number
function ColorGrading:GetShadowsSaturation() end

---@param value number
---@return nil
function ColorGrading:SetShadowsContrast(value) end

---@return number
function ColorGrading:GetShadowsContrast() end

---@param value number
---@return nil
function ColorGrading:SetShadowsGamma(value) end

---@return number
function ColorGrading:GetShadowsGamma() end

---@param value number
---@return nil
function ColorGrading:SetShadowsGain(value) end

---@return number
function ColorGrading:GetShadowsGain() end

---@param value number
---@return nil
function ColorGrading:SetShadowsOffset(value) end

---@return number
function ColorGrading:GetShadowsOffset() end

---@param tint Color
---@return nil
function ColorGrading:SetShadowsTint(tint) end

---@return Color
function ColorGrading:GetShadowsTint() end

---@param value number
---@return nil
function ColorGrading:SetShadowsTintIntensity(value) end

---@return number
function ColorGrading:GetShadowsTintIntensity() end

---@param value number
---@return nil
function ColorGrading:SetMidtonesSaturation(value) end

---@return number
function ColorGrading:GetMidtonesSaturation() end

---@param value number
---@return nil
function ColorGrading:SetMidtonesContrast(value) end

---@return number
function ColorGrading:GetMidtonesContrast() end

---@param value number
---@return nil
function ColorGrading:SetMidtonesGamma(value) end

---@return number
function ColorGrading:GetMidtonesGamma() end

---@param value number
---@return nil
function ColorGrading:SetMidtonesGain(value) end

---@return number
function ColorGrading:GetMidtonesGain() end

---@param value number
---@return nil
function ColorGrading:SetMidtonesOffset(value) end

---@return number
function ColorGrading:GetMidtonesOffset() end

---@param tint Color
---@return nil
function ColorGrading:SetMidtonesTint(tint) end

---@return Color
function ColorGrading:GetMidtonesTint() end

---@param value number
---@return nil
function ColorGrading:SetMidtonesTintIntensity(value) end

---@return number
function ColorGrading:GetMidtonesTintIntensity() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsSaturation(value) end

---@return number
function ColorGrading:GetHighlightsSaturation() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsContrast(value) end

---@return number
function ColorGrading:GetHighlightsContrast() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsGamma(value) end

---@return number
function ColorGrading:GetHighlightsGamma() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsGain(value) end

---@return number
function ColorGrading:GetHighlightsGain() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsOffset(value) end

---@return number
function ColorGrading:GetHighlightsOffset() end

---@param tint Color
---@return nil
function ColorGrading:SetHighlightsTint(tint) end

---@return Color
function ColorGrading:GetHighlightsTint() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsTintIntensity(value) end

---@return number
function ColorGrading:GetHighlightsTintIntensity() end

---@param value number
---@return nil
function ColorGrading:SetShadowsMax(value) end

---@return number
function ColorGrading:GetShadowsMax() end

---@param value number
---@return nil
function ColorGrading:SetHighlightsMin(value) end

---@return number
function ColorGrading:GetHighlightsMin() end

---@param enabled boolean
---@return nil
function ColorGrading:SetColorGradingEnabled(enabled) end

---@return boolean
function ColorGrading:IsColorGradingEnabled() end

---@param path string
---@return boolean
function ColorGrading:SavePreset(path) end

---@param path string
---@return boolean
function ColorGrading:LoadPreset(path) end

---@return nil
function ColorGrading:ResetToDefaults() end

