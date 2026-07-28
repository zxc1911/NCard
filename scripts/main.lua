-- 塔环国：纯 2D 像素 RPG 原型
-- 四方向移动、自动门传送、头像姓名对话框

local UI = require("urhox-libs/UI")
local Maps = require("Maps")
local HeroFrames = require("ChibiHeroFrames")

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
local touchMove_ = { up = false, down = false, left = false, right = false }
local imageHandles_ = {}
local heroFrameIndex_ = 1
local heroFrameTimer_ = 0.0
local heroAnimationDirection_ = "down"
local heroAnimationState_ = "idle"
local TileToScreen
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

local CARD_DEFINITIONS = {
    {
        id = "gravity_formula",
        name = "F=MG",
        type = "物理法则",
        description = "向目标施加重力，使失去支撑的物体向下坠落。",
        accent = { 87, 211, 190, 255 },
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
    usedCards = {},
    solvedObjects = {},
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
local gravityLetter_ = {
    active = true,
    fallen = false,
    x = 0.70,
    y = 0.25,
    startY = 0.25,
    targetY = 0.66,
    velocity = 0.0,
}

---@type Widget|nil
local locationLabel_ = nil
---@type Widget|nil
local inventoryLabel_ = nil
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
local modeHintLabel_ = nil
---@type Widget|nil
local cardHandPanel_ = nil
---@type Widget|nil
local cardFeedbackLabel_ = nil
---@type Widget|nil
local cardDragGhost_ = nil
---@type Widget|nil
local cardDragNameLabel_ = nil
---@type Widget|nil
local cardDragTypeLabel_ = nil
local cardWidgets_ = {}
local cardHandDirty_ = false
local EnterFirstPersonRoom
local ExitFirstPersonRoom
local SwitchFirstPersonView
local OpenDialogue
local RebuildCardHand
local CancelCardDrag
local ResolveCardDrop

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

local function FindCardTarget(view, normalizedX, normalizedY)
    for _, target in ipairs(view.cardTargets or {}) do
        if normalizedX >= target.x and normalizedX <= target.x + target.w
            and normalizedY >= target.y and normalizedY <= target.y + target.h then
            return target
        end
    end

    local hotspot = view.hotspot
    if hotspot ~= nil
        and normalizedX >= hotspot.x and normalizedX <= hotspot.x + hotspot.w
        and normalizedY >= hotspot.y and normalizedY <= hotspot.y + hotspot.h then
        return hotspot
    end
    return nil
end

local function UpdateGravityLetter(dt)
    if not gravityLetter_.active or gravityLetter_.fallen then return end
    if not gameState_.solvedObjects.gravity_letter then return end

    gravityLetter_.velocity = gravityLetter_.velocity + 3.8 * dt
    gravityLetter_.y = math.min(
        gravityLetter_.targetY,
        gravityLetter_.y + gravityLetter_.velocity * dt
    )
    if gravityLetter_.y >= gravityLetter_.targetY then
        gravityLetter_.fallen = true
        gravityLetter_.velocity = 0.0
        SetCardFeedback("信件落到了桌面上，可以调查了。", { 98, 220, 139, 255 })
        print("[Tower2D] Gravity letter landed")
    end
end

local function SetCardFeedback(text, color)
    if cardFeedbackLabel_ == nil then return end
    cardFeedbackLabel_:SetText(text)
    cardFeedbackLabel_:SetStyle({ fontColor = color })
    cardFeedbackLabel_:Show()
    cardFeedbackTimer_ = 2.2
end

local function GlobalPointerPosition(event, widget)
    local layout = widget:GetAbsoluteLayoutForHitTest()
    if layout == nil then return event.x, event.y end
    return layout.x + event.x, layout.y + event.y
end

local function SetCardRestStyle(widget)
    widget:SetStyle({
        scale = 1.0,
        translateY = 0,
        opacity = 1.0,
        zIndex = 0,
    })
end

local function SetCardHoverStyle(widget)
    widget:SetStyle({
        scale = 1.14,
        translateY = -24,
        opacity = 1.0,
        zIndex = 220,
    })
end

local function UpdateCardDragGhost(x, y)
    if cardDragGhost_ == nil then return end
    cardDragGhost_:SetStyle({
        left = x - 58,
        top = y - 74,
    })
end

CancelCardDrag = function()
    if cardDrag_.sourceWidget ~= nil then
        SetCardRestStyle(cardDrag_.sourceWidget)
    end
    cardDrag_.active = false
    cardDrag_.card = nil
    cardDrag_.sourceWidget = nil
    cardDrag_.pointerId = nil
    if cardDragGhost_ ~= nil then cardDragGhost_:Hide() end
end

ResolveCardDrop = function(card, screenX, screenY)
    if not firstPerson_.active or firstPerson_.room == nil then
        SetCardFeedback("卡牌只能在谜室中使用。", { 232, 112, 96, 255 })
        return
    end

    local view = firstPerson_.room.views[firstPerson_.viewId]
    local hotspot = view.hotspot
    local normalizedX = screenX / math.max(1, logicalW_)
    local normalizedY = screenY / math.max(1, logicalH_)
    local overHotspot = hotspot ~= nil
        and normalizedX >= hotspot.x
        and normalizedX <= hotspot.x + hotspot.w
        and normalizedY >= hotspot.y
        and normalizedY <= hotspot.y + hotspot.h

    if not overHotspot then
        SetCardFeedback("卡牌没有接触到可作用的物品。", { 232, 112, 96, 255 })
        print("[Tower2D] Card missed hotspot: " .. card.id)
        return
    end

    if hotspot.objectId ~= nil and gameState_.solvedObjects[hotspot.objectId] then
        SetCardFeedback("这个机关已经被解开了。", { 245, 205, 96, 255 })
        return
    end

    if hotspot.acceptedCard ~= card.id then
        SetCardFeedback(card.name .. "没有产生反应。", { 232, 112, 96, 255 })
        print("[Tower2D] Card rejected: " .. card.id .. " -> " .. tostring(hotspot.objectId))
        return
    end

    gameState_.usedCards[card.id] = true
    gameState_.solvedObjects[hotspot.objectId] = true
    cardHandDirty_ = true
    SetCardFeedback(card.name .. "生效了！", { 98, 220, 139, 255 })
    OpenDialogue({
        hidePortrait = true,
        name = hotspot.effectName or view.name,
        lines = hotspot.effectLines or { "机关产生了变化。" },
    })
    print("[Tower2D] Card solved: " .. card.id .. " -> " .. hotspot.objectId)
end

local function CreateCardWidget(card)
    local cardWidget
    cardWidget = UI.Card {
        width = 108,
        height = 138,
        flexShrink = 0,
        padding = 8,
        gap = 5,
        backgroundColor = { 27, 27, 58, 248 },
        borderColor = card.accent,
        transition = "scale 0.12 ease-out, translateY 0.12 ease-out, opacity 0.1 linear",
        onPointerEnter = function(event, widget)
            if not cardDrag_.active then SetCardHoverStyle(widget) end
        end,
        onPointerLeave = function(event, widget)
            if not cardDrag_.active then SetCardRestStyle(widget) end
        end,
        onPointerDown = function(event, widget)
            if cardDrag_.active or not event:IsPrimaryAction() then return end
            local x, y = GlobalPointerPosition(event, widget)
            cardDrag_.active = true
            cardDrag_.card = card
            cardDrag_.sourceWidget = widget
            cardDrag_.pointerId = event.pointerId
            cardDrag_.x = x
            cardDrag_.y = y
            widget:SetStyle({ opacity = 0.28, scale = 1.0, translateY = 0, zIndex = 0 })
            cardDragNameLabel_:SetText(card.name)
            cardDragTypeLabel_:SetText(card.type)
            cardDragGhost_:SetStyle({ borderColor = card.accent })
            UpdateCardDragGhost(x, y)
            cardDragGhost_:Show()
            event:PreventDefault()
            print("[Tower2D] Card drag start: " .. card.id)
        end,
        onPointerMove = function(event, widget)
            if not cardDrag_.active or cardDrag_.pointerId ~= event.pointerId then return end
            local x, y = GlobalPointerPosition(event, widget)
            cardDrag_.x = x
            cardDrag_.y = y
            UpdateCardDragGhost(x, y)
            event:PreventDefault()
        end,
        onPointerUp = function(event, widget)
            if not cardDrag_.active or cardDrag_.pointerId ~= event.pointerId then return end
            local x, y = GlobalPointerPosition(event, widget)
            local droppedCard = cardDrag_.card
            CancelCardDrag()
            ResolveCardDrop(droppedCard, x, y)
            event:PreventDefault()
        end,
        children = {
            UI.Label {
                text = card.type,
                fontSize = 8,
                fontColor = card.accent,
                alignSelf = "flex-end",
            },
            UI.Panel {
                height = 45,
                alignItems = "center",
                justifyContent = "center",
                backgroundColor = { card.accent[1], card.accent[2], card.accent[3], 48 },
                borderWidth = 1,
                borderColor = card.accent,
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "◆",
                        fontSize = 20,
                        fontColor = card.accent,
                    },
                },
            },
            UI.Label {
                text = card.name,
                fontSize = 11,
                fontWeight = "bold",
                fontColor = { 248, 236, 206, 255 },
                textAlign = "center",
                whiteSpace = "normal",
            },
        },
    }

    return UI.Tooltip {
        content = card.name .. " · " .. card.type .. "\n" .. card.description,
        position = "top",
        delay = 0.12,
        offset = 14,
        maxWidth = 260,
        fontSize = 10,
        tooltipBgColor = { 254, 160, 2, 248 },
        textColor = { 34, 23, 20, 255 },
        borderWidth = 2,
        borderColor = { 249, 95, 3, 255 },
        children = { cardWidget },
    }, cardWidget
