-- 塔环国：纯 2D 像素 RPG 原型
-- 四方向移动、自动门传送、头像姓名对话框

local UI = require("urhox-libs/UI")
local Maps = require("Maps")
local HeroFrames = require("ChibiHeroFrames")
local Prologue = require("Prologue")

---@type NVGContextWrapper|nil
local vg_ = nil
local pixelFont_ = -1
local currentMap_ = nil
local player_ = {
    x = 6,
    y = 8,
    direction = "down",
    moving = false,
    walkSpeed = 3.4,
}

local TILE = 40
local actorScale_ = 1.0
local logicalW_ = 1280
local logicalH_ = 720
local dpr_ = 1.0
local cameraX_ = 0.0
local cameraY_ = 0.0
local transitionLock_ = 0.0
local floorTransition_ = {
    active = false,
    phase = "idle",
    timer = 0.0,
    alpha = 0.0,
    target = nil,
}
local firstPerson_ = {
    active = false,
    room = nil,
    viewId = "door",
    returnMap = "village",
    returnX = 14,
    returnY = 20,
    returnDirection = "down",
}
---@type Scene|nil
local audioScene_ = nil
---@type SoundSource|nil
local transitionSoundSource_ = nil
---@type SoundSource|nil
local bgmSoundSource_ = nil
local currentBgmPath_ = nil
local prologue_ = Prologue.Create()
local touchMove_ = { up = false, down = false, left = false, right = false }
local imageHandles_ = {}
local heroFrameIndex_ = 1
local heroFrameTimer_ = 0.0
local heroAnimationDirection_ = "down"
local heroAnimationState_ = "idle"
local TileToScreen
local FillRect
local StrokeRect
local ResetHeroAnimation
local LoadMap

local dialog_ = {
    open = false,
    speaker = nil,
    lines = {},
    index = 1,
    visibleChars = 0,
    charTimer = 0.0,
}
local dialogCloseLock_ = 0.0

local CARD_DEFINITIONS = {
    {
        id = "gravity_formula",
        name = "F=MG",
        type = "基础法则",
        cost = 1,
        description = "费用 1。让目标响应当前的重力矢量 g；默认方向为右。",
        accent = { 255, 202, 48, 255 },
    },
    {
        id = "vector_direction",
        name = "矢量改向",
        type = "方向技能",
        cost = 0,
        generator = true,
        description = "拖出后松手即可展开四张方向卡，从中选择一张加入手牌。",
        accent = { 108, 92, 231, 255 },
    },
    {
        id = "vector_up",
        name = "向上",
        type = "方向卡",
        cost = 2,
        direction = "up",
        parameterCard = true,
        description = "费用 2。将一个兼容的矢量改为向上；拖到发光的矢量变量上生效。",
        accent = { 108, 92, 231, 255 },
    },
    {
        id = "vector_down",
        name = "向下",
        type = "方向卡",
        cost = 2,
        direction = "down",
        parameterCard = true,
        description = "费用 2。将一个兼容的矢量改为向下；拖到发光的矢量变量上生效。",
        accent = { 108, 92, 231, 255 },
    },
    {
        id = "vector_left",
        name = "向左",
        type = "方向卡",
        cost = 2,
        direction = "left",
        parameterCard = true,
        description = "费用 2。将一个兼容的矢量改为向左；拖到发光的矢量变量上生效。",
        accent = { 108, 92, 231, 255 },
    },
    {
        id = "vector_right",
        name = "向右",
        type = "方向卡",
        cost = 2,
        direction = "right",
        parameterCard = true,
        description = "费用 2。将一个兼容的矢量改为向右；拖到发光的矢量变量上生效。",
        accent = { 108, 92, 231, 255 },
    },
    {
        id = "tower_ink",
        name = "塔影墨水",
        type = "铭文",
        description = "墨水会沿着古老机关的刻痕自行流动。",
        accent = { 91, 122, 181, 255 },
    },
    {
        id = "mirror_dust",
        name = "镜尘",
        type = "媒介",
        description = "洒在旧镜上，可显现被时间抹去的影像。",
        accent = { 177, 205, 219, 255 },
    },
    {
        id = "clockwork_spring",
        name = "机械发条",
        type = "零件",
        description = "还能转动的小型黄铜发条，适合精密机械。",
        accent = { 203, 146, 62, 255 },
    },
    {
        id = "ember_rune",
        name = "余烬符",
        type = "符文",
        description = "封存着六点不灭余火，可唤醒熄灭的火焰。",
        accent = { 207, 82, 48, 255 },
    },
    {
        id = "brass_key",
        name = "黄铜钥匙",
        type = "钥匙",
        description = "钥齿由六段塔纹组成，似乎对应某道暗锁。",
        accent = { 219, 176, 98, 255 },
    },
}

local gameState_ = {
    openedChests = {},
    inventory = {},
    ownedCards = {},
    usedCards = {},
    stagedCards = {},
    cardBindings = {},
    objectCards = {},
    solvedObjects = {},
    objectActionSpent = {},
    cardTutorialSeen = false,
}

local cardDrag_ = {
    active = false,
    card = nil,
    sourceWidget = nil,
    pointerId = nil,
    x = 0,
    y = 0,
}
local cardFeedbackTimer_ = 0.0
local birthdayLetterOpen_ = false
local cardTutorialOpen_ = false
local gravityLetter_ = {
    active = true,
    fallen = false,
    collectible = false,
    collected = false,
    hovered = false,
    gravityEnabled = false,
    vectorCardApplied = false,
    vectorDirection = "right",
    horizontalTravelSign = 1,
    x = 0.57,
    y = 0.25,
    startX = 0.57,
    startY = 0.25,
    targetY = 0.66,
    velocityX = 0.0,
    velocityY = 0.0,
    animationTimer = 0.0,
    timeScale = 1.0,
    glowIntensity = 0.0,
    frozen = false,
    targetLocked = false,
    displayScale = 1.0,
}

local DIRECTION_CARD_ORDER = { "vector_up", "vector_down", "vector_left", "vector_right" }

-- 世界内公式浮层（画在信封上方，g 可作为放置靶区）
local formulaOverlay_ = {
    visible = false,
    gGlow = 0.0,
    gHovered = false,
    -- 逻辑坐标下的 g 命中框
    gx = 0.0, gy = 0.0, gw = 0.0, gh = 0.0,
}

-- 矢量卡展开的四张方向卡选择层
-- 所有 UI 操作先排队，下一帧 Update 再执行，避免事件分发中修改祖先控件树
local directionPicker_ = {
    open = false,
    pendingOpen = false,
    pendingCardId = nil,
    pendingCancel = false,
    pendingReset = false,
}

---@type Widget|nil
local locationLabel_ = nil
---@type Widget|nil
local inventoryLabel_ = nil
---@type Widget|nil
local questLabel_ = nil
---@type Widget|nil
local openingPanel_ = nil
---@type Widget|nil
local titleLayer_ = nil
---@type Widget|nil
local introLayer_ = nil
---@type Widget|nil
local introSpeakerLabel_ = nil
---@type Widget|nil
local introLineLabel_ = nil
---@type Widget|nil
local dialogPanel_ = nil
---@type Widget|nil
local portraitPanel_ = nil
---@type Widget|nil
local nameLabel_ = nil
---@type Widget|nil
local dialogueLabel_ = nil
---@type Widget|nil
local continueLabel_ = nil
---@type Widget|nil
local transitionOverlay_ = nil
---@type Widget|nil
local overworldControls_ = nil
---@type Widget|nil
local firstPersonControls_ = nil
---@type Widget|nil
local firstPersonViewLabel_ = nil
---@type Widget|nil
local firstPersonLeftButton_ = nil
---@type Widget|nil
local firstPersonRightButton_ = nil
---@type Widget|nil
local firstPersonUpButton_ = nil
---@type Widget|nil
local firstPersonDownButton_ = nil
---@type Widget|nil
local modeHintLabel_ = nil
---@type Widget|nil
local cardHandPanel_ = nil
---@type Widget|nil
local cardFeedbackLabel_ = nil
---@type Widget|nil
local cardTooltipPanel_ = nil
---@type Widget|nil
local cardTooltipNameLabel_ = nil
---@type Widget|nil
local cardTooltipDescriptionLabel_ = nil
---@type Widget|nil
local cardDragGhost_ = nil
---@type Widget|nil
local cardDragNameLabel_ = nil
---@type Widget|nil
local cardDragTypeLabel_ = nil
---@type Widget|nil
local directionPickerLayer_ = nil
---@type Widget|nil
local cardResetButton_ = nil
---@type Widget|nil
local birthdayLetterLayer_ = nil
---@type Widget|nil
local cardTutorialLayer_ = nil
local cardWidgets_ = {}
local cardRestStyles_ = {}
local cardHandDirty_ = false
local FINE_CELLS_PER_TILE = 4
local COLLISION_CLOUD_KEY = "tower2d/collision-editor/v2"
local collisionEditor_ = {
    active = false,
    savePath = "collision-editor.json",
    dirty = false,
    cloudSavePending = false,
    cloudSaveTimer = 0.0,
    revision = 0,
    pendingRevision = 0,
    portalMode = false,
    portalTargetIndex = 1,
    selectedCells = {},
    draggingSelection = false,
    dragLastX = 0,
    dragLastY = 0,
    selectedPortals = {},
    draggingPortal = false,
    portalDragLastX = 0,
    portalDragLastY = 0,
}
local collisionSavePayload_ = {
    version = 2,
    subcellsPerTile = FINE_CELLS_PER_TILE,
    maps = {},
    portals = {},
}
local UpdateWorldCamera
local UpdateWorldScale
local UpdateInventoryHUD
local UpdateQuestHUD
local SetCollisionEditorMessage
local EnterFirstPersonRoom
local ExitFirstPersonRoom
local SwitchFirstPersonView
local OpenDialogue
local RebuildCardHand
local CancelCardDrag
local ResolveCardDrop
local SetCardFeedback
local ShowBirthdayLetter
local ShowCardTutorial
local OpenInvitationDialogue
local GetGravityLetterCardTarget
local OpenDirectionPicker
local CloseDirectionPicker
local PickDirectionCard
local ApplyDirectionCard
local ApplyGravityFormula
local ResetGravityLetterCards
local UpdateCardResetButton
local ProcessPendingCardUIActions

local function UpdateResolution()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    dpr_ = math.max(1.0, graphics:GetDPR())
    logicalW_ = physW / dpr_
    logicalH_ = physH / dpr_
end

local function PixelForgeTheme()
    return UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/FusionPixel-12px-Prop-zh_hans.ttf",
                bold = "Fonts/FusionPixel-12px-Prop-zh_hans-Bold.ttf",
            } },
        },
        colors = {
            primary = { 33, 189, 174, 255 },
            background = { 15, 15, 35, 255 },
            surface = { 27, 27, 58, 255 },
            text = { 240, 240, 240, 255 },
            textSecondary = { 160, 160, 192, 255 },
            border = { 58, 58, 106, 255 },
        },
        componentDefaults = { borderRadius = 0 },
        components = {
            Button = { borderWidth = 2 },
            Card = { borderWidth = 2 },
        },
    })
end

local function SetTouch(direction, pressed)
    if not Prologue.IsGameplayReady(prologue_) then return end
    touchMove_[direction] = pressed
end

local function CreateMoveButton(text, left, bottom, direction)
    return UI.Button {
        text = text,
        position = "absolute",
        left = left,
        bottom = bottom,
        width = 46,
        height = 46,
        padding = 0,
        fontSize = 15,
        backgroundColor = { 27, 27, 58, 215 },
        borderWidth = 2,
        borderColor = { 58, 58, 106, 255 },
        onPointerDown = function() SetTouch(direction, true) end,
        onPointerUp = function() SetTouch(direction, false) end,
        onPointerLeave = function() SetTouch(direction, false) end,
    }
end

local function GetGravityLetterHitBounds()
    local halfW = 0.075
    local halfH = 0.075
    local centerX = gravityLetter_.x + 0.0475
    local centerY = gravityLetter_.y + 0.055
    return centerX - halfW, centerY - halfH, centerX + halfW, centerY + halfH
end

local function GetPhysicalPointerPosition()
    local position = input:GetMousePosition()
    return position.x, position.y
end

local function PhysicalToUIPointer(x, y)
    local scale = math.max(0.001, UI.GetScale())
    return x / scale, y / scale
end

local function GetLogicalPointerPosition()
    local physicalX, physicalY = GetPhysicalPointerPosition()
    return physicalX / dpr_, physicalY / dpr_
end

local function IsPointerOverGravityLetter()
    if not firstPerson_.active or firstPerson_.viewId ~= "window" or not gravityLetter_.active then
        return false
    end
    local mousePos = input:GetMousePosition()
    local normalizedX = mousePos.x / math.max(1, graphics:GetWidth())
    local normalizedY = mousePos.y / math.max(1, graphics:GetHeight())
    local left, top, right, bottom = GetGravityLetterHitBounds()
    -- 放大时同步放大命中框，避免视觉与判定不一致
    local scale = math.max(1.0, gravityLetter_.displayScale or 1.0)
    local centerX = (left + right) * 0.5
    local centerY = (top + bottom) * 0.5
    local halfW = (right - left) * 0.5 * scale
    local halfH = (bottom - top) * 0.5 * scale
    return normalizedX >= centerX - halfW and normalizedX <= centerX + halfW
        and normalizedY >= centerY - halfH and normalizedY <= centerY + halfH
end

local function UpdateGravityLetterHover()
    local canHover = firstPerson_.active
        and not dialog_.open
        and not cardTutorialOpen_
        and not birthdayLetterOpen_
        and not cardDrag_.active
        and not UI.IsPointerOverUI()
    gravityLetter_.hovered = canHover and IsPointerOverGravityLetter()
end

-- 信封在逻辑坐标下的绘制矩形（含悬停/拖拽放大）
local function GetGravityLetterLogicalRect()
    local scale = gravityLetter_.displayScale
    local letterW = logicalW_ * 0.15 * scale
    local letterH = logicalH_ * 0.15 * scale
    local letterX = gravityLetter_.x * logicalW_ + logicalW_ * 0.0475 - letterW * 0.5
    local letterY = gravityLetter_.y * logicalH_ + logicalH_ * 0.055 - letterH * 0.5
    return letterX, letterY, letterW, letterH
end

-- 判断某张卡是否能作用于信封（用于拖拽时的高亮判定）
local function CardCanTargetLetter(card)
    if card == nil then return false end
    if not gravityLetter_.active or gravityLetter_.fallen then return false end
    if not firstPerson_.active or firstPerson_.viewId ~= "window" then return false end
    if card.generator then return false end
    if card.parameterCard then
        -- 方向卡作用于公式里的 g，需要公式已经存在
        return formulaOverlay_.visible
    end
    return card.id == "gravity_formula" and not gravityLetter_.gravityEnabled
end

-- 拖拽中：指针是否落在信封上
local function IsDragOverLetter()
    if not cardDrag_.active then return false end
    local logicalX, logicalY = GetLogicalPointerPosition()
    local x, y, w, h = GetGravityLetterLogicalRect()
    return logicalX >= x and logicalX <= x + w and logicalY >= y and logicalY <= y + h
end

-- 拖拽中：指针是否落在公式的 g 上
local function IsDragOverFormulaG()
    if not cardDrag_.active or not formulaOverlay_.visible then return false end
    if cardDrag_.card == nil or not cardDrag_.card.parameterCard then return false end
    local logicalX, logicalY = GetLogicalPointerPosition()
    return logicalX >= formulaOverlay_.gx
        and logicalX <= formulaOverlay_.gx + formulaOverlay_.gw
        and logicalY >= formulaOverlay_.gy
        and logicalY <= formulaOverlay_.gy + formulaOverlay_.gh
end

local function UpdateGravityLetter(dt)
    if not gravityLetter_.active then return end

    local dragCard = cardDrag_.active and cardDrag_.card or nil
    local canTarget = CardCanTargetLetter(dragCard)
    local overLetter = canTarget and not dragCard.parameterCard and IsDragOverLetter()
    local overG = IsDragOverFormulaG()

    -- 拿起任何卡牌时立即冻结位移，但序列帧继续播放
    gravityLetter_.animationTimer = gravityLetter_.animationTimer + dt
    gravityLetter_.frozen = cardDrag_.active
    gravityLetter_.targetLocked = overLetter or overG
    gravityLetter_.timeScale = cardDrag_.active and 0.0 or 1.0

    -- 高亮发光：可用目标常亮，悬停时更强
    local targetGlow = 0.0
    if canTarget and not dragCard.parameterCard then
        targetGlow = overLetter and 1.0 or 0.65
    end
    gravityLetter_.glowIntensity = gravityLetter_.glowIntensity
        + (targetGlow - gravityLetter_.glowIntensity) * math.min(1.0, dt * 12.0)

    -- 公式中 g 的发光
    local targetGGlow = 0.0
    if cardDrag_.active and dragCard ~= nil and dragCard.parameterCard and formulaOverlay_.visible then
        -- 拿起方向卡后，所有兼容矢量立即高亮；悬停时进一步增强
        targetGGlow = overG and 1.0 or 0.86
    end
    formulaOverlay_.gGlow = formulaOverlay_.gGlow
        + (targetGGlow - formulaOverlay_.gGlow) * math.min(1.0, dt * 12.0)

    -- 放大：悬停拖拽时变大
    local targetScale = 1.0
    if overLetter then
        targetScale = 1.45
    elseif canTarget and not dragCard.parameterCard then
        targetScale = 1.12
    elseif gravityLetter_.hovered then
        targetScale = 1.22
    end
    gravityLetter_.displayScale = gravityLetter_.displayScale
        + (targetScale - gravityLetter_.displayScale) * math.min(1.0, dt * 12.0)

    if gravityLetter_.fallen or not gravityLetter_.gravityEnabled then return end

    local scaledDt = dt * gravityLetter_.timeScale
    if scaledDt <= 0.0 then return end

    local speed = 0.24
    local direction = gravityLetter_.vectorDirection
    if direction == "down" then
        gravityLetter_.velocityY = math.min(0.65, gravityLetter_.velocityY + 1.65 * scaledDt)
        gravityLetter_.y = math.min(gravityLetter_.targetY, gravityLetter_.y + gravityLetter_.velocityY * scaledDt)
        if gravityLetter_.y >= gravityLetter_.targetY then
            gravityLetter_.fallen = true
            gravityLetter_.collectible = true
            gravityLetter_.velocityX = 0.0
            gravityLetter_.velocityY = 0.0
            UpdateCardResetButton()
            SetCardFeedback("g 已调整为向下，邀请函落到了窗台上。可先重置，或点击信封收取。", { 98, 220, 139, 255 })
            print("[Tower2D] Gravity letter landed")
        end
        return
    end

    gravityLetter_.velocityY = 0.0
    if direction == "right" or direction == "left" then
        gravityLetter_.x = gravityLetter_.x + speed * gravityLetter_.horizontalTravelSign * scaledDt
        if gravityLetter_.x >= 0.72 then
            gravityLetter_.x = 0.72
            gravityLetter_.horizontalTravelSign = -1
        elseif gravityLetter_.x <= 0.40 then
            gravityLetter_.x = 0.40
            gravityLetter_.horizontalTravelSign = 1
        end
    elseif direction == "up" then
        gravityLetter_.y = gravityLetter_.y - speed * scaledDt
        if gravityLetter_.y < 0.10 then gravityLetter_.y = 0.42 end
    end
