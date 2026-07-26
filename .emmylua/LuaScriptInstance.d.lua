---@meta

--- Auto-generated from LuaScript/LuaScriptInstance

---@class LuaScriptInstance : Component
---@field scriptFile LuaFile
---@field scriptObjectType string
LuaScriptInstance = {}

---@param scriptObjectType string
---@return boolean
function LuaScriptInstance:CreateObject(scriptObjectType) end

---@param scriptFile LuaFile
---@param scriptObjectType string
---@return boolean
function LuaScriptInstance:CreateObject(scriptFile, scriptObjectType) end

---@param scriptFile LuaFile
---@return nil
function LuaScriptInstance:SetScriptFile(scriptFile) end

---@param scriptObjectType string
---@return nil
function LuaScriptInstance:SetScriptObjectType(scriptObjectType) end

---@return LuaFile
function LuaScriptInstance:GetScriptFile() end

---@return string
function LuaScriptInstance:GetScriptObjectType() end