end

RebuildCardHand = function()
    if cardHandPanel_ == nil then return end
    cardHandPanel_:ClearChildren()
    cardWidgets_ = {}
    for _, card in ipairs(CARD_DEFINITIONS) do
        if not gameState_.usedCards[card.id] then
            local tooltip, widget = CreateCardWidget(card)
            cardHandPanel_:AddChild(tooltip)
            cardWidgets_[card.id] = widget
        end
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
        left = "18%",
        right = "18%",
        bottom = 8,
        height = 158,
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "flex-end",
        gap = 8,
        paddingTop = 18,
        pointerEvents = "box-none",
        zIndex = 92,
        visible = false,
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
            UI.Button {
                text = "<",
                position = "absolute",
                left = 24,
                top = "43%",
                width = 62,
                height = 70,
                fontSize = 22,
                onClick = function() NavigateFirstPerson("left") end,
            },
            UI.Button {
                text = ">",
                position = "absolute",
                right = 24,
                top = "43%",
                width = 62,
                height = 70,
                fontSize = 22,
                onClick = function() NavigateFirstPerson("right") end,
            },
            UI.Button {
                text = "^",
                position = "absolute",
                left = "47%",
                top = 68,
                width = 68,
                height = 54,
                onClick = function() NavigateFirstPerson("up") end,
            },
            UI.Button {
                text = "v",
                position = "absolute",
                left = "47%",
                bottom = 26,
                width = 68,
                height = 54,
                onClick = function() NavigateFirstPerson("down") end,
            },
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
                    modeHintLabel_,
                    inventoryLabel_,
                },
            },
            overworldControls_,
            firstPersonControls_,
            cardHandPanel_,
            cardFeedbackLabel_,
            cardDragGhost_,
            dialogPanel_,
            transitionOverlay_,
        },
    }

    UI.SetRoot(root, true)