end

SetCardFeedback = function(text, color)
    if cardFeedbackLabel_ == nil then return end
    cardFeedbackLabel_:SetText(text)
    cardFeedbackLabel_:SetStyle({ fontColor = color })
    cardFeedbackLabel_:Show()
    cardFeedbackTimer_ = 2.2
end

local function SetCardRestStyle(widget, restStyle)
    restStyle = restStyle or { rotate = 0, translateY = 0, scale = 1.0, zIndex = 0 }
    widget:SetStyle({
        rotate = restStyle.rotate or 0,
        scale = restStyle.scale or 1.0,
        translateY = restStyle.translateY or 0,
        opacity = 1.0,
        zIndex = restStyle.zIndex or 0,
    })
end

local function SetCardHoverStyle(widget, card)
    widget:SetStyle({
        scale = 1.16,
        rotate = 0,
        translateY = -38,
        opacity = 1.0,
        zIndex = 220,
    })
    if cardTooltipNameLabel_ ~= nil then
        cardTooltipNameLabel_:SetText(string.format(
            "%s · %s · 费用 %d",
            card.name,
            card.type,
            card.cost or 0
        ))
        cardTooltipDescriptionLabel_:SetText(card.description)
        cardTooltipPanel_:Show()
    end
end

local function HideCardTooltip()
    if cardTooltipPanel_ ~= nil and not cardDrag_.active then
        cardTooltipPanel_:Hide()
    end
end

local function UpdateCardDragGhost(x, y)
    if cardDragGhost_ == nil then return end
    cardDragGhost_:SetStyle({
        left = x - 58,
        top = y - 74,
    })
end

local function FineCollisionCellKey(x, y)
    return tostring(y) .. ":" .. tostring(x)
end

local function SortedSolidKeys(solids)
    local keys = {}
    for key, solid in pairs(solids or {}) do
        if solid then table.insert(keys, key) end
    end
    table.sort(keys)
    return keys
end

local function EnsureFineCollision(map)
    if map == nil or map.fineCollision then return end
    map.fineSolids = Maps.ExpandCoarseSolids(map)
    map.fineCollision = true
end

local function KeepPortalCellsWalkable(map)
    for key in pairs(map.portals or {}) do
        map.solids[key] = nil
        local tileYText, tileXText = key:match("^(%d+):(%d+)$")
        local tileX = tonumber(tileXText)
        local tileY = tonumber(tileYText)
        if tileX ~= nil and tileY ~= nil and map.fineSolids ~= nil then
            local startX = (tileX - 1) * FINE_CELLS_PER_TILE + 1
            local startY = (tileY - 1) * FINE_CELLS_PER_TILE + 1
            for fineY = startY, startY + FINE_CELLS_PER_TILE - 1 do
                for fineX = startX, startX + FINE_CELLS_PER_TILE - 1 do
                    map.fineSolids[FineCollisionCellKey(fineX, fineY)] = nil
                end
            end
        end
    end
end

local function ApplySavedCollision(map)
    if map == nil or map.backgroundImage == nil then return false end
    local saved = collisionSavePayload_.maps[map.id]
    if saved == nil then return false end

    if saved.fineSolids ~= nil then
        map.fineSolids = {}
        for _, key in ipairs(saved.fineSolids) do
            map.fineSolids[key] = true
        end
        map.fineCollision = true
    else
        map.solids = {}
        for _, key in ipairs(saved) do
            map.solids[key] = true
        end
        map.fineSolids = nil
        map.fineCollision = false
    end
    KeepPortalCellsWalkable(map)
    return true
end

local function LoadLocalCollisionPayload()
    if not fileSystem:FileExists(collisionEditor_.savePath) then return end
    local file = File(collisionEditor_.savePath, FILE_READ)
    if not file:IsOpen() then return end
    local ok, payload = pcall(cjson.decode, file:ReadString())
    file:Close()
    if ok and type(payload) == "table" and type(payload.maps) == "table" then
        collisionSavePayload_ = payload
        print("[Tower2D] Local collision data loaded")
    end
end

local function WriteLocalCollisionPayload()
    local file = File(collisionEditor_.savePath, FILE_WRITE)
    if not file:IsOpen() then return false end
    file:WriteString(cjson.encode(collisionSavePayload_))
    file:Close()
    return true
end

local function SaveCollisionCloudData()
    if clientCloud == nil then
        collisionEditor_.dirty = false
        SetCollisionEditorMessage("碰撞已本地保存；登录后可同步云端")
        print("[Tower2D] clientCloud unavailable; collision kept locally")
        return
    end
    if collisionEditor_.cloudSavePending then return end
    collisionEditor_.cloudSavePending = true
    collisionEditor_.pendingRevision = collisionEditor_.revision
    local savedRevision = collisionEditor_.pendingRevision
    clientCloud:Set(COLLISION_CLOUD_KEY, cjson.encode(collisionSavePayload_), {
        ok = function()
            collisionEditor_.cloudSavePending = false
            if collisionEditor_.revision == savedRevision then
                collisionEditor_.dirty = false
                SetCollisionEditorMessage("碰撞已云端保存，刷新后会自动恢复")
            else
                collisionEditor_.cloudSaveTimer = 0.1
                SetCollisionEditorMessage("碰撞有新修改，继续同步云端…")
            end
            print("[Tower2D] Cloud collision data saved")
        end,
        error = function(code, reason)
            collisionEditor_.cloudSavePending = false
            SetCollisionEditorMessage("本地已保存；云端保存失败，可按 F5 重试")
            print(string.format("[Tower2D] Cloud collision save failed: %s / %s", tostring(code), tostring(reason)))
        end,
        timeout = function()
            collisionEditor_.cloudSavePending = false
            SetCollisionEditorMessage("本地已保存；云端保存超时，可按 F5 重试")
            print("[Tower2D] Cloud collision save timeout")
        end,
    })
end

local function SaveCollisionEditorData(saveCloudNow)
    if currentMap_ == nil or currentMap_.backgroundImage == nil then return end
    EnsureFineCollision(currentMap_)
    collisionSavePayload_.version = 2
    collisionSavePayload_.subcellsPerTile = FINE_CELLS_PER_TILE
    collisionSavePayload_.maps[currentMap_.id] = {
        fineSolids = SortedSolidKeys(currentMap_.fineSolids),
    }

    if WriteLocalCollisionPayload() then
        SetCollisionEditorMessage("碰撞已本地保存，正在同步云端…")
        print("[Tower2D] Local collision saved: " .. currentMap_.id)
    end
    collisionEditor_.revision = collisionEditor_.revision + 1
    collisionEditor_.dirty = true
    if saveCloudNow then
        collisionEditor_.cloudSaveTimer = 0.0
        SaveCollisionCloudData()
    else
        collisionEditor_.cloudSaveTimer = 0.8
    end
end

local function RestoreDefaultCollision()
    if currentMap_ == nil or currentMap_.backgroundImage == nil then return end
    collisionSavePayload_.maps[currentMap_.id] = nil
    currentMap_ = Maps.Get(currentMap_.id)
    ApplySavedPortals(currentMap_)
    UpdateWorldScale()
    player_.x = math.min(player_.x, currentMap_.width - 0.5)
    player_.y = math.min(player_.y, currentMap_.height - 0.5)
    collisionEditor_.selectedCells = {}
    collisionEditor_.draggingSelection = false
    if WriteLocalCollisionPayload() then
        collisionEditor_.revision = collisionEditor_.revision + 1
        collisionEditor_.dirty = true
        collisionEditor_.cloudSaveTimer = 0.0
        SaveCollisionCloudData()
    end
    SetCollisionEditorMessage("已恢复当前场景默认碰撞；传送点保持不变")
    print("[Tower2D] Default collision restored: " .. currentMap_.id)
end

function EnsurePortalSaveTable(mapId)
    if collisionSavePayload_.portals == nil then collisionSavePayload_.portals = {} end
    if collisionSavePayload_.portals[mapId] == nil then collisionSavePayload_.portals[mapId] = {} end
    return collisionSavePayload_.portals[mapId]
end

function ApplySavedPortals(map)
    if map == nil then return end
    local saved = collisionSavePayload_.portals ~= nil and collisionSavePayload_.portals[map.id] or nil
    if type(saved) ~= "table" then return end
    map.portals = {}
    for key, portal in pairs(saved) do
        map.portals[key] = portal
        map.solids[key] = nil
    end
end

function SavePortalEditorData()
    if currentMap_ == nil then return end
    local saved = EnsurePortalSaveTable(currentMap_.id)
    for key in pairs(saved) do saved[key] = nil end
    for key, portal in pairs(currentMap_.portals or {}) do
        saved[key] = portal
    end
    if WriteLocalCollisionPayload() then
        collisionEditor_.revision = collisionEditor_.revision + 1
        collisionEditor_.dirty = true
        collisionEditor_.cloudSaveTimer = 0.8
        SetCollisionEditorMessage("传送点已保存，正在同步云端…")
        print("[Tower2D] Portal data saved: " .. currentMap_.id)
    end
end

function PortalTargetList()
    return {
        { id = "village", name = "小镇外" },
        { id = "home_lower", name = "家里一楼" },
        { id = "guild", name = "勇者公会" },
        { id = "inn", name = "登塔人旅店" },
        { id = "forge", name = "风轮工坊" },
        { id = "church", name = "教堂内" },
        { id = "tower_floor1", name = "塔1层" },
    }
end

function GetPortalTarget()
    local targets = PortalTargetList()
    local target = targets[collisionEditor_.portalTargetIndex]
    if target == nil then target = targets[1] end
    return target
end

function TogglePortalEditorMode()
    collisionEditor_.portalMode = not collisionEditor_.portalMode
    collisionEditor_.selectedPortals = {}
    collisionEditor_.draggingPortal = false
    local target = GetPortalTarget()
    SetCollisionEditorMessage(collisionEditor_.portalMode
        and ("传送区域编辑：右键选择/新增到 " .. target.name .. "  ·  左键按住拖动  ·  中键删除 · F4切换目标")
        or "碰撞编辑：左键点击切换细格（传送区域自动跳过）  ·  F4传送区域编辑  ·  F8恢复默认碰撞  ·  F2退出")
    print("[Tower2D] Portal editor: " .. tostring(collisionEditor_.portalMode) .. " / " .. target.id)
end

function CyclePortalTarget()
    local targets = PortalTargetList()
    collisionEditor_.portalTargetIndex = collisionEditor_.portalTargetIndex % #targets + 1
    local target = GetPortalTarget()
    SetCollisionEditorMessage("当前传送目标：" .. target.name .. "  ·  右键设置传送点")
end

function GetEditorFineCellAtPointer()
    if UpdateWorldCamera ~= nil then UpdateWorldCamera() end
    local logicalX, logicalY = GetLogicalPointerPosition()
    local subcellSize = TILE / FINE_CELLS_PER_TILE
    local fineX = math.floor((logicalX + cameraX_) / subcellSize) + 1
    local fineY = math.floor((logicalY + cameraY_) / subcellSize) + 1
    if fineX < 1 or fineY < 1
        or fineX > currentMap_.width * FINE_CELLS_PER_TILE
        or fineY > currentMap_.height * FINE_CELLS_PER_TILE then
        return nil, nil
    end
    return fineX, fineY
end

function GetEditorTileAtPointer()
    local fineX, fineY = GetEditorFineCellAtPointer()
    if fineX == nil then return nil, nil end
    return math.floor((fineX - 1) / FINE_CELLS_PER_TILE) + 1,
        math.floor((fineY - 1) / FINE_CELLS_PER_TILE) + 1
end

function GetConnectedSolidCells(startX, startY)
    local cells = {}
    local queue = { { x = startX, y = startY } }
    local head = 1
    while queue[head] ~= nil do
        local cell = queue[head]
        head = head + 1
        local key = FineCollisionCellKey(cell.x, cell.y)
        if not cells[key] and currentMap_.fineSolids[key] then
            cells[key] = true
            table.insert(queue, { x = cell.x + 1, y = cell.y })
            table.insert(queue, { x = cell.x - 1, y = cell.y })
            table.insert(queue, { x = cell.x, y = cell.y + 1 })
            table.insert(queue, { x = cell.x, y = cell.y - 1 })
        end
    end
    return cells
end

function ShiftSelectedCollision(dx, dy)
    if dx == 0 and dy == 0 then return end
    EnsureFineCollision(currentMap_)
    local moved = {}
    for key in pairs(collisionEditor_.selectedCells) do
        local yText, xText = key:match("^(%d+):(%d+)$")
        local x = tonumber(xText)
        local y = tonumber(yText)
        if x ~= nil and y ~= nil then
            local newX = x + dx
            local newY = y + dy
            if newX >= 1 and newY >= 1
                and newX <= currentMap_.width * FINE_CELLS_PER_TILE
                and newY <= currentMap_.height * FINE_CELLS_PER_TILE then
                moved[FineCollisionCellKey(newX, newY)] = true
            end
        end
    end
    for key in pairs(collisionEditor_.selectedCells) do
        currentMap_.fineSolids[key] = nil
    end
    for key in pairs(moved) do
        currentMap_.fineSolids[key] = true
    end
    collisionEditor_.selectedCells = moved
    SaveCollisionEditorData(false)
end

function GetPortalCells(startX, startY)
    local cells = {}
    local startKey = startY .. ":" .. startX
    local startPortal = currentMap_.portals[startKey]
    if startPortal == nil then return cells end
    local queue = { { x = startX, y = startY } }
    local head = 1
    while queue[head] ~= nil do
        local cell = queue[head]
        head = head + 1
        local key = cell.y .. ":" .. cell.x
        local portal = currentMap_.portals[key]
        if not cells[key] and portal ~= nil and portal.target == startPortal.target then
            cells[key] = true
            table.insert(queue, { x = cell.x + 1, y = cell.y })
            table.insert(queue, { x = cell.x - 1, y = cell.y })
            table.insert(queue, { x = cell.x, y = cell.y + 1 })
            table.insert(queue, { x = cell.x, y = cell.y - 1 })
        end
    end
    return cells
end

function GetPortalCellAtPointer()
    local tileX, tileY = GetEditorTileAtPointer()
    if tileX == nil then return nil, nil end
    return tileX, tileY
end

function ShiftSelectedPortals(dx, dy)
    if dx == 0 and dy == 0 then return end
    local moved = {}
    for key in pairs(collisionEditor_.selectedPortals) do
        local yText, xText = key:match("^(%d+):(%d+)$")
        local x = tonumber(xText)
        local y = tonumber(yText)
        local portal = currentMap_.portals[key]
        if x ~= nil and y ~= nil and portal ~= nil then
            local newX = x + dx
            local newY = y + dy
            if newX >= 1 and newY >= 1
                and newX <= currentMap_.width
                and newY <= currentMap_.height then
                local newKey = newY .. ":" .. newX
                local movedPortal = {}
                for field, value in pairs(portal) do movedPortal[field] = value end
                moved[newKey] = movedPortal
            end
        end
    end
    for key in pairs(collisionEditor_.selectedPortals) do
        currentMap_.portals[key] = nil
    end
    collisionEditor_.selectedPortals = {}
    for key, portal in pairs(moved) do
        currentMap_.portals[key] = portal
        currentMap_.solids[key] = nil
        collisionEditor_.selectedPortals[key] = true
    end
    SavePortalEditorData()
end

local function LoadCollisionEditorData(map)
    if ApplySavedCollision(map) then
        print("[Tower2D] Collision loaded: " .. map.id)
    end
    ApplySavedPortals(map)
end

local function LoadCollisionCloudData()
    if clientCloud == nil then
        print("[Tower2D] clientCloud unavailable; using local collision data")
        return
    end
    clientCloud:Get(COLLISION_CLOUD_KEY, {
        ok = function(values)
            local jsonText = values[COLLISION_CLOUD_KEY]
            if type(jsonText) ~= "string" or jsonText == "" then return end
            local ok, payload = pcall(cjson.decode, jsonText)
            if not ok or type(payload) ~= "table" or type(payload.maps) ~= "table" then return end
            if collisionEditor_.dirty then
                SaveCollisionCloudData()
                return
            end
            collisionSavePayload_ = payload
            if collisionSavePayload_.portals == nil then collisionSavePayload_.portals = {} end
            WriteLocalCollisionPayload()
            if currentMap_ ~= nil then
                ApplySavedCollision(currentMap_)
                ApplySavedPortals(currentMap_)
            end
            print("[Tower2D] Cloud collision data loaded")
        end,
        error = function(code, reason)
            print(string.format("[Tower2D] Cloud collision load failed: %s / %s", tostring(code), tostring(reason)))
        end,
        timeout = function()
            print("[Tower2D] Cloud collision load timeout; using local data")
        end,
    })
end

local function IsCollisionEditorMap()
    return not firstPerson_.active
        and not dialog_.open
        and not floorTransition_.active
        and currentMap_ ~= nil
        and currentMap_.backgroundImage ~= nil
end

SetCollisionEditorMessage = function(text)
    if modeHintLabel_ ~= nil then
        modeHintLabel_:SetText(text)
    end
end

