---@meta

--- Auto-generated from Network_Http/HttpResponse

---@class HttpResponse
---@field statusCode integer
---@field statusText string
---@field success boolean
---@field dataAsString string
---@field downloadedBytes integer
---@field totalBytes integer
---@field progress number
HttpResponse = {}

--- 获取状态码
---@return integer
function HttpResponse:GetStatusCode() end

--- 获取状态文本
---@return string
function HttpResponse:GetStatusText() end

--- 判断请求是否成功（2xx）
---@return boolean
function HttpResponse:IsSuccess() end

--- 获取响应数据（字符串形式）
---@return string
function HttpResponse:GetDataAsString() end

--- 获取指定响应头
---@param name string
---@return string
function HttpResponse:GetHeader(name) end

--- 获取已下载字节数
---@return integer
function HttpResponse:GetDownloadedBytes() end

--- 获取总字节数
---@return integer
function HttpResponse:GetTotalBytes() end

--- 获取进度（0.0 - 1.0）
---@return number
function HttpResponse:GetProgress() end

