---@meta

--- Auto-generated from Audio/SoundSource


---@class SoundSource : Component
---@field sound Sound
---@field soundType string
---@field timePosition number
---@field frequency number
---@field gain number
---@field attenuation number
---@field panning number
---@field autoRemoveMode AutoRemoveMode
---@field playing boolean
---@field fadingIn boolean
---@field fadingOut boolean
---@field declickEnabled boolean
SoundSource = {}

---@param seekTime number
---@return nil
function SoundSource:Seek(seekTime) end

---@param sound Sound
---@return nil
function SoundSource:Play(sound) end

---@param sound Sound
---@param frequency number
---@return nil
function SoundSource:Play(sound, frequency) end

---@param sound Sound
---@param frequency number
---@param gain number
---@return nil
function SoundSource:Play(sound, frequency, gain) end

---@param sound Sound
---@param frequency number
---@param gain number
---@param panning number
---@return nil
function SoundSource:Play(sound, frequency, gain, panning) end

---@return nil
function SoundSource:Stop() end

---@return nil
function SoundSource:StopImmediate() end

---@param enable boolean
---@return nil
function SoundSource:SetDeclickEnabled(enable) end

---@return boolean
function SoundSource:GetDeclickEnabled() end

---@param type string
---@return nil
function SoundSource:SetSoundType(type) end

---@param frequency number
---@return nil
function SoundSource:SetFrequency(frequency) end

---@param gain number
---@return nil
function SoundSource:SetGain(gain) end

---@param attenuation number
---@return nil
function SoundSource:SetAttenuation(attenuation) end

---@param panning number
---@return nil
function SoundSource:SetPanning(panning) end

---@param mode AutoRemoveMode
---@return nil
function SoundSource:SetAutoRemoveMode(mode) end

---@return Sound
function SoundSource:GetSound() end

---@return string
function SoundSource:GetSoundType() end

---@return number
function SoundSource:GetTimePosition() end

---@return number
function SoundSource:GetFrequency() end

---@return number
function SoundSource:GetGain() end

---@return number
function SoundSource:GetAttenuation() end

---@return number
function SoundSource:GetPanning() end

---@return AutoRemoveMode
function SoundSource:GetAutoRemoveMode() end

--- Return whether is playing. Returns true during fade-in, false during fade-out.
---@return boolean
function SoundSource:IsPlaying() end

--- Return whether a fade-in is in progress.
---@return boolean
function SoundSource:IsFadingIn() end

--- Return whether a fade-out is in progress.
---@return boolean
function SoundSource:IsFadingOut() end