local function ToggleCollisionEditor()
    if collisionEditor_.active then
        collisionEditor_.active = false
        collisionEditor_.portalMode = false
        collisionEditor_.selectedCells = {}
        collisionEditor_.selectedPortals = {}
        collisionEditor_.draggingSelection = false
        collisionEditor_.draggingPortal = false
        SetCollisionEditorMessage("方向键 / WASD 移动  ·  E / 空格 调查")
        print("[Tower2D] Collision editor: off")
        return
    end
    if not IsCollisionEditorMap() then
        SetCollisionEditorMessage("当前地图不支持碰撞编辑；请进入带背景图的房间后按 F2")
        print("[Tower2D] Collision editor unavailable on current map")
        return
    end
    EnsureFineCollision(currentMap_)
    collisionEditor_.active = true
    collisionEditor_.portalMode = false
    collisionEditor_.selectedCells = {}
    collisionEditor_.selectedPortals = {}
    collisionEditor_.draggingSelection = false
    collisionEditor_.draggingPortal = false
    SetCollisionEditorMessage("碰撞编辑：左键点击切换细格（传送区域自动跳过）  ·  F4传送区域编辑  ·  F8恢复默认碰撞  ·  F2退出")
    print("[Tower2D] Collision editor: on / " .. currentMap_.id)
end

local function RestoreSavedCollision()
    if currentMap_ == nil or currentMap_.backgroundImage == nil then return end
    LoadCollisionEditorData(currentMap_)
    if collisionEditor_.portalMode then
        SetCollisionEditorMessage("传送区域已读取：右键选择  ·  左键拖动  ·  右键空白新增  ·  中键删除  ·  F4切换目标")
    else
        SetCollisionEditorMessage("已读取保存碰撞：左键切换格子")
    end
end

local function HandleCollisionEditorPointer()
    if not collisionEditor_.active or not IsCollisionEditorMap() then return end
    if collisionEditor_.portalMode then
        if input:GetKeyPress(KEY_F4) then
            CyclePortalTarget()
            return
        end
        local tileX, tileY = GetPortalCellAtPointer()
        if tileX == nil then return end
        local key = tileY .. ":" .. tileX
        if input:GetMouseButtonPress(MOUSEB_RIGHT) then
            if currentMap_.portals[key] ~= nil then
                collisionEditor_.selectedPortals = GetPortalCells(tileX, tileY)
                collisionEditor_.draggingPortal = false
                SetCollisionEditorMessage("已选中传送区域：左键按住细调拖动，右键可重新选择，中键删除")
            else
                local target = GetPortalTarget()
                currentMap_.portals[key] = {
                    target = target.id,
                    x = target.id == "village" and 9 or 7,
                    y = target.id == "tower_floor1" and 11 or 9,
                }
                currentMap_.solids[key] = nil
                collisionEditor_.selectedPortals = { [key] = true }
                SavePortalEditorData()
                SetCollisionEditorMessage("已新增传送区域：" .. key .. " → " .. target.name)
            end
            return
        end
        if input:GetMouseButtonPress(MOUSEB_MIDDLE) then
            if currentMap_.portals[key] ~= nil then
                currentMap_.portals[key] = nil
                collisionEditor_.selectedPortals[key] = nil
                SavePortalEditorData()
                SetCollisionEditorMessage("已删除传送区域：" .. key)
            end
            return
        end
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            if next(collisionEditor_.selectedPortals) == nil then return end
            collisionEditor_.draggingPortal = true
            collisionEditor_.portalDragLastX = tileX
            collisionEditor_.portalDragLastY = tileY
            return
        end
        if input:GetMouseButtonDown(MOUSEB_LEFT) and collisionEditor_.draggingPortal then
            local dx = tileX - collisionEditor_.portalDragLastX
            local dy = tileY - collisionEditor_.portalDragLastY
            if dx ~= 0 or dy ~= 0 then
                ShiftSelectedPortals(dx, dy)
                collisionEditor_.portalDragLastX = tileX
                collisionEditor_.portalDragLastY = tileY
            end
            return
        end
        if input:GetMouseButtonRelease(MOUSEB_LEFT) then
            collisionEditor_.draggingPortal = false
        end
        return
    end
    EnsureFineCollision(currentMap_)
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        local fineX, fineY = GetEditorFineCellAtPointer()
        if fineX == nil then return end
        local tileX = math.floor((fineX - 1) / FINE_CELLS_PER_TILE) + 1
        local tileY = math.floor((fineY - 1) / FINE_CELLS_PER_TILE) + 1
        if Maps.GetPortal(currentMap_, tileX, tileY) ~= nil then
            SetCollisionEditorMessage("传送区域不可修改碰撞，请切换到 F4 传送区域编辑")
            return
        end
        local key = FineCollisionCellKey(fineX, fineY)
        if currentMap_.fineSolids[key] then
            currentMap_.fineSolids[key] = nil
        else
            currentMap_.fineSolids[key] = true
        end
        SaveCollisionEditorData(false)
        SetCollisionEditorMessage(string.format(
            "已切换碰撞细格(%d,%d)，传送区域保持不变",
            tileX,
            tileY
        ))
        print(string.format(
            "[Tower2D] Fine collision toggle: %s (%d,%d)",
            currentMap_.fineSolids[key] and "solid" or "walkable",
            fineX,
            fineY
        ))
        return
    end
end

local function DrawCollisionEditorOverlay()
    if not collisionEditor_.active or not IsCollisionEditorMap() then return end

    if collisionEditor_.portalMode then
        for key, portal in pairs(currentMap_.portals or {}) do
            local tileYText, tileXText = key:match("^(%d+):(%d+)$")
            local tileX = tonumber(tileXText)
            local tileY = tonumber(tileYText)
            if tileX ~= nil and tileY ~= nil then
                local sx, sy = TileToScreen(tileX, tileY)
                local selected = collisionEditor_.selectedPortals[key] == true
                FillRect(sx + 4, sy + 4, TILE - 8, TILE - 8, selected and { 255, 239, 112, 175 } or { 255, 210, 72, 96 })
                StrokeRect(sx + 2, sy + 2, TILE - 4, TILE - 4, selected and { 255, 255, 190, 255 } or { 255, 239, 148, 230 }, selected and 3 or 2)
            end
        end
        return
    end
    local subcellSize = TILE / FINE_CELLS_PER_TILE
    local fineWidth = currentMap_.width * FINE_CELLS_PER_TILE
    local fineHeight = currentMap_.height * FINE_CELLS_PER_TILE
    for fineY = 1, fineHeight do
        for fineX = 1, fineWidth do
            local sx = (fineX - 1) * subcellSize - cameraX_
            local sy = (fineY - 1) * subcellSize - cameraY_
            local key = FineCollisionCellKey(fineX, fineY)
            local solid = currentMap_.fineSolids[key] == true
            local selected = collisionEditor_.selectedCells[key] == true
            FillRect(
                sx + 1,
                sy + 1,
                subcellSize - 2,
                subcellSize - 2,
                selected and { 255, 214, 76, 175 }
                    or (solid and { 214, 74, 74, 76 } or { 56, 205, 132, 18 })
            )
            StrokeRect(
                sx,
                sy,
                subcellSize,
                subcellSize,
                selected and { 255, 248, 154, 255 }
                    or (solid and { 255, 111, 111, 165 } or { 117, 241, 169, 58 }),
                selected and 2 or 1
            )
        end
    end

    for tileY = 1, currentMap_.height do
        for tileX = 1, currentMap_.width do
            local sx, sy = TileToScreen(tileX, tileY)
            StrokeRect(sx, sy, TILE, TILE, { 240, 240, 255, 105 }, 1)
        end
    end
end

local function UpdateCollisionEditorInput()
    if input:GetKeyPress(KEY_F2) then
        ToggleCollisionEditor()
        return
    end
    if not collisionEditor_.active then return end
    if input:GetKeyPress(KEY_F8) then
        RestoreDefaultCollision()
        return
    end
    if input:GetKeyPress(KEY_F4) and not collisionEditor_.portalMode then
        TogglePortalEditorMode()
        return
    end
    if input:GetKeyPress(KEY_F5) then
        SaveCollisionEditorData(true)
        if collisionEditor_.portalMode then SavePortalEditorData() end
    elseif input:GetKeyPress(KEY_F9) then
        RestoreSavedCollision()
    end
    HandleCollisionEditorPointer()
end

local function BeginCardDrag(card, widget, physicalX, physicalY)
    if cardDrag_.active then return false end
    local uiX, uiY = PhysicalToUIPointer(physicalX, physicalY)
    cardDrag_.active = true
    cardDrag_.card = card
    cardDrag_.sourceWidget = widget
    cardDrag_.pointerId = 0
    cardDrag_.x = physicalX
    cardDrag_.y = physicalY
    gravityLetter_.frozen = true
    gravityLetter_.timeScale = 0.0
    gravityLetter_.targetLocked = false
    widget:SetStyle({ opacity = 0.24, scale = 1.0, rotate = 0, translateY = 0, zIndex = 300 })
    cardDragNameLabel_:SetText(card.name)
    cardDragTypeLabel_:SetText(string.format("%s · 费用 %d", card.type, card.cost or 0))
    cardDragGhost_:SetStyle({ borderColor = card.accent })
    UpdateCardDragGhost(uiX, uiY)
    cardDragGhost_:Show()
    if cardTooltipPanel_ ~= nil then cardTooltipPanel_:Hide() end
    print(string.format(
        "[Tower2D] Card drag start: %s at physical %.1f, %.1f",
        card.id,
        physicalX,
        physicalY
    ))
    return true
end

local function FindCardAtPointer(x, y)
    for index = #CARD_DEFINITIONS, 1, -1 do
        local card = CARD_DEFINITIONS[index]
        local widget = cardWidgets_[card.id]
        if widget ~= nil and widget:IsVisible() then
            local rect = UI.GetVisualRect(widget)
            if x >= rect.x and x <= rect.x + rect.w
                and y >= rect.y and y <= rect.y + rect.h then
                return card, widget
            end
        end
    end
    return nil, nil
end

local function UpdateCardPointer()
    if birthdayLetterOpen_ or cardTutorialOpen_ then return end
    if not firstPerson_.active then return end
    local physicalX, physicalY = GetPhysicalPointerPosition()
    local uiX, uiY = PhysicalToUIPointer(physicalX, physicalY)
    if not cardDrag_.active then
        if input:GetMouseButtonPress(MOUSEB_LEFT) and not dialog_.open then
            local card, widget = FindCardAtPointer(uiX, uiY)
            if card ~= nil then
                BeginCardDrag(card, widget, physicalX, physicalY)
            end
        end
        return
    end

    if input:GetMouseButtonDown(MOUSEB_LEFT) then
        cardDrag_.x = physicalX
        cardDrag_.y = physicalY
        UpdateCardDragGhost(uiX, uiY)
        return
    end

    local droppedCard = cardDrag_.card
    CancelCardDrag()
    ResolveCardDrop(droppedCard, physicalX, physicalY)
end

CancelCardDrag = function()
    if cardDrag_.sourceWidget ~= nil and cardDrag_.card ~= nil then
        SetCardRestStyle(
            cardDrag_.sourceWidget,
            cardRestStyles_[cardDrag_.card.id]
        )
    end
    cardDrag_.active = false
    cardDrag_.card = nil
    cardDrag_.sourceWidget = nil
    cardDrag_.pointerId = nil
    gravityLetter_.frozen = false
    gravityLetter_.timeScale = 1.0
    gravityLetter_.targetLocked = false
    if cardDragGhost_ ~= nil then cardDragGhost_:Hide() end
end

local function GetCardDefinition(cardId)
    for _, card in ipairs(CARD_DEFINITIONS) do
        if card.id == cardId then return card end
    end
    return nil
end

local function CardIsAccepted(target, cardId)
    if target.acceptedCard == cardId then return true end
    for _, acceptedId in ipairs(target.acceptedCards or {}) do
        if acceptedId == cardId then return true end
    end
    return false
end

local function GetObjectCardCost(objectId, includeStaged)
    local cost = 0
    for _, cardId in ipairs(gameState_.objectCards[objectId] or {}) do
        local card = GetCardDefinition(cardId)
        if card ~= nil then cost = cost + (card.cost or 0) end
    end
    if includeStaged then
        for cardId, stagedObjectId in pairs(gameState_.stagedCards) do
            if stagedObjectId == objectId then
                local card = GetCardDefinition(cardId)
                if card ~= nil then cost = cost + (card.cost or 0) end
            end
        end
    end
    return cost
end

-- 取得信封对应的 cardTarget 数据（行动值、可接受卡牌等）
GetGravityLetterCardTarget = function()
    if firstPerson_.room == nil then return nil end
    local view = firstPerson_.room.views[firstPerson_.viewId]
    if view == nil then return nil end
    for _, target in ipairs(view.cardTargets or {}) do
        if target.objectId == "gravity_letter" then return target end
    end
    return nil
end

-- 仅在卡牌流程已经开始时显示明确的重置入口
UpdateCardResetButton = function()
    if cardResetButton_ == nil then return end

    local hasDirectionCard = false
    for _, cardId in ipairs(DIRECTION_CARD_ORDER) do
        if gameState_.ownedCards[cardId] then
            hasDirectionCard = true
            break
        end
    end
    local hasCardOperation = directionPicker_.open
        or gameState_.objectCards.gravity_letter ~= nil
        or gameState_.usedCards.vector_direction
        or hasDirectionCard
        or gravityLetter_.gravityEnabled
        or gravityLetter_.vectorCardApplied

    cardResetButton_:SetVisible(
        firstPerson_.active
            and firstPerson_.viewId == "window"
            and not gravityLetter_.collected
            and not prologue_.invitationCollected
            and hasCardOperation
    )
end

-- 关闭方向卡选择层
CloseDirectionPicker = function()
    directionPicker_.pendingOpen = false
    directionPicker_.pendingCardId = nil
    directionPicker_.pendingCancel = false
    directionPicker_.open = false
    if directionPickerLayer_ ~= nil then directionPickerLayer_:Hide() end
    UpdateCardResetButton()
end

-- 打开方向卡选择层：四张方向卡供玩家挑一张进手牌
OpenDirectionPicker = function()
    if directionPickerLayer_ == nil then return end
    directionPicker_.open = true
    directionPickerLayer_:Show()
    UpdateCardResetButton()
    SetCardFeedback("选择一个方向加入手牌（2 费）。点击空白处取消。", { 177, 158, 255, 255 })
    print("[Tower2D] Direction picker opened")
end

-- 玩家挑选了某个方向 → 该方向卡入手牌，矢量改向卡消耗掉
PickDirectionCard = function(cardId)
    local card = GetCardDefinition(cardId)
    if card == nil then return end
    CloseDirectionPicker()
    gameState_.ownedCards[cardId] = true
    gameState_.usedCards[cardId] = nil
    -- 矢量改向是生成器，用掉后从手牌移除
    gameState_.usedCards.vector_direction = true
    cardHandDirty_ = true
    UpdateCardResetButton()
    SetCardFeedback(card.name .. "方向卡已加入手牌，请拖到一个发光的矢量上。", { 98, 220, 139, 255 })
    print("[Tower2D] Direction card picked: " .. cardId)
end

ProcessPendingCardUIActions = function()
    if directionPicker_.pendingReset then
        directionPicker_.pendingReset = false
        directionPicker_.pendingOpen = false
        directionPicker_.pendingCardId = nil
        directionPicker_.pendingCancel = false
        ResetGravityLetterCards(false)
        return
    end

    if directionPicker_.pendingCardId ~= nil then
        local cardId = directionPicker_.pendingCardId
        directionPicker_.pendingCardId = nil
        directionPicker_.pendingCancel = false
        PickDirectionCard(cardId)
        return
    end

    if directionPicker_.pendingCancel then
        directionPicker_.pendingCancel = false
        CloseDirectionPicker()
        SetCardFeedback("已取消方向选择。", { 245, 205, 96, 255 })
        return
    end

    if directionPicker_.pendingOpen then
        directionPicker_.pendingOpen = false
        OpenDirectionPicker()
    end
end

-- 应用重力方向（由方向卡拖到 g 上触发）
ApplyDirectionCard = function(card)
    local direction = card.direction
    if direction == nil then return end
    local target = GetGravityLetterCardTarget()
    if target == nil then return end

    local actionValue = target.actionValue or 0
    local spent = GetObjectCardCost("gravity_letter", true)
    local cost = card.cost or 0
    if spent + cost > actionValue then
        SetCardFeedback(
            string.format("行动点不足：%d + %d > %d。", spent, cost, actionValue),
            { 232, 112, 96, 255 }
        )
        return
    end

    local applied = gameState_.objectCards.gravity_letter or {}
    gameState_.objectCards.gravity_letter = applied
    table.insert(applied, card.id)
    gameState_.usedCards[card.id] = true
    gameState_.objectActionSpent.gravity_letter = GetObjectCardCost("gravity_letter", false)

    gravityLetter_.vectorDirection = direction
    gravityLetter_.vectorCardApplied = true
    if direction == "right" then gravityLetter_.horizontalTravelSign = 1 end
    if direction == "left" then gravityLetter_.horizontalTravelSign = -1 end
    gravityLetter_.velocityX = 0.0
    gravityLetter_.velocityY = direction == "down" and 0.06 or 0.0

    gameState_.solvedObjects.gravity_letter =
        gameState_.objectActionSpent.gravity_letter >= actionValue
    cardHandDirty_ = true
    UpdateCardResetButton()

    local directionName = ({ up = "上", down = "下", left = "左", right = "右" })[direction]
    SetCardFeedback("g 已改为向" .. directionName .. "。", { 98, 220, 139, 255 })
    print("[Tower2D] Direction applied: " .. direction)
end

-- 应用 F=MG（拖到信封上触发）
ApplyGravityFormula = function(card)
    local target = GetGravityLetterCardTarget()
    if target == nil then return end

    local actionValue = target.actionValue or 0
    local spent = GetObjectCardCost("gravity_letter", true)
    local cost = card.cost or 0
    if spent + cost > actionValue then
        SetCardFeedback(
            string.format("行动点不足：%d + %d > %d。", spent, cost, actionValue),
            { 232, 112, 96, 255 }
        )
        return
    end
    if not CardIsAccepted(target, card.id) then
        SetCardFeedback(card.name .. "无法作用于这个物体。", { 232, 112, 96, 255 })
        return
    end

    local applied = gameState_.objectCards.gravity_letter or {}
    gameState_.objectCards.gravity_letter = applied
    table.insert(applied, card.id)
    gameState_.usedCards[card.id] = true
    gameState_.objectActionSpent.gravity_letter = GetObjectCardCost("gravity_letter", false)

    gravityLetter_.gravityEnabled = true
    formulaOverlay_.visible = true
    cardHandDirty_ = true
    UpdateCardResetButton()

    SetCardFeedback("F = m·g 已刻在信封上。拖动方向卡时，可改变的矢量会发光。", { 98, 220, 139, 255 })
    print("[Tower2D] Gravity formula applied")
end

