-- 塔环国：纯 2D 像素 RPG 原型
-- 四方向移动、自动门传送、头像姓名对话框

local UI = require("urhox-libs/UI")
local Maps = require("Maps")
local HeroFrames = require("HeroFrames")

---@type userdata|nil
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
---@type Scene|nil
local audioScene_ = nil
---@type SoundSource|nil
local transitionSoundSource_ = nil
local touchMove_ = { up = false, down = false, left = false, right = false }
local imageHandles_ = {}
local heroFrameIndex_ = 1
local heroFrameTimer_ = 0.0
local heroAnimationDirection_ = "down"
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

local gameState_ = {
    openedChests = {},
    inventory = {},
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

local function BuildUI()
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
                    UI.Label {
                        text = "方向键 / WASD 移动  ·  E / 空格 调查",
                        fontSize = 9,
                        fontColor = { 200, 200, 220, 255 },
                    },
                    inventoryLabel_,
                },
            },
            CreateMoveButton("▲", 68, 104, "up"),
            CreateMoveButton("◀", 20, 56, "left"),
            CreateMoveButton("▼", 68, 56, "down"),
            CreateMoveButton("▶", 116, 56, "right"),
            UI.Button {
                text = "对话",
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

LoadMap = function(id, spawnX, spawnY)
    currentMap_ = Maps.Get(id)
    player_.x = spawnX or currentMap_.spawn.x
    player_.y = spawnY or currentMap_.spawn.y
    player_.moving = false
    transitionLock_ = 0.28
    locationLabel_:SetText(currentMap_.name)
    print("[Tower2D] Map: " .. currentMap_.id .. " / " .. currentMap_.name)
end

local function OpenDialogue(target)
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
    if heroAnimationDirection_ ~= player_.direction then
        heroAnimationDirection_ = player_.direction
        ResetHeroAnimation()
    end

    if not player_.moving then
        ResetHeroAnimation()
        return
    end

    local animation = HeroFrames[player_.direction]
    heroFrameTimer_ = heroFrameTimer_ + dt
    local frameDuration = 0.042 / 0.72
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
        ResetHeroAnimation()
        return
    end

    transitionLock_ = math.max(0, transitionLock_ - dt)
    if transitionLock_ > 0 then
        player_.moving = false
        ResetHeroAnimation()
        return
    end

    CheckNearbyFloorTransition()
    if floorTransition_.active then
        player_.moving = false
        ResetHeroAnimation()
        return
    end

    local dx, dy, direction = ReadDirection()
    if direction == nil then
        player_.moving = false
        ResetHeroAnimation()
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
            LoadMap(portal.target, portal.x, portal.y)
            ResetHeroAnimation()
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
    heroDown = "sprites/lorn_hero/walk_down/spritesheet.png",
    heroUp = "sprites/lorn_hero/walk_up/spritesheet.png",
    heroLeft = "sprites/lorn_hero/walk_left/spritesheet.png",
    heroRight = "sprites/lorn_hero/walk_right/spritesheet.png",
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

local function DrawAtlasFrame(handleKey, animation, frame, canvasX, canvasY)
    local handle = imageHandles_[handleKey]
    if handle == nil then return false end

    local sourceX, sourceY = frame[1], frame[2]
    local frameW, frameH = frame[3], frame[4]
    local trimX, trimY = frame[5], frame[6]
    local drawX, drawY = canvasX + trimX, canvasY + trimY

    nvgBeginPath(vg_)
    nvgRect(vg_, math.floor(drawX), math.floor(drawY), frameW, frameH)
    nvgFillPaint(vg_, nvgImagePattern(
        vg_,
        drawX - sourceX,
        drawY - sourceY,
        animation.atlasW,
        animation.atlasH,
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
    if npc.sprite ~= nil and DrawImage(npc.sprite, x - 12, y - 24, 64, 64) then
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
    local animation = HeroFrames[player_.direction]
    local frame = animation.frames[math.min(heroFrameIndex_, #animation.frames)]
    local x, y = TileToScreen(player_.x, player_.y)
    local canvasX = x + TILE * 0.5 - 33.5
    local canvasY = y + TILE - 60
    local handleKey = "hero" .. player_.direction:sub(1, 1):upper() .. player_.direction:sub(2)

    if not DrawAtlasFrame(handleKey, animation, frame, canvasX, canvasY) then
        FillRect(x + 10, y + 4, 20, 36, { 42, 104, 172 })
    end
end

local function DrawWorld()
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

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    UpdateDialogue(dt)
    UpdateFloorTransition(dt)
    UpdateTransitionOverlay()
    if not dialog_.open and not floorTransition_.active then
        UpdatePlayer(dt)
    else
        player_.moving = false
    end
    UpdateHeroAnimation(dt)

    if not floorTransition_.active
        and (input:GetKeyPress(KEY_E) or input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN)) then
        AdvanceDialogueOrInteract()
    end
end

function HandleScreenMode(eventType, eventData)
    UpdateResolution()
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
    transitionSoundSource_ = nil
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
