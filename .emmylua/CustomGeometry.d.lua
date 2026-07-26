---@meta

--- Auto-generated from Graphics/CustomGeometry

---@class CustomGeometryVertex
---@field position Vector3
---@field normal Vector3
---@field color integer
---@field texCoord Vector2
---@field tangent Vector4
CustomGeometryVertex = {}


---@class CustomGeometry : Drawable
---@field material Material
---@field numGeometries integer
---@field dynamic boolean
CustomGeometry = {}

---@return nil
function CustomGeometry:Clear() end

---@param num integer
---@return nil
function CustomGeometry:SetNumGeometries(num) end

---@param enable boolean
---@return nil
function CustomGeometry:SetDynamic(enable) end

---@param index integer
---@param type PrimitiveType
---@return nil
function CustomGeometry:BeginGeometry(index, type) end

--- 绕序约定：三角形正面 = (v1-v0)×(v2-v0) 指向的一侧，正面须朝外，反了会被默认背面剔除。例：(0,0,0)→(0,0,1)→(1,0,0) 正面朝 +Y
---@param position Vector3
---@return nil
function CustomGeometry:DefineVertex(position) end

---@param normal Vector3
---@return nil
function CustomGeometry:DefineNormal(normal) end

---@param tangent Vector4
---@return nil
function CustomGeometry:DefineTangent(tangent) end

---@param color Color
---@return nil
function CustomGeometry:DefineColor(color) end

---@param texCoord Vector2
---@return nil
function CustomGeometry:DefineTexCoord(texCoord) end

---@param index integer
---@param type PrimitiveType
---@param numVertices integer
---@param hasNormals boolean
---@param hasColors boolean
---@param hasTexCoords boolean
---@param hasTangents boolean
---@return nil
function CustomGeometry:DefineGeometry(index, type, numVertices, hasNormals, hasColors, hasTexCoords, hasTangents) end

---@return nil
function CustomGeometry:Commit() end

---@param material Material
---@return nil
function CustomGeometry:SetMaterial(material) end

---@param index integer
---@param material Material
---@return boolean
function CustomGeometry:SetMaterial(index, material) end

---@return integer
function CustomGeometry:GetNumGeometries() end

---@param index integer
---@return integer
function CustomGeometry:GetNumVertices(index) end

---@param model Model
---@return boolean
function CustomGeometry:FillModel(model) end

---@return boolean
function CustomGeometry:IsDynamic() end

---@param index? integer
---@return Material
function CustomGeometry:GetMaterial(index) end

---@param geometryIndex integer
---@param vertexNum integer
---@return CustomGeometryVertex
function CustomGeometry:GetVertex(geometryIndex, vertexNum) end