-- 撤销/重置：卡牌返还手牌，信封恢复初始运动状态
ResetGravityLetterCards = function(silent)
    if gravityLetter_.collected or prologue_.invitationCollected then
        if not silent then
            SetCardFeedback("邀请函已经收取，效果不能再重置。", { 245, 205, 96, 255 })
        end
        return
    end

    local hasDirectionCard = false
    for _, cardId in ipairs(DIRECTION_CARD_ORDER) do
        if gameState_.ownedCards[cardId] then
            hasDirectionCard = true
            break
        end
    end
    local hadAnything = directionPicker_.open
        or (gameState_.objectCards.gravity_letter ~= nil)
        or gravityLetter_.gravityEnabled
        or gameState_.usedCards.vector_direction
        or hasDirectionCard

    CloseDirectionPicker()

    for _, cardId in ipairs(gameState_.objectCards.gravity_letter or {}) do
        gameState_.usedCards[cardId] = nil
        gameState_.cardBindings[cardId] = nil
    end
    for cardId, stagedObjectId in pairs(gameState_.stagedCards) do
        if stagedObjectId == "gravity_letter" then
            gameState_.stagedCards[cardId] = nil
            gameState_.cardBindings[cardId] = nil
        end
    end
    gameState_.objectCards.gravity_letter = nil
    gameState_.objectActionSpent.gravity_letter = nil
    gameState_.solvedObjects.gravity_letter = nil

    -- 方向卡由矢量改向生成；重置时收回方向卡并返还生成器
    for _, cardId in ipairs(DIRECTION_CARD_ORDER) do
        gameState_.ownedCards[cardId] = nil
        gameState_.usedCards[cardId] = nil
    end
    if hasDirectionCard or gameState_.usedCards.vector_direction then
        gameState_.usedCards.vector_direction = nil
        gameState_.ownedCards.vector_direction = true
    end

    gravityLetter_.active = true
    gravityLetter_.fallen = false
    gravityLetter_.collectible = false
    gravityLetter_.gravityEnabled = false
    gravityLetter_.vectorCardApplied = false
    gravityLetter_.vectorDirection = "right"
    gravityLetter_.horizontalTravelSign = 1
    gravityLetter_.x = gravityLetter_.startX
    gravityLetter_.y = gravityLetter_.startY
    gravityLetter_.velocityX = 0.0
    gravityLetter_.velocityY = 0.0
    gravityLetter_.timeScale = 1.0
    gravityLetter_.frozen = false
    gravityLetter_.targetLocked = false
    formulaOverlay_.visible = false
    formulaOverlay_.gGlow = 0.0

    cardHandDirty_ = true
    UpdateCardResetButton()
    if not silent and hadAnything then
        SetCardFeedback("已重置：卡牌返还，信封恢复初始运动。", { 255, 217, 61, 255 })
    end
    print("[Tower2D] Gravity letter cards reset")
end

ResolveCardDrop = function(card, physicalX, physicalY)
    if card == nil then return end
    if not firstPerson_.active or firstPerson_.room == nil then
        SetCardFeedback("卡牌只能在谜室中使用。", { 232, 112, 96, 255 })
        return
    end
    if not gameState_.ownedCards[card.id] then
        SetCardFeedback("你还没有获得这张卡牌。", { 232, 112, 96, 255 })
        return
    end

    -- 矢量改向：脱手释放后，下一帧展开四张方向卡
    if card.generator then
        directionPicker_.pendingOpen = true
        return
    end

    local logicalX = physicalX / dpr_
    local logicalY = physicalY / dpr_

    -- 方向卡：必须落在公式的 g 上
    if card.parameterCard then
        if not formulaOverlay_.visible then
            SetCardFeedback("当前场景里还没有可修改的矢量。", { 232, 112, 96, 255 })
            return
        end
        local onG = logicalX >= formulaOverlay_.gx
            and logicalX <= formulaOverlay_.gx + formulaOverlay_.gw
            and logicalY >= formulaOverlay_.gy
            and logicalY <= formulaOverlay_.gy + formulaOverlay_.gh
        if not onG then
            SetCardFeedback("请放到发光的矢量上。", { 232, 112, 96, 255 })
            return
        end
        if gameState_.usedCards[card.id] then
            SetCardFeedback("这张方向卡已经用过了。", { 232, 112, 96, 255 })
            return
        end
        ApplyDirectionCard(card)
        return
    end

    -- 基础法则卡：必须落在信封上
    local lx, ly, lw, lh = GetGravityLetterLogicalRect()
    local onLetter = gravityLetter_.active
        and logicalX >= lx and logicalX <= lx + lw
        and logicalY >= ly and logicalY <= ly + lh
    if not onLetter then
        SetCardFeedback("把卡牌拖到发光的交互物上。", { 232, 112, 96, 255 })
        return
    end
    if gameState_.usedCards[card.id] then
        SetCardFeedback("这张卡牌已经使用过了。", { 232, 112, 96, 255 })
        return
    end
    if card.id == "gravity_formula" then
        if gravityLetter_.gravityEnabled then
            SetCardFeedback("信封已经在响应 g 了。", { 245, 205, 96, 255 })
            return
        end
        ApplyGravityFormula(card)
        return
    end

    SetCardFeedback(card.name .. "无法作用于这个物体。", { 232, 112, 96, 255 })
end

local CARD_WIDTH = 124
local CARD_HEIGHT = 158

local function CreateCardWidget(card, restStyle)
    local cardWidget
    cardWidget = UI.Card {
        position = "absolute",
        left = restStyle.left,
        top = restStyle.top,
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        rotate = restStyle.rotate,
        scale = restStyle.scale,
        translateY = restStyle.translateY,
        zIndex = restStyle.zIndex,
        flexShrink = 0,
        padding = 9,
        gap = 5,
        overflow = "visible",
        backgroundColor = { 24, 31, 61, 252 },
        borderWidth = 3,
        borderColor = card.accent,
        boxShadow = { { x = 5, y = 7, blur = 0, color = { 0, 0, 0, 125 } } },
        transition = "scale 0.12 ease-out, translateY 0.12 ease-out, rotate 0.12 ease-out, opacity 0.1 linear",
        onPointerEnter = function(event, widget)
            if not cardDrag_.active then SetCardHoverStyle(widget, card) end
        end,
        onPointerLeave = function(event, widget)
            if not cardDrag_.active then
                SetCardRestStyle(widget, restStyle)
                HideCardTooltip()
            end
        end,
        onPointerDown = function(event, widget)
            if cardDrag_.active or not event:IsPrimaryAction() then return end
            local physicalX, physicalY = GetPhysicalPointerPosition()
            BeginCardDrag(card, widget, physicalX, physicalY)
            cardDrag_.pointerId = event.pointerId
            event:StopPropagation()
            event:PreventDefault()
        end,
        onPointerMove = function(event, widget)
            if not cardDrag_.active or cardDrag_.pointerId ~= event.pointerId then return end
            local physicalX, physicalY = GetPhysicalPointerPosition()
            local uiX, uiY = PhysicalToUIPointer(physicalX, physicalY)
            cardDrag_.x = physicalX
            cardDrag_.y = physicalY
            UpdateCardDragGhost(uiX, uiY)
            event:PreventDefault()
        end,
        onPointerUp = function(event, widget)
            if not cardDrag_.active or cardDrag_.pointerId ~= event.pointerId then return end
            local physicalX, physicalY = GetPhysicalPointerPosition()
            local droppedCard = cardDrag_.card
            CancelCardDrag()
            ResolveCardDrop(droppedCard, physicalX, physicalY)
            event:StopPropagation()
            event:PreventDefault()
        end,
        children = {
            UI.Label {
                text = card.type,
                fontSize = 8,
                fontWeight = "bold",
                fontColor = card.accent,
                alignSelf = "flex-end",
                pointerEvents = "none",
            },
            UI.Panel {
                height = 54,
                alignItems = "center",
                justifyContent = "center",
                backgroundColor = { card.accent[1], card.accent[2], card.accent[3], 38 },
                borderWidth = 2,
                borderColor = card.accent,
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "◆",
                        fontSize = 24,
                        fontWeight = "bold",
                        fontColor = card.accent,
                        pointerEvents = "none",
                    },
                },
            },
            UI.Label {
                text = "费用 " .. tostring(card.cost or 0),
                fontSize = 8,
                fontWeight = "bold",
                fontColor = { 255, 217, 61, 255 },
                pointerEvents = "none",
            },
            UI.Label {
                text = card.name,
                fontSize = 11,
                fontWeight = "bold",
                fontColor = { 255, 245, 214, 255 },
                textAlign = "center",
                whiteSpace = "normal",
                pointerEvents = "none",
            },
        },
    }
    return cardWidget
end

local HAND_SPANS_BY_COUNT = {
    0,
    12,
    22,
    30,
    38,
    46,
    54,
    60,
    66,
    72,
}

local function CalculateCardFanLayout(cardCount, screenWidth)
    local layouts = {}
    if cardCount <= 0 then return layouts end

    local safeCount = math.max(1, math.min(10, cardCount))
    local totalSpan = HAND_SPANS_BY_COUNT[safeCount]
    local halfSpanRadians = math.rad(totalSpan * 0.5)
    local cardScale = 1.0
    if safeCount >= 7 then
        cardScale = math.max(0.86, 1.0 - (safeCount - 6) * 0.035)
    end

    local radius = 360
    if totalSpan > 0 then
        local horizontalMargin = math.max(56, screenWidth * 0.08)
        local availableHalfWidth = math.max(
            150,
            (screenWidth - horizontalMargin * 2 - CARD_WIDTH * cardScale) * 0.5
        )
        radius = math.min(radius, availableHalfWidth / math.sin(halfSpanRadians))
    end
    radius = math.max(245, radius)

    local centerX = screenWidth * 0.5
    local centerCardY = 88
    local circleCenterY = centerCardY + radius
    local angleStep = safeCount > 1 and totalSpan / (safeCount - 1) or 0

    for index = 1, safeCount do
        local angleDegrees = safeCount > 1
            and (-totalSpan * 0.5 + (index - 1) * angleStep)
            or 0
        local angleRadians = math.rad(angleDegrees)
        local cardCenterX = centerX + radius * math.sin(angleRadians)
        local cardCenterY = circleCenterY - radius * math.cos(angleRadians)
        layouts[index] = {
            left = cardCenterX - CARD_WIDTH * 0.5,
            top = cardCenterY - CARD_HEIGHT * 0.5,
            rotate = angleDegrees,
            translateY = 0,
            scale = cardScale,
            zIndex = index,
            radius = radius,
            circleCenterX = centerX,
            circleCenterY = circleCenterY,
        }
    end
    return layouts
end