end

local function UpdateInventoryHUD()
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

local function UpdateWorldScale()
    if currentMap_ == nil then return end

    if currentMap_.id == "village" then
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
    if mapId == "home_upper" or mapId == "home_lower" then
        return "audio/bgm_home.ogg"
    end
    return "audio/bgm_town.ogg"
end

LoadMap = function(id, spawnX, spawnY)
    currentMap_ = Maps.Get(id)
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
    print("[Tower2D] First-person view: " .. viewId)
end

EnterFirstPersonRoom = function(portal)
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
    firstPersonControls_:Show()
    modeHintLabel_:SetText("方向键 / WASD 切换视角  ·  E / 空格 调查  ·  Esc 离开")
    locationLabel_:SetText(room.name)
    SwitchFirstPersonView(room.initialView)
    if cardHandPanel_ ~= nil then
        cardHandPanel_:Hide()
    end
    if cardFeedbackLabel_ ~= nil then
        cardFeedbackLabel_:Hide()
    end
    CancelCardDrag()
    RebuildCardHand()
    cardHandPanel_:Show()
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
    CancelCardDrag()
    if cardHandPanel_ ~= nil then cardHandPanel_:Hide() end
    if cardFeedbackLabel_ ~= nil then cardFeedbackLabel_:Hide() end
    firstPersonControls_:Hide()
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

    local portrait = target.portrait or "image/主角洛恩像素头像_20260727071202.png"
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
    dialog_.open = false
    dialog_.speaker = nil
    dialogPanel_:Hide()
