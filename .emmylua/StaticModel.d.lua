---@meta

--- Auto-generated from Graphics/StaticModel

---@class StaticModel : Drawable
---@field model Model
---@field material Material
---@field boundingBox BoundingBox
---@field numGeometries integer
---@field occlusionLodLevel integer
StaticModel = {}

---@param model Model
---@return nil
function StaticModel:SetModel(model) end

---@param material Material
---@return nil
function StaticModel:SetMaterial(material) end

---@param index integer
---@param material Material
---@return boolean
function StaticModel:SetMaterial(index, material) end

---@param level integer
---@return nil
function StaticModel:SetOcclusionLodLevel(level) end

---@param fileName? string
---@return nil
function StaticModel:ApplyMaterialList(fileName) end

---@return Model
function StaticModel:GetModel() end

---@return integer
function StaticModel:GetNumGeometries() end

---@return Material
function StaticModel:GetMaterial() end

---@param index integer
---@return Material
function StaticModel:GetMaterial(index) end

---@return integer
function StaticModel:GetOcclusionLodLevel() end

---@param point Vector3
---@return boolean
function StaticModel:IsInside(point) end

---@param point Vector3
---@return boolean
function StaticModel:IsInsideLocal(point) end