RebuildCardHand = function()
    if cardHandPanel_ == nil then return end
    cardHandPanel_:ClearChildren()
    cardWidgets_ = {}
    cardRestStyles_ = {}
    local visibleCards = {}
    for _, card in ipairs(CARD_DEFINITIONS) do
        if gameState_.ownedCards[card.id]
            and not gameState_.usedCards[card.id]
            and gameState_.stagedCards[card.id] == nil then
            table.insert(visibleCards, card)
        end
    end

    local layouts = CalculateCardFanLayout(#visibleCards, UI.GetWidth())
    for index, card in ipairs(visibleCards) do
        local restStyle = layouts[index]
        local widget = CreateCardWidget(card, restStyle)
        cardHandPanel_:AddChild(widget)
        cardWidgets_[card.id] = widget
        cardRestStyles_[card.id] = restStyle
    end
    if #visibleCards > 0 then
        local sample = layouts[1]
        print(string.format(
            "[Tower2D] Card fan: count=%d radius=%.1f center=(%.1f, %.1f)",
            #visibleCards,
            sample.radius,
            sample.circleCenterX,
            sample.circleCenterY
        ))
    end
    cardHandDirty_ = false
end

local function BuildUI()
    local function NavigateFirstPerson(direction)
        if not firstPerson_.active or firstPerson_.room == nil then return end
        local view = firstPerson_.room.views[firstPerson_.viewId]
        local target = view[direction]
        if target ~= nil then SwitchFirstPersonView(target) end
    end

    locationLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontWeight = "bold",
        fontColor = { 255, 217, 61, 255 },
        textStroke = { width = 2, color = { 15, 15, 35, 255 } },
    }

    inventoryLabel_ = UI.Label {
        text = "背包：空",
        fontSize = 10,
        fontColor = { 240, 240, 240, 255 },
        whiteSpace = "normal",
    }

    modeHintLabel_ = UI.Label {
        text = "方向键 / WASD 移动  ·  E / 空格 调查",
        fontSize = 9,
        fontColor = { 200, 200, 220, 255 },
    }

    questLabel_ = UI.Label {
        text = Prologue.GetQuestText(prologue_),
        fontSize = 11,
        fontWeight = "bold",
        lineHeight = 1.45,
        whiteSpace = "normal",
        fontColor = { 255, 217, 61, 255 },
    }

    portraitPanel_ = UI.Panel {
        width = 108,
        height = 108,
        flexShrink = 0,
        backgroundColor = { 15, 15, 35, 255 },
        backgroundFit = "contain",
        borderWidth = 3,
        borderColor = { 108, 92, 231, 255 },
        pointerEvents = "none",
    }

    nameLabel_ = UI.Label {
        text = "",
        fontSize = 14,
        fontWeight = "bold",
        fontColor = { 33, 189, 174, 255 },
    }

    dialogueLabel_ = UI.Label {
        text = "",
        marginTop = 10,
        fontSize = 12,
        lineHeight = 1.55,
        whiteSpace = "normal",
        flexShrink = 1,
        fontColor = { 240, 240, 240, 255 },
    }

    continueLabel_ = UI.Label {
        text = "▼",
        position = "absolute",
        right = 16,
        bottom = 10,
        fontSize = 11,
        fontColor = { 255, 217, 61, 255 },
        visible = false,
    }

    dialogPanel_ = UI.Panel {
        position = "absolute",
        left = "8%",
        right = "8%",
        bottom = 28,
        minHeight = 152,
        padding = 14,
        flexDirection = "row",
        gap = 16,
        backgroundColor = { 15, 15, 35, 245 },
        borderWidth = 4,
        borderColor = { 240, 240, 240, 255 },
        zIndex = 100,
        pointerEvents = "auto",
        visible = false,
        children = {
            portraitPanel_,
            UI.Panel {
                flexGrow = 1,
                flexShrink = 1,
                paddingTop = 3,
                children = { nameLabel_, dialogueLabel_, continueLabel_ },
            },
        },
    }

    transitionOverlay_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        backgroundColor = { 0, 0, 0, 0 },
        zIndex = 1000,
        pointerEvents = "auto",
        visible = false,
    }

    titleLayer_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        backgroundImage = "image/edited_牛顿牌正式开场封面_20260801070431.png",
        backgroundFit = "cover",
        pointerEvents = "none",
    }

    introSpeakerLabel_ = UI.Label {
        text = "",
        fontSize = 14,
        fontWeight = "bold",
        fontColor = { 33, 189, 174, 255 },
    }

    introLineLabel_ = UI.Label {
        text = "",
        marginTop = 10,
        fontSize = 12,
        lineHeight = 1.55,
        whiteSpace = "normal",
        flexShrink = 1,
        fontColor = { 240, 240, 240, 255 },
    }

    introLayer_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        backgroundColor = { 0, 0, 0, 255 },
        pointerEvents = "none",
        visible = false,
        children = {
            UI.Panel {
                position = "absolute",
                left = "8%",
                right = "8%",
                bottom = 28,
                minHeight = 152,
                padding = 14,
                flexDirection = "row",
                gap = 16,
                backgroundColor = { 15, 15, 35, 245 },
                borderWidth = 4,
                borderColor = { 240, 240, 240, 255 },
                pointerEvents = "none",
                children = {
                    UI.Panel {
                        width = 108,
                        height = 108,
                        flexShrink = 0,
                        backgroundColor = { 15, 15, 35, 255 },
                        backgroundImage = "image/母亲塞拉像素头像_20260727072703.png",
                        backgroundFit = "contain",
                        borderWidth = 3,
                        borderColor = { 108, 92, 231, 255 },
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        flexGrow = 1,
                        flexShrink = 1,
                        paddingTop = 3,
                        children = {
                            introSpeakerLabel_,
                            introLineLabel_,
                            UI.Label {
                                text = "▼",
                                position = "absolute",
                                right = 16,
                                bottom = 10,
                                fontSize = 11,
                                fontColor = { 255, 217, 61, 255 },
                            },
                        },
                    },
                },
            },
        },
    }

    openingPanel_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        zIndex = 2000,
        pointerEvents = "auto",
        children = { titleLayer_, introLayer_ },
    }

    overworldControls_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        pointerEvents = "box-none",
        children = {
            CreateMoveButton("▲", 68, 104, "up"),
            CreateMoveButton("◀", 20, 56, "left"),
            CreateMoveButton("▼", 68, 56, "down"),
            CreateMoveButton("▶", 116, 56, "right"),
            UI.Button {
                text = "调查",
                position = "absolute",
                right = 26,
                bottom = 64,
                width = 70,
                height = 58,
                variant = "primary",
                onClick = function()
                    AdvanceDialogueOrInteract()
                end,
            },
        },
    }

    firstPersonViewLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontWeight = "bold",
        fontColor = { 240, 220, 180, 255 },
        textStroke = { width = 2, color = { 8, 8, 12, 255 } },
    }

    cardFeedbackLabel_ = UI.Label {
        text = "",
        position = "absolute",
        left = "31%",
        right = "31%",
        bottom = 176,
        paddingHorizontal = 12,
        paddingVertical = 7,
        fontSize = 10,
        fontWeight = "bold",
        textAlign = "center",
        backgroundColor = { 8, 8, 12, 224 },
        borderWidth = 2,
        borderColor = { 174, 135, 73, 255 },
        pointerEvents = "none",
        zIndex = 94,
        visible = false,
    }

    cardHandPanel_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        bottom = 0,
        height = 220,
        overflow = "visible",
        pointerEvents = "box-none",
        zIndex = 92,
        visible = false,
    }

    cardTooltipNameLabel_ = UI.Label {
        text = "",
        fontSize = 11,
        fontWeight = "bold",
        fontColor = { 34, 23, 20, 255 },
        textAlign = "center",
    }

    cardTooltipDescriptionLabel_ = UI.Label {
        text = "",
        fontSize = 9,
        fontColor = { 34, 23, 20, 255 },
        whiteSpace = "normal",
        textAlign = "center",
    }

    cardTooltipPanel_ = UI.Panel {
        position = "absolute",
        left = "34%",
        right = "34%",
        bottom = 190,
        minHeight = 58,
        paddingHorizontal = 12,
        paddingVertical = 8,
        gap = 4,
        alignItems = "center",
        backgroundColor = { 254, 160, 2, 248 },
        borderWidth = 2,
        borderColor = { 249, 95, 3, 255 },
        boxShadow = { { x = 6, y = 6, blur = 0, color = { 0, 0, 0, 100 } } },
        pointerEvents = "none",
        zIndex = 240,
        visible = false,
        children = { cardTooltipNameLabel_, cardTooltipDescriptionLabel_ },
    }

    cardDragNameLabel_ = UI.Label {
        text = "",
        fontSize = 11,
        fontWeight = "bold",
        fontColor = { 248, 236, 206, 255 },
        textAlign = "center",
    }

    cardDragTypeLabel_ = UI.Label {
        text = "",
        fontSize = 8,
        fontColor = { 219, 176, 98, 255 },
        textAlign = "center",
    }

    cardDragGhost_ = UI.Card {
        position = "absolute",
        left = 0,
        top = 0,
        width = 116,
        height = 148,
        padding = 10,
        gap = 10,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 27, 27, 58, 244 },
        borderWidth = 3,
        borderColor = { 219, 176, 98, 255 },
        boxShadow = {
            { x = 6, y = 8, blur = 0, color = { 0, 0, 0, 105 } },
        },
        scale = 1.08,
        opacity = 0.94,
        pointerEvents = "none",
        zIndex = 900,
        visible = false,
        children = {
            UI.Label {
                text = "◆",
                fontSize = 23,
                fontColor = { 245, 205, 96, 255 },
            },
            cardDragNameLabel_,
            cardDragTypeLabel_,
        },
    }

    -- 方向卡选择层：矢量改向脱手后展开四张方向卡
    local function CreateDirectionPickCard(cardId)
        local card = GetCardDefinition(cardId)
        local glyph = ({ up = "↑", down = "↓", left = "←", right = "→" })[card.direction]
        local label = ({ up = "上", down = "下", left = "左", right = "右" })[card.direction]
        return UI.Card {
            width = 124,
            height = 158,
            padding = 9,
            gap = 6,
            alignItems = "center",
            justifyContent = "center",
            backgroundColor = { 24, 31, 61, 252 },
            borderWidth = 3,
            borderColor = card.accent,
            boxShadow = { { x = 5, y = 7, blur = 0, color = { 0, 0, 0, 125 } } },
            transition = "scale 0.12 ease-out, translateY 0.12 ease-out",
            pointerEvents = "auto",
            clickable = true,
            hoverable = true,
            onPointerEnter = function(event, widget)
                widget:SetStyle({ scale = 1.12, translateY = -14 })
            end,
            onPointerLeave = function(event, widget)
                widget:SetStyle({ scale = 1.0, translateY = 0 })
            end,
            onClick = function()
                directionPicker_.pendingCardId = cardId
            end,
            children = {
                UI.Label {
                    text = "矢量方向",
                    fontSize = 8,
                    fontWeight = "bold",
                    fontColor = card.accent,
                    pointerEvents = "none",
                },
                UI.Panel {
                    width = 62,
                    height = 62,
                    alignItems = "center",
                    justifyContent = "center",
                    backgroundColor = { card.accent[1], card.accent[2], card.accent[3], 46 },
                    borderWidth = 2,
                    borderColor = card.accent,
                    pointerEvents = "none",
                    children = {
                        UI.Label {
                            text = glyph,
                            fontSize = 30,
                            fontWeight = "bold",
                            fontColor = { 255, 245, 214, 255 },
                            pointerEvents = "none",
                        },
                    },
                },
                UI.Label {
                    text = "方向：" .. label,
                    fontSize = 12,
                    fontWeight = "bold",
                    fontColor = { 255, 245, 214, 255 },
                    pointerEvents = "none",
                },
                UI.Label {
                    text = "费用 2",
                    fontSize = 8,
                    fontWeight = "bold",
                    fontColor = { 255, 217, 61, 255 },
                    pointerEvents = "none",
                },
            },
        }
    end

    directionPickerLayer_ = UI.Panel {
        position = "absolute",
        left = 0,
        top = 0,
        right = 0,
        bottom = 0,
        alignItems = "center",
        justifyContent = "center",
        gap = 18,
        backgroundColor = { 6, 8, 20, 208 },
        pointerEvents = "box-none",
        zIndex = 460,
        visible = false,
        children = {
            -- 独立空白点击区：不再依赖祖先 onClick，避免方向卡点击冒泡时关闭选择层
            UI.Button {
                text = "",
                position = "absolute",
                left = 0,
                top = 0,
                width = "100%",
                height = "100%",
                padding = 0,
                backgroundColor = { 0, 0, 0, 0 },
                borderWidth = 0,
                zIndex = 1,
                onClick = function()
                    directionPicker_.pendingCancel = true
                end,
            },
            UI.Panel {
                width = "100%",
                alignItems = "center",
                gap = 18,
                pointerEvents = "box-none",
                zIndex = 2,
                children = {
                    UI.Label {
                        text = "选择一张方向卡",
                        fontSize = 16,
                        fontWeight = "bold",
                        fontColor = { 255, 217, 61, 255 },
                        pointerEvents = "none",
                    },
                    UI.Label {
                        text = "方向卡不会预先绑定变量；加入手牌后，拖到任意发光的矢量上生效",
                        fontSize = 10,
                        fontColor = { 200, 200, 224, 255 },
                        pointerEvents = "none",
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = 14,
                        pointerEvents = "box-none",
                        children = {
                            CreateDirectionPickCard("vector_up"),
                            CreateDirectionPickCard("vector_down"),
                            CreateDirectionPickCard("vector_left"),
                            CreateDirectionPickCard("vector_right"),
                        },
                    },
                    UI.Label {
                        text = "点击空白处取消",
                        fontSize = 9,
                        fontColor = { 160, 160, 192, 255 },
                        pointerEvents = "none",
                    },
                },
            },
        },
    }

    cardResetButton_ = UI.Button {
        text = "重置卡牌效果",
        position = "absolute",
        right = 24,
        top = 74,
        width = 142,
        height = 40,
        fontSize = 10,
        backgroundColor = { 108, 45, 73, 245 },
        borderColor = { 239, 108, 128, 255 },
        zIndex = 980,
        visible = false,
        onClick = function()
            directionPicker_.pendingReset = true
        end,
    }

    firstPersonLeftButton_ = UI.Button {
        text = "<",
        position = "absolute",
        left = 24,
        top = "43%",
        width = 62,
        height = 70,
        fontSize = 22,
        onClick = function() NavigateFirstPerson("left") end,
    }

    firstPersonRightButton_ = UI.Button {
        text = ">",
        position = "absolute",
        right = 24,
        top = "43%",
        width = 62,
        height = 70,
        fontSize = 22,
        onClick = function() NavigateFirstPerson("right") end,
    }

    firstPersonUpButton_ = UI.Button {
        text = "^",
        position = "absolute",
        left = "47%",
        top = 68,
        width = 68,
        height = 54,
        onClick = function() NavigateFirstPerson("up") end,
    }

    firstPersonDownButton_ = UI.Button {
        text = "v",
        position = "absolute",
        left = "47%",
        bottom = 26,
        width = 68,
        height = 54,
        onClick = function() NavigateFirstPerson("down") end,
    }

    firstPersonControls_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        pointerEvents = "box-none",
        zIndex = 80,
        visible = false,
        children = {
            UI.Panel {
                position = "absolute",
                left = "38%",
                right = "38%",
                top = 18,
                alignItems = "center",
                paddingHorizontal = 12,
                paddingVertical = 8,
                backgroundColor = { 8, 8, 12, 205 },
                borderWidth = 2,
                borderColor = { 174, 135, 73, 255 },
                pointerEvents = "none",
                children = { firstPersonViewLabel_ },
            },
            firstPersonLeftButton_,
            firstPersonRightButton_,
            firstPersonUpButton_,
            firstPersonDownButton_,
            UI.Button {
                text = "调查",
                position = "absolute",
                right = 28,
                bottom = 26,
                width = 82,
                height = 54,
                variant = "primary",
                onClick = function() AdvanceDialogueOrInteract() end,
            },
            UI.Button {
                text = "离开",
                position = "absolute",
                left = 28,
                bottom = 26,
                width = 78,
                height = 48,
                onClick = function() ExitFirstPersonRoom() end,
            },
        },
    }

    birthdayLetterLayer_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 0, 0, 0, 155 },
        pointerEvents = "auto",
        zIndex = 520,
        visible = false,
        children = {
            UI.Panel {
                width = "56%",
                minHeight = 360,
                padding = 28,
                gap = 16,
                alignItems = "center",
                backgroundColor = { 240, 219, 172, 255 },
                borderWidth = 4,
                borderColor = { 92, 60, 39, 255 },
                boxShadow = { { x = 8, y = 8, blur = 0, color = { 0, 0, 0, 145 } } },
                children = {
                    UI.Label {
                        text = "教皇的礼物",
                        fontSize = 18,
                        fontWeight = "bold",
                        fontColor = { 83, 45, 31, 255 },
                        textAlign = "center",
                    },
                    UI.Panel {
                        width = "86%",
                        height = 3,
                        backgroundColor = { 154, 103, 58, 255 },
                    },
                    UI.Label {
                        text = "生日快乐！",
                        fontSize = 17,
                        fontWeight = "bold",
                        fontColor = { 132, 55, 41, 255 },
                        textAlign = "center",
                    },
                    UI.Label {
                        text = "我为你准备了两张礼物卡。\n黄色 F=MG 能让物体响应重力矢量，\n紫色矢量改向卡则能改变 g 的方向。\n希望它们能帮你拿到窗台上的邀请函。",
                        width = "88%",
                        fontSize = 12,
                        lineHeight = 1.65,
                        whiteSpace = "normal",
                        textAlign = "center",
                        fontColor = { 61, 43, 36, 255 },
                    },
                    UI.Label {
                        text = "—— 教皇",
                        width = "86%",
                        fontSize = 11,
                        fontWeight = "bold",
                        textAlign = "right",
                        fontColor = { 92, 60, 39, 255 },
                    },
                    UI.Button {
                        text = "收下两张卡",
                        width = 180,
                        height = 44,
                        variant = "primary",
                        onClick = function()
                            birthdayLetterOpen_ = false
                            birthdayLetterLayer_:Hide()
                        end,
                    },
                },
            },
        },
    }

    cardTutorialLayer_ = UI.Panel {
        position = "absolute",
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
        alignItems = "center",
        justifyContent = "center",
        backgroundColor = { 0, 0, 0, 135 },
        pointerEvents = "auto",
        zIndex = 500,
        visible = false,
        children = {
            UI.Panel {
                width = "48%",
                minHeight = 270,
                padding = 24,
                gap = 14,
                alignItems = "center",
                backgroundColor = { 15, 15, 35, 250 },
                borderWidth = 4,
                borderColor = { 33, 189, 174, 255 },
                boxShadow = { { x = 8, y = 8, blur = 0, color = { 0, 0, 0, 155 } } },
                children = {
                    UI.Label {
                        text = "卡牌教学",
                        fontSize = 18,
                        fontWeight = "bold",
                        fontColor = { 255, 217, 61, 255 },
                    },
                    UI.Label {
                        text = "先点击邀请函，将黄色 F=MG 拖入法则卡槽。\n公式生效后，点击卡槽内 F=MG 的矢量参数 g。\n再把紫色矢量改向卡拖到 g 上，选择 ↓ 让信封落下。",
                        width = "92%",
                        fontSize = 13,
                        lineHeight = 1.55,
                        whiteSpace = "normal",
                        textAlign = "center",
                        fontColor = { 240, 240, 240, 255 },
                    },
                    UI.Panel {
                        width = "88%",
                        padding = 12,
                        backgroundColor = { 27, 27, 58, 255 },
                        borderWidth = 2,
                        borderColor = { 108, 92, 231, 255 },
                        children = {
                            UI.Label {
                                text = "信封行动值 3  ·  F=MG 费用 1  ·  矢量改向费用 2\n总费用达到 3 后，方向决定信封的飞行效果。",
                                fontSize = 10,
                                lineHeight = 1.45,
                                whiteSpace = "normal",
                                textAlign = "center",
                                fontColor = { 160, 160, 192, 255 },
                            },
                        },
                    },
                    UI.Button {
                        text = "开始操作",
                        width = 160,
                        height = 44,
                        variant = "primary",
                        onClick = function()
                            cardTutorialOpen_ = false
                            gameState_.cardTutorialSeen = true
                            cardTutorialLayer_:Hide()
                        end,
                    },
                },
            },
        },
    }

    local root = UI.Panel {
        width = "100%",
        height = "100%",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                left = 18,
                top = 18,
                paddingHorizontal = 12,
                paddingVertical = 8,
                backgroundColor = { 15, 15, 35, 220 },
                borderWidth = 2,
                borderColor = { 33, 189, 174, 255 },
                pointerEvents = "none",
                children = { locationLabel_ },
            },
            UI.Panel {
                position = "absolute",
                right = 18,
                top = 18,
                minWidth = 230,
                paddingHorizontal = 10,
                paddingVertical = 7,
                gap = 5,
                backgroundColor = { 15, 15, 35, 210 },
                borderWidth = 2,
                borderColor = { 108, 92, 231, 255 },
                pointerEvents = "none",
                children = {
                    questLabel_,
                    modeHintLabel_,
                    inventoryLabel_,
                },
            },
            overworldControls_,
            firstPersonControls_,
            cardHandPanel_,
            directionPickerLayer_,
            cardResetButton_,
            cardFeedbackLabel_,
            cardTooltipPanel_,
            cardDragGhost_,
            dialogPanel_,
            cardTutorialLayer_,
            birthdayLetterLayer_,
            transitionOverlay_,
            openingPanel_,
        },
    }

    UI.SetRoot(root, true)
end

ShowBirthdayLetter = function()
    if birthdayLetterLayer_ == nil then return end
    birthdayLetterOpen_ = true
    birthdayLetterLayer_:Show()
end

ShowCardTutorial = function()
    if cardTutorialLayer_ == nil or gameState_.cardTutorialSeen then return end
    cardTutorialOpen_ = true
    cardTutorialLayer_:Show()
end

UpdateInventoryHUD = function()
    local entries = {}
    for itemId, item in pairs(gameState_.inventory) do
        table.insert(entries, item.name .. " ×" .. tostring(item.amount))
    end
    table.sort(entries)
    if #entries == 0 then
        inventoryLabel_:SetText("背包：空")
    else
        inventoryLabel_:SetText("背包：" .. table.concat(entries, "  ·  "))
    end
end

UpdateWorldScale = function()
    if currentMap_ == nil then return end

    if currentMap_.backgroundImage ~= nil then
        local fitX = logicalW_ / currentMap_.width
        local fitY = logicalH_ / currentMap_.height
        TILE = math.floor(math.max(48, math.min(96, fitX, fitY)))
        actorScale_ = TILE / 40
    elseif currentMap_.id == "village" then
        TILE = math.floor(math.max(44, math.min(58, logicalH_ / 12.5)))
        actorScale_ = TILE / 40
    else
        local targetWidth = logicalW_ * 0.84
        local targetHeight = logicalH_ * 1.04
        TILE = math.floor(math.max(
            56,
            math.min(84, targetWidth / 10.5, targetHeight / 8.6)
        ))
        actorScale_ = TILE / 40
    end
end

local function PlayBGM(path)
    if bgmSoundSource_ == nil or currentBgmPath_ == path then return end

    local sound = cache:GetResource("Sound", path)
    if sound == nil then
        print("[Tower2D] BGM resource missing: " .. path)
        return
    end

    sound:SetLooped(true)
    bgmSoundSource_:Stop()
    bgmSoundSource_:SetGain(0.42)
    bgmSoundSource_:Play(sound)
    currentBgmPath_ = path
    print("[Tower2D] BGM: " .. path)
end

local function BGMPathForMap(mapId)
    if mapId == "tower_floor1" then
        return "audio/music_1785678380652.ogg"
    end
    if mapId == "home_upper" or mapId == "home_lower" then
        return "audio/bgm_prologue_home.ogg"
    end
    return "audio/bgm_town.ogg"
end

UpdateQuestHUD = function()
    if questLabel_ ~= nil then
        questLabel_:SetText(Prologue.GetQuestText(prologue_))
    end
end

local function BeginPrologueOpening()
    if not Prologue.Begin(prologue_) then return end
    titleLayer_:Hide()
    introLayer_:Show()
    introLayer_:SetOpacity(1.0)
    PlayBGM("audio/bgm_prologue_home.ogg")
end

local function UpdatePrologueOpening(dt)
    local action = Prologue.Update(prologue_, dt)
    if action == "reveal_home" then
        introSpeakerLabel_:SetText("")
        introLineLabel_:SetText("")
        PlayBGM("audio/bgm_prologue_home.ogg")
    elseif action == "gameplay_started" then
        openingPanel_:Hide()
        overworldControls_:Show()
        UpdateQuestHUD()
    end

    if Prologue.IsIntro(prologue_) then
        local line = Prologue.GetIntroLine(prologue_)
        local alpha = Prologue.GetIntroLineAlpha(prologue_)
        introSpeakerLabel_:SetText(line.speaker)
        introLineLabel_:SetText(line.text)
        introSpeakerLabel_:SetOpacity(alpha)
        introLineLabel_:SetOpacity(alpha)
    elseif prologue_.phase == "reveal" then
        introLayer_:SetOpacity(Prologue.GetRevealAlpha(prologue_))
    end
end

LoadMap = function(id, spawnX, spawnY)
    currentMap_ = Maps.Get(id)
    LoadCollisionEditorData(currentMap_)
    UpdateWorldScale()
    player_.x = spawnX or currentMap_.spawn.x
    player_.y = spawnY or currentMap_.spawn.y
    player_.moving = false
    transitionLock_ = 0.28
    locationLabel_:SetText(currentMap_.name)
    PlayBGM(BGMPathForMap(currentMap_.id))
    print("[Tower2D] Map: " .. currentMap_.id .. " / " .. currentMap_.name)
end

SwitchFirstPersonView = function(viewId)
    if not firstPerson_.active or firstPerson_.room == nil then return end
    local view = firstPerson_.room.views[viewId]
    if view == nil then return end

    firstPerson_.viewId = viewId
    firstPersonViewLabel_:SetText(view.name)
    UpdateCardResetButton()
    print("[Tower2D] First-person view: " .. viewId)
end