end

local function OpenChest(chest)
    if gameState_.openedChests[chest.id] then
        OpenDialogue({
            name = chest.name,
            lines = { "箱盖敞开着，里面已经空了。" },
        })
        return
    end

    gameState_.openedChests[chest.id] = true
    local item = gameState_.inventory[chest.itemId]
    if item == nil then
        item = { name = chest.itemName, amount = 0 }
        gameState_.inventory[chest.itemId] = item
    end
    item.amount = item.amount + chest.amount
    UpdateInventoryHUD()

    OpenDialogue({
        name = chest.name,
        lines = {
            chest.lines[1],
            "获得了 " .. chest.itemName .. " ×" .. tostring(chest.amount) .. "！",
        },
    })
    print("[Tower2D] Chest opened: " .. chest.id .. " / " .. chest.itemName)
end

function AdvanceDialogueOrInteract()
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
        local tileX = math.floor(point[1] + 0.5)
        local tileY = math.floor(point[2] + 0.5)
        if Maps.IsSolid(currentMap_, tileX, tileY) then return true end
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

    local frameDuration = 0.075
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

local function FillRect(x, y, w, h, color)
    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(x), math.floor(y), math.ceil(w), math.ceil(h))
    nvgFillColor(vg_, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(vg_)
end

local function StrokeRect(x, y, w, h, color, width)
    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(x) + 0.5, math.floor(y) + 0.5, math.ceil(w) - 1, math.ceil(h) - 1)
    nvgStrokeColor(vg_, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgStrokeWidth(vg_, width)
    nvgStroke(vg_)
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
    fpWindow = "image/六面谜室_窗桌_20260728112348.png",
    fpMirror = "image/六面谜室_镜墙_20260728112345.png",
    fpShelves = "image/六面谜室_书架_20260728112342.png",
    fpCeiling = "image/六面谜室_天花板_20260728112345.png",
    fpFloor = "image/六面谜室_地板_20260728112337.png",
    heroWalkDown = "sprites/lorn_hero_chibi/walk_down.png",
    heroWalkUp = "sprites/lorn_hero_chibi/walk_up.png",
    heroWalkLeft = "sprites/lorn_hero_chibi/walk_left.png",
    heroWalkRight = "sprites/lorn_hero_chibi/walk_right.png",
    heroIdleDown = "sprites/lorn_hero_chibi/idle_down.png",
    heroIdleUp = "sprites/lorn_hero_chibi/idle_up.png",
    heroIdleLeft = "sprites/lorn_hero_chibi/idle_left.png",
    heroIdleRight = "sprites/lorn_hero_chibi/idle_right.png",
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
    local canvasSize = 67 * actorScale_
    local canvasX = x + TILE * 0.5 - canvasSize * 0.5
    local canvasY = y + TILE - canvasSize
    local directionName = player_.direction:sub(1, 1):upper() .. player_.direction:sub(2)
    local stateName = heroAnimationState_:sub(1, 1):upper() .. heroAnimationState_:sub(2)
    local handleKey = "hero" .. stateName .. directionName

    if not DrawAtlasFrame(handleKey, animation, frame, canvasX, canvasY, actorScale_) then
        FillRect(x + 10, y + 4, 20, 36, { 42, 104, 172 })
    end
end

local function DrawFirstPersonRoom()
    FillRect(0, 0, logicalW_, logicalH_, { 5, 5, 8 })
    if firstPerson_.room == nil then return end

    local view = firstPerson_.room.views[firstPerson_.viewId]
    DrawImage(view.image, 0, 0, logicalW_, logicalH_)

    local hotspot = view.hotspot
    if hotspot ~= nil then
        local x = hotspot.x * logicalW_
        local y = hotspot.y * logicalH_
        local w = hotspot.w * logicalW_
        local h = hotspot.h * logicalH_
        StrokeRect(x, y, w, h, { 219, 176, 98, 85 }, 2)
    end
end

local function DrawWorld()
    if firstPerson_.active then
        DrawFirstPersonRoom()
        return
    end

    local mapPixelW = currentMap_.width * TILE
    local mapPixelH = currentMap_.height * TILE
    local playerPixelX = (player_.x - 0.5) * TILE
    local playerPixelY = (player_.y - 0.5) * TILE
    cameraX_ = math.max(0, math.min(mapPixelW - logicalW_, playerPixelX - logicalW_ * 0.5))
    cameraY_ = math.max(0, math.min(mapPixelH - logicalH_, playerPixelY - logicalH_ * 0.5))
    if mapPixelW < logicalW_ then cameraX_ = -(logicalW_ - mapPixelW) * 0.5 end
    if mapPixelH < logicalH_ then cameraY_ = -(logicalH_ - mapPixelH) * 0.5 end

    FillRect(0, 0, logicalW_, logicalH_, { 21, 24, 36 })

    for y = 1, currentMap_.height do
        for x = 1, currentMap_.width do
            local sx, sy = TileToScreen(x, y)
            local tile = currentMap_.tiles[y][x]
            DrawTile(tile, sx, sy)
        end
    end

    DrawHighWall()
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
end

local function DrawTransitionOverlay()
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

local function HandleFirstPersonNavigation()
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

local function HandleFirstPersonHotspotClick()
    if not firstPerson_.active or cardDrag_.active or dialog_.open or UI.IsPointerOverUI() then return end
    if not input:GetMouseButtonPress(MOUSEB_LEFT) then return end

    local mousePos = input:GetMousePosition()
    local x = mousePos.x / dpr_ / logicalW_
    local y = mousePos.y / dpr_ / logicalH_
    local view = firstPerson_.room.views[firstPerson_.viewId]
    local hotspot = view.hotspot
    if hotspot ~= nil
        and x >= hotspot.x and x <= hotspot.x + hotspot.w
        and y >= hotspot.y and y <= hotspot.y + hotspot.h then
        OpenDialogue(view.target)
    end
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    if cardFeedbackLabel_ ~= nil and cardFeedbackTimer_ > 0 then
        cardFeedbackTimer_ = math.max(0, cardFeedbackTimer_ - dt)
        if cardFeedbackTimer_ <= 0 then cardFeedbackLabel_:Hide() end
    end
    if cardHandDirty_ and firstPerson_.active and not cardDrag_.active then
        RebuildCardHand()
    end
    UpdateDialogue(dt)
    UpdateFloorTransition(dt)
    UpdateTransitionOverlay()

    if firstPerson_.active then
        player_.moving = false
        HandleFirstPersonNavigation()
        HandleFirstPersonHotspotClick()
    elseif not dialog_.open and not floorTransition_.active then
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
    LoadMap("home_upper")
    ResetHeroAnimation()

    SubscribeToEvent(vg_, "NanoVGRender", "HandleNanoVGRender")
    SubscribeToEvent("Update", "HandleUpdate")
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
