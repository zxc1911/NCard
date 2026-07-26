---@meta

--- Auto-generated from Audio/Sound

---@class Sound : ResourceWithMetadata
---@overload fun(): Sound
---@field length number
---@field dataSize integer
---@field sampleSize integer
---@field frequency number
---@field intFrequency integer
---@field looped boolean
---@field sixteenBit boolean
---@field stereo boolean
---@field compressed boolean
Sound = {}

---@return Sound
function Sound.new() end

---@param source Deserializer
---@return boolean
function Sound:LoadRaw(source) end

---@param fileName string
---@return boolean
function Sound:LoadRaw(fileName) end

---@param source Deserializer
---@return boolean
function Sound:LoadWav(source) end

---@param fileName string
---@return boolean
function Sound:LoadWav(fileName) end

---@param source Deserializer
---@return boolean
function Sound:LoadOggVorbis(source) end

---@param fileName string
---@return boolean
function Sound:LoadOggVorbis(fileName) end

---@param source Deserializer
---@return boolean
function Sound:LoadMp3(source) end

---@param fileName string
---@return boolean
function Sound:LoadMp3(fileName) end

---@param dataSize integer
---@return nil
function Sound:SetSize(dataSize) end

-- Method SetData is not supported (uses void* pointer)

---@param frequency integer
---@param sixteenBit boolean
---@param stereo boolean
---@return nil
function Sound:SetFormat(frequency, sixteenBit, stereo) end

---@param enable boolean
---@return nil
function Sound:SetLooped(enable) end

---@param repeatOffset integer
---@param endOffset integer
---@return nil
function Sound:SetLoop(repeatOffset, endOffset) end

---@return nil
function Sound:FixInterpolation() end

---@return number
function Sound:GetLength() end

---@return integer
function Sound:GetDataSize() end

---@return integer
function Sound:GetSampleSize() end

---@return number
function Sound:GetFrequency() end

---@return integer
function Sound:GetIntFrequency() end

---@return boolean
function Sound:IsLooped() end

---@return boolean
function Sound:IsSixteenBit() end

---@return boolean
function Sound:IsStereo() end

---@return boolean
function Sound:IsCompressed() end


-- Global functions
---@param fileName string
---@return boolean
function LoadRaw(fileName) end

---@param fileName string
---@return boolean
function LoadWav(fileName) end

---@param fileName string
---@return boolean
function LoadOggVorbis(fileName) end

---@param fileName string
---@return boolean
function LoadMp3(fileName) end