EnterFirstPersonRoom = function(portal)
    if portal.roomId == "six_face_room" and not prologue_.motherTalked then
        player_.x = portal.returnX or player_.x
        player_.y = portal.returnY or (player_.y + 1)
        player_.moving = false
        transitionLock_ = 0.45
        OpenHeroMonologue({
            "母亲还在楼下等我。",
            "先去找她吧，窗台房的事待会儿再说。",
        })
        print("[Prologue] Window room locked until mother dialogue")
        return
    end

    if portal.roomId == "six_face_room" and not Prologue.CanEnterInvitationRoom(prologue_) then
        player_.x = portal.returnX or player_.x
        player_.y = portal.returnY or (player_.y + 1)
        player_.moving = false
        transitionLock_ = 0.45
        OpenHeroMonologue({
            "门锁中央有一道卡槽，旁边还刻着 F=MG。",
            "我得先打开二楼那份“教皇的礼物”，拿到法则卡再回来。",
        })
        print("[Prologue] Window room locked until gravity card collected")
        return
    end

    local room = Maps.GetFirstPersonRoom(portal.roomId)
    if room == nil then return end

    firstPerson_.active = true
    firstPerson_.room = room
    firstPerson_.returnMap = portal.returnMap or currentMap_.id
    firstPerson_.returnX = portal.returnX or player_.x
    firstPerson_.returnY = portal.returnY or player_.y
    firstPerson_.returnDirection = portal.returnDirection or player_.direction
    player_.moving = false
    touchMove_ = { up = false, down = false, left = false, right = false }
    input.mouseMode = MM_ABSOLUTE
    overworldControls_:Hide()
    CloseDirectionPicker()
    firstPersonControls_:Show()
    modeHintLabel_:SetText("拖卡到发光目标  ·  方向卡作用于发光矢量  ·  右上角可随时重置  ·  Esc 离开")
    firstPersonLeftButton_:Hide()
    firstPersonRightButton_:Hide()
    firstPersonUpButton_:Hide()
    firstPersonDownButton_:Hide()
    locationLabel_:SetText(room.name)
    SwitchFirstPersonView(room.initialView)
    PlayBGM("audio/bgm_prologue_intro.ogg")
    if cardHandPanel_ ~= nil then
        cardHandPanel_:Hide()
    end
    if cardFeedbackLabel_ ~= nil then
        cardFeedbackLabel_:Hide()
    end
    if cardTooltipPanel_ ~= nil then
        cardTooltipPanel_:Hide()
    end
    CancelCardDrag()
    RebuildCardHand()
    cardHandPanel_:Show()
    UpdateCardResetButton()
    if room.id == "six_face_room" then
        ShowCardTutorial()
    end
    print("[Tower2D] Card hand shown")
    print("[Tower2D] Enter first-person room: " .. room.id)
end

ExitFirstPersonRoom = function()
    if not firstPerson_.active then return end

    local returnMap = firstPerson_.returnMap
    local returnX = firstPerson_.returnX
    local returnY = firstPerson_.returnY
    local returnDirection = firstPerson_.returnDirection
    firstPerson_.active = false
    firstPerson_.room = nil
    gravityLetter_.hovered = false
    CloseDirectionPicker()
    UpdateCardResetButton()
    CancelCardDrag()
    if cardHandPanel_ ~= nil then cardHandPanel_:Hide() end
    if cardFeedbackLabel_ ~= nil then cardFeedbackLabel_:Hide() end
    if cardTooltipPanel_ ~= nil then cardTooltipPanel_:Hide() end
    firstPersonControls_:Hide()
    firstPersonLeftButton_:Show()
    firstPersonRightButton_:Show()
    firstPersonUpButton_:Show()
    firstPersonDownButton_:Show()
    overworldControls_:Show()
    modeHintLabel_:SetText("方向键 / WASD 移动  ·  E / 空格 调查")
    input.mouseMode = MM_ABSOLUTE
    LoadMap(returnMap, returnX, returnY)
    player_.direction = returnDirection
    ResetHeroAnimation()
    print("[Tower2D] Exit first-person room")
end

OpenDialogue = function(target)
    dialog_.open = true
    dialog_.speaker = target
    dialog_.lines = target.lines
    dialog_.index = 1
    dialog_.visibleChars = 0
    dialog_.charTimer = 0.0

    nameLabel_:SetText(target.name or "叙述")
    dialogueLabel_:SetText("")
    continueLabel_:Hide()

    local portrait = target.portrait or "image/新主角勇者立绘_20260731152743.png"
    portraitPanel_:SetStyle({ backgroundImage = portrait, backgroundFit = "contain" })
    if target.hidePortrait then
        portraitPanel_:Hide()
    else
        portraitPanel_:Show()
    end
    dialogPanel_:Show()
    print("[Tower2D] Dialogue: " .. (target.name or "Narrator"))
end

local function CloseDialogue()
    local completedSpeaker = dialog_.speaker
    dialog_.open = false
    dialog_.speaker = nil
    dialogCloseLock_ = 0.20
    dialogPanel_:Hide()

    if completedSpeaker ~= nil and completedSpeaker.showBirthdayLetterAfter then
        ShowBirthdayLetter()
    end

    if completedSpeaker ~= nil and completedSpeaker.id == "mother" then
        if Prologue.CompleteMotherTalk(prologue_) then
            UpdateQuestHUD()
        end
    elseif completedSpeaker ~= nil and completedSpeaker.interaction == "tower_invitation" then
        if Prologue.CollectInvitation(prologue_) then
            gravityLetter_.active = false
            gravityLetter_.collectible = false
            gravityLetter_.collected = true
            gameState_.inventory.tower_invitation = {
                name = "高塔邀请函",
                amount = 1,
            }
            UpdateInventoryHUD()
            UpdateQuestHUD()
            CloseDirectionPicker()
            UpdateCardResetButton()
            SetCardFeedback("已获得高塔邀请函。", { 255, 217, 61, 255 })
        end
    end
end

OpenInvitationDialogue = function()
    if gravityLetter_.collected or prologue_.invitationCollected then
        CloseDirectionPicker()
        SetCardFeedback("邀请函已经收进背包了。", { 245, 205, 96, 255 })
        return
    end
    CloseDirectionPicker()
    OpenDialogue({
        interaction = "tower_invitation",
        name = "高塔邀请函",
        portrait = "image/tower_invitation_letter.png",
        lines = {
            "你拾起盖着教皇火漆的邀请函，厚实纸面上还残留着法则卡的微光。",
            "信封正面写着：致爬塔候选者洛恩。凭此函前往教堂内殿，接受主教祝福。",
            "获得邀请函后，就可以前往教堂见主教了。",
        },
    })
end

function OpenHeroMonologue(lines, name)
    OpenDialogue({
        id = "hero_monologue",
        name = name or "洛恩",
        portrait = "image/主角洛恩像素头像_20260727071202.png",
        lines = lines,
    })
end

local function OpenChest(chest)
    local rewardCardIds = chest.rewardCardIds
        or (chest.rewardCardId ~= nil and { chest.rewardCardId } or nil)
    if gameState_.openedChests[chest.id] then
        OpenDialogue({
            hidePortrait = rewardCardIds ~= nil,
            name = chest.name,
            lines = rewardCardIds ~= nil
                and { "丝绒衬垫已经空了。两张法则卡现在都在你的手牌中。" }
                or { "箱盖敞开着，里面已经空了。" },
        })
        return
    end

    gameState_.openedChests[chest.id] = true
    if rewardCardIds ~= nil then
        for _, cardId in ipairs(rewardCardIds) do
            gameState_.ownedCards[cardId] = true
        end
        cardHandDirty_ = true
        if Prologue.CollectGravityCard(prologue_) then
            UpdateQuestHUD()
        end
    end

    local item = gameState_.inventory[chest.itemId]
    if item == nil then
        item = { name = chest.itemName, amount = 0 }
        gameState_.inventory[chest.itemId] = item
    end
    item.amount = item.amount + chest.amount
    UpdateInventoryHUD()

    local lines = {}
    for _, line in ipairs(chest.lines or {}) do table.insert(lines, line) end
    table.insert(lines, "获得了 " .. chest.itemName .. " ×" .. tostring(chest.amount) .. "！")
    if rewardCardIds ~= nil then
        table.insert(lines, "黄色 F=MG 费用 1；矢量改向费用 2。窗台房门已经解锁。")
    end
    OpenDialogue({
        hidePortrait = rewardCardIds ~= nil,
        name = chest.name,
        lines = lines,
    })
    if rewardCardIds ~= nil then
        dialog_.speaker.showBirthdayLetterAfter = true
    end
    print("[Tower2D] Chest opened: " .. chest.id .. " / " .. chest.itemName)
end

local function GetMotherDialogueTarget(mother)
    local lines = nil
    if not prologue_.motherTalked then
        lines = {}
        for _, line in ipairs(mother.lines or {}) do table.insert(lines, line) end
        if prologue_.gravityCardCollected then
            table.insert(lines, "看来你已经拿到教皇的礼物了。很好，直接去二楼开门拿邀请函吧。")
        end
    elseif prologue_.invitationCollected then
        lines = {
            "邀请函已经拿到了，很好。",
            "现在去教会找教皇吧，他正在等你。",
        }
    elseif prologue_.gravityCardCollected then
        lines = {
            "教皇的礼物已经在你手里了。",
            "直接去二楼打开窗台房门，用那两张卡拿到邀请函吧。",
        }
    else
        lines = {
            "教皇送来的礼物还在二楼箱子里。",
            "先把礼物拿上，再去窗台房取邀请函。",
        }
    end

    return {
        id = "mother",
        name = mother.name,
        portrait = mother.portrait,
        lines = lines,
    }
end

function AdvanceDialogueOrInteract()
    if not dialog_.open and dialogCloseLock_ > 0 then return end

    if dialog_.open then
        local line = dialog_.lines[dialog_.index]
        if dialog_.visibleChars < utf8.len(line) then
            dialog_.visibleChars = utf8.len(line)
            dialogueLabel_:SetText(line)
            continueLabel_:Show()
            return
        end

        dialog_.index = dialog_.index + 1
        if dialog_.index > #dialog_.lines then
            CloseDialogue()
            return
        end
        dialog_.visibleChars = 0
        dialog_.charTimer = 0.0
        dialogueLabel_:SetText("")
        continueLabel_:Hide()
        return
    end

    if firstPerson_.active then
        if firstPerson_.viewId == "window" and gravityLetter_.collectible then
            OpenInvitationDialogue()
            return
        end
        local view = firstPerson_.room.views[firstPerson_.viewId]
        OpenDialogue(view.target)
        return
    end

    local dx, dy = 0, 1
    if player_.direction == "up" then dx, dy = 0, -1 end
    if player_.direction == "left" then dx, dy = -1, 0 end
    if player_.direction == "right" then dx, dy = 1, 0 end

    local facingX = math.floor(player_.x + dx + 0.5)
    local facingY = math.floor(player_.y + dy + 0.5)
    local target = Maps.GetFacingTarget(currentMap_, facingX, facingY)
    if target ~= nil then
        if target.kind == "chest" then
            OpenChest(target)
        elseif target.id == "mother" then
            OpenDialogue(GetMotherDialogueTarget(target))
        else
            OpenDialogue(target)
        end
    end
end

local function PlayStairSound()
    if transitionSoundSource_ == nil then return end
    local sound = cache:GetResource("Sound", "audio/sfx/wood_stairs_transition.mp3")
    if sound ~= nil then
        transitionSoundSource_.gain = 0.85
        transitionSoundSource_:Play(sound)
    end
end

local function IsNearTransition(trigger)
    local nearestX = math.max(trigger.x, math.min(player_.x, trigger.x + trigger.w - 1))
    local nearestY = math.max(trigger.y, math.min(player_.y, trigger.y + trigger.h - 1))
    local dx = player_.x - nearestX
    local dy = player_.y - nearestY
    return dx * dx + dy * dy <= (trigger.proximity or 0.75) ^ 2
end

local function BeginFloorTransition(trigger)
    if floorTransition_.active or transitionLock_ > 0 then return end

    floorTransition_.active = true
    floorTransition_.phase = "fadeOut"
    floorTransition_.timer = 0.0
    floorTransition_.alpha = 0.0
    floorTransition_.target = trigger
    player_.moving = false
    touchMove_ = { up = false, down = false, left = false, right = false }
    ResetHeroAnimation()
    PlayStairSound()
    print("[Tower2D] Floor transition: " .. trigger.id)
end

local function CheckNearbyFloorTransition()
    if floorTransition_.active or transitionLock_ > 0 then return end
    for _, trigger in ipairs(currentMap_.transitions or {}) do
        if IsNearTransition(trigger) then
            BeginFloorTransition(trigger)
            return
        end
    end
end

local function UpdateFloorTransition(dt)
    if not floorTransition_.active then return end

    floorTransition_.timer = floorTransition_.timer + dt
    if floorTransition_.phase == "fadeOut" then
        floorTransition_.alpha = math.min(1.0, floorTransition_.timer / 0.45)
        if floorTransition_.alpha >= 1.0 then
            local target = floorTransition_.target
            LoadMap(target.target, target.spawnX, target.spawnY)
            floorTransition_.phase = "hold"
            floorTransition_.timer = 0.0
        end
    elseif floorTransition_.phase == "hold" then
        floorTransition_.alpha = 1.0
        if floorTransition_.timer >= 0.22 then
            floorTransition_.phase = "fadeIn"
            floorTransition_.timer = 0.0
        end
    elseif floorTransition_.phase == "fadeIn" then
        floorTransition_.alpha = math.max(0.0, 1.0 - floorTransition_.timer / 0.55)
        if floorTransition_.alpha <= 0.0 then
            floorTransition_.active = false
            floorTransition_.phase = "idle"
            floorTransition_.target = nil
            transitionLock_ = 0.55
        end
    end
end

local function UpdateTransitionOverlay()
    if transitionOverlay_ == nil then return end

    local alpha = math.floor(255 * floorTransition_.alpha)
    transitionOverlay_:SetStyle({
        backgroundColor = { 0, 0, 0, alpha },
    })

    if floorTransition_.active or alpha > 0 then
        transitionOverlay_:Show()
    else
        transitionOverlay_:Hide()
    end
end

local function ReadDirection()
    if input:GetKeyDown(KEY_UP) or input:GetKeyDown(KEY_W) or touchMove_.up then return 0, -1, "up" end
    if input:GetKeyDown(KEY_DOWN) or input:GetKeyDown(KEY_S) or touchMove_.down then return 0, 1, "down" end
    if input:GetKeyDown(KEY_LEFT) or input:GetKeyDown(KEY_A) or touchMove_.left then return -1, 0, "left" end
    if input:GetKeyDown(KEY_RIGHT) or input:GetKeyDown(KEY_D) or touchMove_.right then return 1, 0, "right" end
    return 0, 0, nil
end

local function IsPositionBlocked(x, y)
    local radius = 0.27
    local points = {
        { x - radius, y - radius }, { x + radius, y - radius },
        { x - radius, y + radius }, { x + radius, y + radius },
    }
    for _, point in ipairs(points) do
        if Maps.IsSolidAt(currentMap_, point[1], point[2]) then return true end
    end
    return false
end

ResetHeroAnimation = function()
    heroFrameIndex_ = 1
    heroFrameTimer_ = 0.0
end

local function UpdateHeroAnimation(dt)
    local nextState = player_.moving and "walk" or "idle"
    if heroAnimationDirection_ ~= player_.direction
        or heroAnimationState_ ~= nextState then
        heroAnimationDirection_ = player_.direction
        heroAnimationState_ = nextState
        ResetHeroAnimation()
    end

    local animation = HeroFrames[heroAnimationState_][player_.direction]
    if heroAnimationState_ == "idle" then
        heroFrameIndex_ = 1
        heroFrameTimer_ = 0.0
        return
    end

    local frameDuration = 1.0 / 10.0
    heroFrameTimer_ = heroFrameTimer_ + dt
    while heroFrameTimer_ >= frameDuration do
        heroFrameTimer_ = heroFrameTimer_ - frameDuration
        heroFrameIndex_ = heroFrameIndex_ % #animation.frames + 1
    end
end

local function UpdateDialogue(dt)
    if not dialog_.open then return end
    local line = dialog_.lines[dialog_.index]
    local length = utf8.len(line)
    if dialog_.visibleChars >= length then return end

    dialog_.charTimer = dialog_.charTimer + dt * 28
    local chars = math.floor(dialog_.charTimer)
    if chars > dialog_.visibleChars then
        dialog_.visibleChars = math.min(chars, length)
        local byteEnd = utf8.offset(line, dialog_.visibleChars + 1)
        if byteEnd == nil then
            dialogueLabel_:SetText(line)
        else
            dialogueLabel_:SetText(string.sub(line, 1, byteEnd - 1))
        end
        if dialog_.visibleChars >= length then
            continueLabel_:Show()
        end
    end
end

local function UpdatePlayer(dt)
    if floorTransition_.active then
        player_.moving = false
        return
    end

    transitionLock_ = math.max(0, transitionLock_ - dt)
    if transitionLock_ > 0 then
        player_.moving = false
        return
    end

    CheckNearbyFloorTransition()
    if floorTransition_.active then
        player_.moving = false
        return
    end

    local dx, dy, direction = ReadDirection()
    if direction == nil then
        player_.moving = false
        return
    end

    player_.direction = direction
    local distance = player_.walkSpeed * dt
    local moved = false

    local nextX = player_.x + dx * distance
    if dx ~= 0 and not IsPositionBlocked(nextX, player_.y) then
        player_.x = nextX
        moved = true
    end

    local nextY = player_.y + dy * distance
    if dy ~= 0 and not IsPositionBlocked(player_.x, nextY) then
        player_.y = nextY
        moved = true
    end

    player_.moving = moved

    if moved then
        local tileX = math.floor(player_.x + 0.5)
        local tileY = math.floor(player_.y + 0.5)
        local portal = Maps.GetPortal(currentMap_, tileX, tileY)
        if portal ~= nil then
            if currentMap_.id == "home_lower"
                and portal.target == "village"
                and not prologue_.invitationCollected then
                player_.x = 7
                player_.y = 9
                player_.direction = "up"
                player_.moving = false
                transitionLock_ = 0.45
                OpenHeroMonologue({
                    "现在还不能出门。",
                    "我得先拿到邀请函，再去教堂见主教。",
                })
                print("[Prologue] Home exit blocked until invitation collected")
                return
            end

            if portal.mode == "firstPerson" then
                EnterFirstPersonRoom(portal)
            else
                LoadMap(portal.target, portal.x, portal.y)
                ResetHeroAnimation()
            end
        end
    end
end

local COLORS = {
    grass = { 48, 112, 65 },
    road = { 173, 153, 113 },
    plaza = { 136, 136, 126 },
    tower = { 59, 63, 78 },
    floor = { 142, 97, 57 },
    upperFloor = { 162, 118, 72 },
    lowerFloor = { 126, 83, 51 },
    stoneFloor = { 107, 105, 103 },
    rug = { 109, 49, 69 },
}

FillRect = function(x, y, w, h, color)
    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(x), math.floor(y), math.ceil(w), math.ceil(h))
    nvgFillColor(vg_, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(vg_)
end

StrokeRect = function(x, y, w, h, color, width)
    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(x) + 0.5, math.floor(y) + 0.5, math.ceil(w) - 1, math.ceil(h) - 1)
    nvgStrokeColor(vg_, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(vg_, width)
    nvgStroke(vg_)
end

local function DrawPixelText(text, x, y, size, color, align)
    if pixelFont_ < 0 then return end
    nvgFontFaceId(vg_, pixelFont_)
    nvgFontSize(vg_, size)
    nvgTextAlign(vg_, align or (NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE))
    nvgFillColor(vg_, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(vg_, x, y, text, nil)
end

TileToScreen = function(tx, ty)
    return (tx - 1) * TILE - cameraX_, (ty - 1) * TILE - cameraY_
end

local IMAGE_PATHS = {
    bed = "image/像素家具木床_20260727075327.png",
    bedVertical = "image/正交像素木床竖直_20260727084608.png",
    desk = "image/像素家具书桌椅_20260727075339.png",
    deskHorizontal = "image/正交像素书桌水平_20260727084606.png",
    bookshelf = "image/像素家具书架_20260727075338.png",
    bookshelfHorizontal = "image/正交像素书架水平_20260727084358.png",
    bookshelfVertical = "image/正交像素书架竖直_20260727084402.png",
    wardrobe = "image/像素家具衣柜_20260727075331.png",
    wardrobeHorizontal = "image/正交像素衣柜水平_20260727084605.png",
    nightstand = "image/像素家具橱柜陶罐_20260727080937.png",
    kitchen = "image/像素家具厨房_20260727075349.png",
    diningTable = "image/像素家具餐桌_20260727075344.png",
    tableHorizontal = "image/正交像素长桌水平_20260727084352.png",
    tableVertical = "image/正交像素长桌竖直_20260727084405.png",
    fireplace = "image/像素家具壁炉_20260727075340.png",
    fireplaceHorizontal = "image/正交像素壁炉水平_20260727084409.png",
    fireplaceVertical = "image/正交像素壁炉竖直_20260727084404.png",
    stairsUp = "image/像素家具木楼梯_20260727075330.png",
    stairsDown = "image/像素家具木楼梯_20260727075330.png",
    stairsVertical = "image/正交像素木楼梯竖直_20260727084619.png",
    exitDoor = "image/像素家具出口木门_20260727075337.png",
    exitDoorOrthogonal = "image/正交像素出口木门_20260727084619.png",
    chest = "image/像素家具宝箱_20260727075332.png",
    chestOpen = "image/像素家具开启宝箱_20260727080938.png",
    chair = "image/像素家具单椅_20260727080920.png",
    chairOrthogonal = "image/正交像素木椅_20260727084630.png",
    cupboard = "image/像素家具橱柜陶罐_20260727080937.png",
    cupboardHorizontal = "image/正交像素橱柜水平_20260727084611.png",
    storage = "image/像素家具橱柜陶罐_20260727080937.png",
    window = "image/像素家具窗户_20260727080937.png",
    plant = "image/像素家具盆栽_20260727080923.png",
    stove = "image/像素家具炉灶_20260727080918.png",
    stoveHorizontal = "image/正交像素炉灶水平_20260727084403.png",
    stoveVertical = "image/正交像素炉灶竖直_20260727084359.png",
    counter = "image/像素家具公会柜台_20260727080931.png",
    counterHorizontal = "image/正交像素柜台水平_20260727084357.png",
    counterVertical = "image/正交像素柜台竖直_20260727084401.png",
    bench = "image/像素家具长椅_20260727080930.png",
    benchHorizontal = "image/正交像素长椅水平_20260727084616.png",
    forge = "image/像素家具锻造炉_20260727080939.png",
    forgeHorizontal = "image/正交像素锻造炉水平_20260727084618.png",
    anvil = "image/像素家具铁砧_20260727080932.png",
    anvilOrthogonal = "image/正交像素铁砧_20260727084626.png",
    map = "image/像素物件登塔地图_20260727081236.png",
    board = "image/像素物件留言板_20260727081246.png",
    hook = "image/像素物件登塔钩索_20260727081250.png",
    tree = "image/像素户外树木_20260727081242.png",
    well = "image/像素户外石井_20260727081246.png",
    sign = "image/像素户外路牌花丛_20260727081231.png",
    flowers = "image/像素户外路牌花丛_20260727081231.png",
    home = "image/像素建筑蓝屋顶住宅_20260727081252.png",
    guild = "image/像素建筑红屋顶公会_20260727081243.png",
    inn = "image/像素建筑绿屋顶旅店_20260727081253.png",
    forgeBuilding = "image/像素建筑橙屋顶工坊_20260727081252.png",
    tileUpperFloor = "image/像素瓦片浅木地板_20260727084238.png",
    tileLowerFloor = "image/像素瓦片深木地板_20260727084228.png",
    tileStoneFloor = "image/像素瓦片石板地面_20260727084223.png",
    tileGrass = "image/像素瓦片草地_20260727084240.png",
    tileRoad = "image/像素瓦片土路_20260727084224.png",
    tilePlaza = "image/像素瓦片石板地面_20260727084223.png",
    tileTower = "image/像素瓦片石板地面_20260727084223.png",
    tileWallTop = "image/像素直墙顶部无缝_20260727090053.png",
    tileWallBottom = "image/像素直墙底部无缝_20260727090102.png",
    tileWallLeft = "image/像素直墙左侧无缝_20260727090101.png",
    tileWallRight = "image/像素直墙右侧无缝_20260727090057.png",
    tileWallCornerTopLeft = "image/像素墙角左上_20260727090110.png",
    tileWallCornerTopRight = "image/像素墙角右上_20260727090110.png",
    tileWallCornerBottomLeft = "image/像素墙角左下_20260727090106.png",
    tileWallCornerBottomRight = "image/像素墙角右下_20260727090104.png",
    tileDoorway = "image/像素瓦片深木地板_20260727084228.png",
    staircaseDown = "image/像素扶手楼梯向下_20260727090110.png",
    staircaseUp = "image/像素扶手楼梯向上_20260727090631.png",
    staircaseRight = "image/像素三角楼梯向右_20260727093036.png",
    staircaseDownRight = "image/像素横向下楼梯向右_20260727100219.png",
    staircaseLeft = "image/像素三角楼梯向左_20260727093038.png",
    chestHorizontal = "image/像素水平长宝箱_20260727093047.png",
    chestHorizontalOpen = "image/像素水平长宝箱开启_20260727093049.png",
    highWallMiddle = "image/像素高墙中段_20260727093105.png",
    highWallLeft = "image/像素高墙左端_20260727093111.png",
    highWallRight = "image/像素高墙右端_20260727093101.png",
    sofaHorizontal = "image/像素双人沙发水平_20260727093041.png",
    lowBookshelf = "image/像素矮书柜水平_20260727093050.png",
    kitchenCounter = "image/像素厨房操作台水平_20260727093058.png",
    rugLong = "image/像素室内长地毯_20260727090100.png",
    towerPainting = "image/像素墙面高塔画像_20260727090252.png",
    familyPortrait = "image/像素墙面家庭画像_20260727090312.png",
    wallSconce = "image/像素壁挂烛台_20260727090246.png",
    barrelCrate = "image/像素木桶木箱组合_20260727090300.png",
    roundTable = "image/像素圆形边桌_20260727090301.png",
    screenHorizontal = "image/像素室内屏风水平_20260727090236.png",
    floorLamp = "image/像素落地灯_20260727090355.png",
    npcMother = "image/NPC母亲塞拉_48px.png",
    npcMira = "image/NPC村民米拉_48px.png",
    npcAda = "image/NPC公会长艾达_48px.png",
    fpDoor = "image/六面谜室_门墙_20260728112350.png",
    fpWindow = "image/edited_明亮高塔木阳台_20260801111714.png",
    fpMirror = "image/六面谜室_镜墙_20260728112345.png",
    fpShelves = "image/六面谜室_书架_20260728112342.png",
    fpCeiling = "image/六面谜室_天花板_20260728112345.png",
    fpFloor = "image/六面谜室_地板_20260728112337.png",
    optionRoomUpper = "image/edited_OptionRoom_2Nd清晰像素版_20260729155032.png",
    optionRoomLower = "image/OptionRoom_1nd.png",
    titleCover = "image/edited_牛顿牌正式开场封面_20260801070431.png",
    gravityLetterFrames = "image/Temp_transparent.png",
    churchInterior = "image/教堂内.png",
    towerFloor1 = "image/塔1层.png",
    villageBackground = "image/小镇外.png",
    heroWalkDown = "sprites/lorn_hero_rework/walk_down.png",
    heroWalkUp = "sprites/lorn_hero_rework/walk_up.png",
    heroWalkLeft = "sprites/lorn_hero_rework/walk_left.png",
    heroWalkRight = "sprites/lorn_hero_rework/walk_right.png",
    heroIdleDown = "sprites/lorn_hero_rework/idle_down.png",
    heroIdleUp = "sprites/lorn_hero_rework/idle_up.png",
    heroIdleLeft = "sprites/lorn_hero_rework/idle_left.png",
    heroIdleRight = "sprites/lorn_hero_rework/idle_right.png",
}

local function LoadImages()
    for key, path in pairs(IMAGE_PATHS) do
        local handle = nvgCreateImage(vg_, path, NVG_IMAGE_NEAREST)
        if handle ~= 0 then imageHandles_[key] = handle end
    end
end

local function DrawImage(handleKey, x, y, w, h)
    local handle = imageHandles_[handleKey]
    if handle == nil then return false end
    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(x), math.floor(y), math.ceil(w), math.ceil(h))
    nvgFillPaint(vg_, nvgImagePattern(vg_, x, y, w, h, 0, handle, 1.0))
    nvgFill(vg_)
    return true
end

local function DrawAtlasFrame(handleKey, animation, frame, canvasX, canvasY, scale)
    local handle = imageHandles_[handleKey]
    if handle == nil then return false end

    scale = scale or 1.0
    local sourceX, sourceY = frame[1], frame[2]
    local frameW, frameH = frame[3], frame[4]
    local trimX, trimY = frame[5] * scale, frame[6] * scale
    local drawW, drawH = frameW * scale, frameH * scale
    local drawX, drawY = canvasX + trimX, canvasY + trimY

    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(drawX), math.floor(drawY), drawW, drawH)
    nvgFillPaint(vg_, nvgImagePattern(
        vg_,
        drawX - sourceX * scale,
        drawY - sourceY * scale,
        animation.atlasW * scale,
        animation.atlasH * scale,
        0,
        handle,
        1.0
    ))
    nvgFill(vg_)
    return true
end

local TILE_IMAGE_KEYS = {
    grass = "tileGrass",
    road = "tileRoad",
    plaza = "tilePlaza",
    tower = "tileTower",
    floor = "tileUpperFloor",
    upperFloor = "tileUpperFloor",
    lowerFloor = "tileLowerFloor",
    stoneFloor = "tileStoneFloor",
    wallTop = "tileWallTop",
    wallBottom = "tileWallBottom",
    wallLeft = "tileWallLeft",
    wallRight = "tileWallRight",
    wallCornerTopLeft = "tileWallCornerTopLeft",
    wallCornerTopRight = "tileWallCornerTopRight",
    wallCornerBottomLeft = "tileWallCornerBottomLeft",
    wallCornerBottomRight = "tileWallCornerBottomRight",
    doorway = "tileDoorway",
}

local function DrawTile(tile, x, y)
    local key = TILE_IMAGE_KEYS[tile]
    if key ~= nil and DrawImage(key, x, y, TILE, TILE) then
        return
    end
    FillRect(x, y, TILE, TILE, COLORS[tile] or COLORS.grass)
end

local function DrawHighWall()
    if currentMap_.id == "village" then return end

    for x = 1, currentMap_.width do
        local screenX, screenY = TileToScreen(x, 1)
        local key = "highWallMiddle"
        if x == 1 then key = "highWallLeft" end
        if x == currentMap_.width then key = "highWallRight" end
        DrawImage(key, screenX, screenY - TILE, TILE, TILE * 2)
    end
end

local function DrawBuilding(building)
    local x, y = TileToScreen(building.x, building.y)
    local w, h = building.w * TILE, building.h * TILE
    local key = building.id == "forge" and "forgeBuilding" or building.id
    if not DrawImage(key, x - TILE * 0.45, y - TILE * 0.65, w + TILE * 0.9, h + TILE * 0.75) then
        FillRect(x, y, w, h, { 221, 194, 143 })
    end
end

local function DrawNpc(npc)
    local x, y = TileToScreen(npc.x, npc.y)
    local actorSize = 64 * actorScale_
    if npc.sprite ~= nil and DrawImage(
        npc.sprite,
        x + TILE * 0.5 - actorSize * 0.5,
        y + TILE - actorSize,
        actorSize,
        actorSize
    ) then
        return
    end

    local bodyColors = {
        red = { 164, 62, 62 },
        green = { 48, 137, 86 },
        mother = { 137, 58, 78 },
    }
    local body = bodyColors[npc.color] or bodyColors.green
    FillRect(x + 10, y + 18, 20, 19, body)
    FillRect(x + 12, y + 5, 16, 16, { 232, 181, 132 })
    FillRect(x + 9, y + 4, 22, 7, { 69, 43, 35 })
    FillRect(x + 8, y + 37, 10, 3, { 34, 28, 38 })
    FillRect(x + 22, y + 37, 10, 3, { 34, 28, 38 })
end

local function DrawObject(object)
    local x, y = TileToScreen(object.x, object.y)
    local draw = object.draw or {}
    local drawW = (draw.w or object.w or 1) * TILE
    local drawH = (draw.h or object.h or 1) * TILE
    local drawX = x + (draw.ox or 0) * TILE
    local drawY = y + (draw.oy or 0) * TILE
    local key = object.asset or object.kind

    if DrawImage(key, drawX, drawY, drawW, drawH) then
        return
    end

    FillRect(x, y, (object.w or 1) * TILE, (object.h or 1) * TILE, { 120, 80, 48 })
end

local function DrawFeature(feature)
    if feature.hidden then
        return
    end

    local x, y = TileToScreen(feature.x, feature.y)
    local key = feature.asset or feature.kind
    if feature.kind == "chest" then
        if feature.asset == "chestHorizontal" then
            key = gameState_.openedChests[feature.id] and "chestHorizontalOpen" or "chestHorizontal"
        else
            key = gameState_.openedChests[feature.id] and "chestOpen" or "chest"
        end
    end
    local draw = feature.draw or {}
    local width = (draw.w or feature.w or 1) * TILE
    local height = (draw.h or feature.h or 1) * TILE
    local drawX = x + (draw.ox or 0) * TILE
    local drawY = y + (draw.oy or 0) * TILE
    if not DrawImage(key, drawX, drawY, width, height) then
        FillRect(x, y, (feature.w or 1) * TILE, (feature.h or 1) * TILE, { 69, 170, 242 })
    end
end

local function DrawPlayer()
    local animation = HeroFrames[heroAnimationState_][player_.direction]
    local frame = animation.frames[math.min(heroFrameIndex_, #animation.frames)]
    local x, y = TileToScreen(player_.x, player_.y)
    local canvasSize = 64 * actorScale_
    local canvasX = x + TILE * 0.5 - canvasSize * 0.5
    local canvasY = y + TILE - canvasSize
    local directionName = player_.direction:sub(1, 1):upper() .. player_.direction:sub(2)
    local stateName = heroAnimationState_:sub(1, 1):upper() .. heroAnimationState_:sub(2)
    local handleKey = "hero" .. stateName .. directionName

    if not DrawAtlasFrame(handleKey, animation, frame, canvasX, canvasY, actorScale_) then
        FillRect(x + 10, y + 4, 20, 36, { 42, 104, 172 })
    end
end

local function DrawAtlasRegion(handleKey, sourceX, sourceY, sourceW, sourceH, x, y, w, h, atlasW, atlasH)
    local handle = imageHandles_[handleKey]
    if handle == nil then return false end

    nvgSave(vg_)
    nvgScissor(vg_, x, y, w, h)
    nvgBeginPath(vg_)
    nvgRect(vg_, x, y, w, h)
    nvgFillPaint(vg_, nvgImagePattern(
        vg_,
        x - sourceX * w / sourceW,
        y - sourceY * h / sourceH,
        atlasW * w / sourceW,
        atlasH * h / sourceH,
        0,
        handle,
        1.0
    ))
    nvgFill(vg_)
    nvgRestore(vg_)
    return true
end

function DrawAtlasRegionTinted(handleKey, sourceX, sourceY, sourceW, sourceH, x, y, w, h, atlasW, atlasH, color)
    local handle = imageHandles_[handleKey]
    if handle == nil then return false end

    nvgSave(vg_)
    nvgScissor(vg_, x, y, w, h)
    nvgBeginPath(vg_)
    nvgRect(vg_, x, y, w, h)
    nvgFillPaint(vg_, nvgImagePatternTinted(
        vg_,
        x - sourceX * w / sourceW,
        y - sourceY * h / sourceH,
        atlasW * w / sourceW,
        atlasH * h / sourceH,
        0,
        handle,
        nvgRGBA(color[1], color[2], color[3], color[4] or 255)
    ))
    nvgFill(vg_)
    nvgRestore(vg_)
    return true
end

function DrawGravityLetter(x, y, w, h, glow)
    local frameIndex = math.floor(gravityLetter_.animationTimer * 8.0) % 12
    local sourceX = (frameIndex % 4) * 288
    local sourceY = math.floor(frameIndex / 4) * 256

    glow = math.max(0.0, math.min(1.0, glow or 0.0))
    if glow > 0.01 then
        local pulse = 0.82 + 0.18 * math.sin(gravityLetter_.animationTimer * 6.0)
        local strength = glow * pulse
        local spread = math.max(8, w * 0.10)

        -- 安全的整体荧光底层：避免浏览器端复杂 Paint/复合模式造成 WASM 压力
        FillRect(
            x - spread,
            y - spread,
            w + spread * 2,
            h + spread * 2,
            { 255, 218, 92, math.floor(72 * strength) }
        )

        -- 四方向发光轮廓，明显但只额外绘制四次纹理
        local ring = math.max(4, w * 0.045)
        DrawAtlasRegionTinted(
            "gravityLetterFrames", sourceX, sourceY, 288, 256,
            x - ring, y, w, h, 1152, 768,
            { 255, 226, 92, math.floor(220 * strength) }
        )
        DrawAtlasRegionTinted(
            "gravityLetterFrames", sourceX, sourceY, 288, 256,
            x + ring, y, w, h, 1152, 768,
            { 255, 226, 92, math.floor(220 * strength) }
        )
        DrawAtlasRegionTinted(
            "gravityLetterFrames", sourceX, sourceY, 288, 256,
            x, y - ring, w, h, 1152, 768,
            { 255, 226, 92, math.floor(220 * strength) }
        )
        DrawAtlasRegionTinted(
            "gravityLetterFrames", sourceX, sourceY, 288, 256,
            x, y + ring, w, h, 1152, 768,
            { 255, 226, 92, math.floor(220 * strength) }
        )
    end

    local drawn = DrawAtlasRegion(
        "gravityLetterFrames",
        sourceX,
        sourceY,
        288,
        256,
        x,
        y,
        w,
        h,
        1152,
        768
    )

    -- 本体整体提亮，不使用浏览器端高风险复合模式
    if glow > 0.01 then
        DrawAtlasRegionTinted(
            "gravityLetterFrames", sourceX, sourceY, 288, 256,
            x, y, w, h, 1152, 768,
            { 255, 238, 165, math.floor(92 * glow) }
        )
    end
    return drawn
end
-- 目标锁定辅助线：四角括号 + 十字准星
function DrawTargetGuides(x, y, w, h, alpha)
    if alpha <= 0.01 then return end
    local a = math.floor(255 * alpha)
    local color = { 120, 245, 220, a }
    local pad = math.max(6, w * 0.10)
    local len = math.max(10, w * 0.22)
    local left, top = x - pad, y - pad
    local right, bottom = x + w + pad, y + h + pad

    local function Line(x1, y1, x2, y2)
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, x1, y1)
        nvgLineTo(vg_, x2, y2)
        nvgStrokeColor(vg_, nvgRGBA(color[1], color[2], color[3], color[4]))
        nvgStrokeWidth(vg_, 2)
        nvgStroke(vg_)
    end

    -- 四角括号
    Line(left, top, left + len, top);        Line(left, top, left, top + len)
    Line(right, top, right - len, top);      Line(right, top, right, top + len)
    Line(left, bottom, left + len, bottom);  Line(left, bottom, left, bottom - len)
    Line(right, bottom, right - len, bottom); Line(right, bottom, right, bottom - len)

    -- 贯穿全屏的十字辅助线（淡）
    local cx, cy = x + w * 0.5, y + h * 0.5
    local faint = { 120, 245, 220, math.floor(70 * alpha) }
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, 0, cy); nvgLineTo(vg_, logicalW_, cy)
    nvgMoveTo(vg_, cx, 0); nvgLineTo(vg_, cx, logicalH_)
    nvgStrokeColor(vg_, nvgRGBA(faint[1], faint[2], faint[3], faint[4]))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)
end

-- 行动点徽标：画在信封正上方
function DrawActionPoints(centerX, topY, spent, total, alpha)
    if alpha <= 0.01 or total <= 0 then return end
    local a = math.floor(255 * alpha)
    local dot = math.max(9, logicalW_ * 0.011)
    local gap = dot * 0.62
    local totalW = total * dot + (total - 1) * gap
    local startX = centerX - totalW * 0.5
    local y = topY - dot * 2.1

    DrawPixelText(
        string.format("行动点  %d / %d", spent, total),
        centerX, y - dot * 1.5, 15,
        { 255, 236, 170, a },
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE
    )

    for index = 1, total do
        local cx = startX + (index - 1) * (dot + gap) + dot * 0.5
        local filled = index <= spent
        nvgBeginPath(vg_)
        nvgCircle(vg_, cx, y + dot * 0.5, dot * 0.5)
        if filled then
            nvgFillColor(vg_, nvgRGBA(255, 209, 66, a))
            nvgFill(vg_)
        else
            nvgFillColor(vg_, nvgRGBA(18, 20, 40, math.floor(a * 0.72)))
            nvgFill(vg_)
        end
        nvgStrokeColor(vg_, nvgRGBA(255, 224, 130, a))
        nvgStrokeWidth(vg_, 2)
        nvgStroke(vg_)
    end
end

-- 世界内公式浮层：F = m · g，其中 g 是可被方向卡替换的发光变量
function DrawFormulaOverlay(centerX, bottomY, alpha)
    if alpha <= 0.01 then return end
    local a = math.floor(255 * alpha)
    local fontSize = math.max(16, logicalW_ * 0.019)
    local y = bottomY + fontSize * 1.5

    local directionGlyph = ({
        up = "↑", down = "↓", left = "←", right = "→",
    })[gravityLetter_.vectorDirection] or ""

    local prefix = "F = m ·"
    -- 方向卡真正放到矢量上后才显示方向，避免提前绑定
    local gText = gravityLetter_.vectorCardApplied and ("g " .. directionGlyph) or "g"

    nvgFontFaceId(vg_, pixelFont_)
    nvgFontSize(vg_, fontSize)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local prefixW = nvgTextBounds(vg_, 0, 0, prefix, nil)
    local gW = nvgTextBounds(vg_, 0, 0, gText, nil)
    local spacing = fontSize * 0.35
    local totalW = prefixW + spacing + gW

    local padX = fontSize * 0.7
    local padY = fontSize * 0.45
    local boxX = centerX - totalW * 0.5 - padX
    local boxY = y - fontSize * 0.5 - padY
    local boxW = totalW + padX * 2
    local boxH = fontSize + padY * 2

    FillRect(boxX, boxY, boxW, boxH, { 12, 14, 32, math.floor(a * 0.88) })
    StrokeRect(boxX, boxY, boxW, boxH, { 255, 202, 48, a }, 2)

    local textX = centerX - totalW * 0.5
    DrawPixelText(prefix, textX, y, fontSize, { 255, 245, 214, a },
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- g 的命中框（供方向卡拖放）
    local gx = textX + prefixW + spacing
    formulaOverlay_.gx = gx - fontSize * 0.3
    formulaOverlay_.gy = y - fontSize * 0.75
    formulaOverlay_.gw = gW + fontSize * 0.6
    formulaOverlay_.gh = fontSize * 1.5

    local gGlow = formulaOverlay_.gGlow
    if gGlow > 0.01 then
        local pulse = 0.75 + 0.25 * math.sin(gravityLetter_.animationTimer * 7.0)
        local glowAlpha = math.floor(150 * gGlow * pulse * alpha)
        local glowPad = fontSize * 0.75
        FillRect(
            formulaOverlay_.gx - glowPad,
            formulaOverlay_.gy - glowPad * 0.5,
            formulaOverlay_.gw + glowPad * 2,
            formulaOverlay_.gh + glowPad,
            { 90, 220, 255, glowAlpha }
        )
        StrokeRect(
            formulaOverlay_.gx,
            formulaOverlay_.gy,
            formulaOverlay_.gw,
            formulaOverlay_.gh,
            { 170, 248, 255, math.floor(255 * gGlow * alpha) },
            gGlow > 0.95 and 4 or 3
        )
    end

    local gColor = gGlow > 0.01
        and { 170, 245, 255, a }
        or { 255, 202, 48, a }
    DrawPixelText(gText, gx, y, fontSize, gColor,
        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
end

function DrawFirstPersonRoom()
    FillRect(0, 0, logicalW_, logicalH_, { 5, 5, 8 })
    if firstPerson_.room == nil then return end

    local view = firstPerson_.room.views[firstPerson_.viewId]
    DrawImage(view.image, 0, 0, logicalW_, logicalH_)

    if firstPerson_.viewId == "window" and gravityLetter_.active then
        -- 子弹时间暗角：拖拽时压暗全屏，突出可用目标
        local dim = cardDrag_.active and 0.55 or 0.0
        if dim > 0.0 then
            FillRect(0, 0, logicalW_, logicalH_, { 4, 6, 20, math.floor(150 * dim) })
        end

        local letterX, letterY, letterW, letterH = GetGravityLetterLogicalRect()
        DrawGravityLetter(
            letterX,
            letterY,
            letterW,
            letterH,
            math.max(gravityLetter_.glowIntensity, gravityLetter_.hovered and 0.55 or 0.0)
        )

        -- 锁定辅助线：拖拽悬停到目标上时出现
        if gravityLetter_.targetLocked then
            DrawTargetGuides(letterX, letterY, letterW, letterH, 1.0)
        end

        -- 行动点：拖拽中或已投入卡牌时显示
        local target = GetGravityLetterCardTarget()
        if target ~= nil then
            local spent = GetObjectCardCost("gravity_letter", true)
            local pointsAlpha = 0.0
            if cardDrag_.active then
                pointsAlpha = 1.0
            elseif spent > 0 or gravityLetter_.hovered then
                pointsAlpha = 1.0
            end
            DrawActionPoints(
                letterX + letterW * 0.5,
                letterY,
                spent,
                target.actionValue or 0,
                pointsAlpha
            )
        end

        -- 公式浮层
        if formulaOverlay_.visible then
            DrawFormulaOverlay(letterX + letterW * 0.5, letterY + letterH, 1.0)
        end
    end
end

UpdateWorldCamera = function()
    if currentMap_ == nil or firstPerson_.active then return end
    local mapPixelW = currentMap_.width * TILE
    local mapPixelH = currentMap_.height * TILE
    local playerPixelX = (player_.x - 0.5) * TILE
    local playerPixelY = (player_.y - 0.5) * TILE
    cameraX_ = math.max(0, math.min(mapPixelW - logicalW_, playerPixelX - logicalW_ * 0.5))
    cameraY_ = math.max(0, math.min(mapPixelH - logicalH_, playerPixelY - logicalH_ * 0.5))
    if mapPixelW < logicalW_ then cameraX_ = -(logicalW_ - mapPixelW) * 0.5 end
    if mapPixelH < logicalH_ then cameraY_ = -(logicalH_ - mapPixelH) * 0.5 end
end

function DrawWorld()
    if firstPerson_.active then
        DrawFirstPersonRoom()
        return
    end

    UpdateWorldCamera()
    local mapPixelW = currentMap_.width * TILE
    local mapPixelH = currentMap_.height * TILE

    FillRect(0, 0, logicalW_, logicalH_, { 21, 24, 36 })

    if currentMap_.backgroundImage ~= nil then
        local backgroundX, backgroundY =
            TileToScreen(1, 1)

        DrawImage(
            currentMap_.backgroundImage,
            backgroundX,
            backgroundY,
            mapPixelW,
            mapPixelH
        )
    else
        for y = 1, currentMap_.height do
            for x = 1, currentMap_.width do
                local sx, sy = TileToScreen(x, y)
                local tile = currentMap_.tiles[y][x]
                DrawTile(tile, sx, sy)
            end
        end

        DrawHighWall()
    end

    for _, building in ipairs(currentMap_.buildings or {}) do DrawBuilding(building) end
    for _, object in ipairs(currentMap_.objects or {}) do
        if object.layer == "floor" then DrawObject(object) end
    end
    for _, object in ipairs(currentMap_.objects or {}) do
        if object.layer == "wall" then DrawObject(object) end
    end
    for _, object in ipairs(currentMap_.objects or {}) do
        if object.layer == nil then DrawObject(object) end
    end
    for _, feature in ipairs(currentMap_.features or {}) do DrawFeature(feature) end

    for _, npc in ipairs(currentMap_.npcs or {}) do DrawNpc(npc) end
    DrawPlayer()
    DrawCollisionEditorOverlay()
end

function DrawTransitionOverlay()
    if floorTransition_.alpha <= 0.0 then return end
    FillRect(0, 0, logicalW_, logicalH_, {
        0,
        0,
        0,
        math.floor(255 * floorTransition_.alpha),
    })
end

function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg_, logicalW_, logicalH_, dpr_)
    nvgShapeAntiAlias(vg_, 0)
    DrawWorld()
    DrawTransitionOverlay()
    nvgEndFrame(vg_)
end

function HandleFirstPersonNavigation()
    if not firstPerson_.active or dialog_.open or firstPerson_.room == nil then return end

    local direction = nil
    if input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_A) then direction = "left" end
    if input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_D) then direction = "right" end
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then direction = "up" end
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then direction = "down" end
    if direction == nil then return end

    local view = firstPerson_.room.views[firstPerson_.viewId]
    local target = view[direction]
    if target ~= nil then SwitchFirstPersonView(target) end
end

function HandleFirstPersonHotspotClick()
    if cardDrag_.active then return end
    if not firstPerson_.active or dialog_.open or UI.IsPointerOverUI() then return end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return end

    local view = firstPerson_.room.views[firstPerson_.viewId]
    if firstPerson_.viewId == "window" and IsPointerOverGravityLetter() then
        if gravityLetter_.collectible then
            OpenInvitationDialogue()
            return
        end
        if gameState_.objectCards.gravity_letter ~= nil then
            SetCardFeedback("卡牌效果已生效；需要撤销时请点右上角“重置卡牌效果”。", { 255, 217, 61, 255 })
        else
            SetCardFeedback("把手牌里的卡拖到信封上使用。", { 255, 217, 61, 255 })
        end
        return
    end

    local mousePos = input:GetMousePosition()
    local x = mousePos.x / math.max(1, graphics:GetWidth())
    local y = mousePos.y / math.max(1, graphics:GetHeight())
    local hotspot = view.hotspot
    if hotspot ~= nil
        and x >= hotspot.x and x <= hotspot.x + hotspot.w
        and y >= hotspot.y and y <= hotspot.y + hotspot.h then
        OpenDialogue(view.target)
    end
end

---@param eventType string
---@param eventData VariantMap
function HandleOpeningInput(eventType, eventData)
    if Prologue.IsTitle(prologue_) then
        BeginPrologueOpening()
        return
    end

    if eventType ~= "KeyDown" and dialog_.open
        and not birthdayLetterOpen_ and not cardTutorialOpen_ then
        AdvanceDialogueOrInteract()
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    dialogCloseLock_ = math.max(0.0, dialogCloseLock_ - dt)

    if Prologue.IsTitle(prologue_) then
        return
    end
    if not Prologue.IsGameplayReady(prologue_) then
        UpdatePrologueOpening(dt)
        player_.moving = false
        UpdateHeroAnimation(dt)
        return
    end

    if cardFeedbackLabel_ ~= nil and cardFeedbackTimer_ > 0 then
        cardFeedbackTimer_ = math.max(0, cardFeedbackTimer_ - dt)
        if cardFeedbackTimer_ <= 0 then cardFeedbackLabel_:Hide() end
    end
    ProcessPendingCardUIActions()
    if cardHandDirty_ and firstPerson_.active and not cardDrag_.active then
        RebuildCardHand()
    end
    UpdateGravityLetter(dt)
    UpdateGravityLetterHover()
    UpdateDialogue(dt)
    UpdateFloorTransition(dt)
    UpdateTransitionOverlay()
    UpdateCollisionEditorInput()
    if collisionEditor_.dirty and not collisionEditor_.cloudSavePending
        and collisionEditor_.cloudSaveTimer > 0 then
        collisionEditor_.cloudSaveTimer = math.max(0, collisionEditor_.cloudSaveTimer - dt)
        if collisionEditor_.cloudSaveTimer <= 0 then SaveCollisionCloudData() end
    end

    if collisionEditor_.active then
        player_.moving = false
    elseif firstPerson_.active then
        player_.moving = false
        UpdateCardPointer()
        HandleFirstPersonNavigation()
        HandleFirstPersonHotspotClick()
    elseif Prologue.IsGameplayReady(prologue_) and not dialog_.open and not floorTransition_.active then
        UpdatePlayer(dt)
    else
        player_.moving = false
    end
    UpdateHeroAnimation(dt)

    if firstPerson_.active and not dialog_.open and input:GetKeyPress(KEY_ESCAPE) then
        ExitFirstPersonRoom()
        return
    end
    if not floorTransition_.active
        and (input:GetKeyPress(KEY_E) or input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN)) then
        AdvanceDialogueOrInteract()
    end
end

function HandleScreenMode(eventType, eventData)
    UpdateResolution()
    UpdateWorldScale()
    if firstPerson_.active then
        cardHandDirty_ = true
    end
end

function Start()
    graphics.windowTitle = "塔环国：垂环镇"
    input.mouseMode = MM_ABSOLUTE

    UpdateResolution()
    vg_ = nvgCreate(0)
    pixelFont_ = nvgCreateFont(vg_, "pixel", "Fonts/FusionPixel-12px-Prop-zh_hans.ttf")
    LoadImages()

    audioScene_ = Scene()
    local audioNode = audioScene_:CreateChild("TransitionAudio")
    transitionSoundSource_ = audioNode:CreateComponent("SoundSource")
    local bgmNode = audioScene_:CreateChild("BackgroundMusic")
    bgmSoundSource_ = bgmNode:CreateComponent("SoundSource")

    UI.Init({
        theme = PixelForgeTheme(),
        scale = UI.Scale.DEFAULT,
    })
    BuildUI()
    UpdateInventoryHUD()
    LoadLocalCollisionPayload()
    LoadMap("home_upper", 16, 3)
    if bgmSoundSource_ ~= nil then
        bgmSoundSource_:Stop()
        currentBgmPath_ = nil
    end
    overworldControls_:Hide()
    UpdateQuestHUD()
    LoadCollisionCloudData()
    ResetHeroAnimation()

    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("KeyDown", "HandleOpeningInput")
    SubscribeToEvent("MouseButtonDown", "HandleOpeningInput")
    SubscribeToEvent("TouchBegin", "HandleOpeningInput")
    SubscribeToEvent("ScreenMode", "HandleScreenMode")
    print("[Tower2D] Pure 2D pixel RPG started")
end

function Stop()
    UI.Shutdown()
    if bgmSoundSource_ ~= nil then bgmSoundSource_:Stop() end
    transitionSoundSource_ = nil
    bgmSoundSource_ = nil
    currentBgmPath_ = nil
    if audioScene_ ~= nil then
        audioScene_:Dispose()
        audioScene_ = nil
    end
    imageHandles_ = {}
    if vg_ ~= nil then
        nvgDelete(vg_)
        vg_ = nil
    end
end
