-- 牛顿牌：四区域异世界地图
-- 当前版本：大地图入口 + 四个可探索地标

local UI = require("urhox-libs/UI")

local uiRoot_ = nil
local currentView_ = "map"
local selectedRegion_ = nil
local mapButtons_ = {}

local CONFIG = {
    title = "牛顿牌",
    subtitle = "修正公式，改写物理",
    strategyPoints = 12,
    coverImage = "image/牛顿牌开场封面_20260725072941.png",
    mapImage = "image/edited_牛顿牌异世界大地图港口修复版_20260723140439.png",
}

local REGIONS = {
    {
        id = "pendulum_forest",
        name = "钟摆林",
        direction = "北境",
        subtitle = "失重的林间回廊",
        image = "image/钟摆林区域图_20260723133812.png",
        landmarkImage = "image/钟摆林地标_20260723135140.png",
        color = { 104, 178, 156, 255 },
        accent = { 177, 239, 201, 255 },
        left = "42%",
        top = "5%",
        width = 170,
        height = 190,
    },
    {
        id = "tide_harbor",
        name = "潮汐港",
        direction = "东岸",
        subtitle = "水面倒流的旧码头",
        image = "image/潮汐港区域图_20260723133805.png",
        landmarkImage = "image/潮汐港地标_20260723135116.png",
        color = { 89, 145, 207, 255 },
        accent = { 168, 220, 255, 255 },
        left = "70%",
        top = "31%",
        width = 185,
        height = 190,
    },
    {
        id = "equator_tower",
        name = "赤道塔",
        direction = "南部",
        subtitle = "热力失控的观测站",
        image = "image/赤道塔区域图_20260723133803.png",
        landmarkImage = "image/赤道塔地标_20260723135117.png",
        color = { 210, 128, 82, 255 },
        accent = { 255, 207, 128, 255 },
        left = "42%",
        top = "65%",
        width = 175,
        height = 190,
    },
    {
        id = "echo_mine",
        name = "回声矿区",
        direction = "西域",
        subtitle = "声音拥有重量的矿井",
        image = "image/回声矿区区域图_20260723133805.png",
        landmarkImage = "image/edited_回声矿区地标无边框版_20260723141505.png",
        color = { 142, 111, 184, 255 },
        accent = { 214, 185, 255, 255 },
        left = "12%",
        top = "36%",
        width = 190,
        height = 190,
    },
}

function Start()
    graphics.windowTitle = CONFIG.title

    print("[NewtonCard] Start: four-region map")
    print("[NewtonCard] Regions available: " .. tostring(#REGIONS))

    UI.Init({
        theme = "default-dark",
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } },
        },
        scale = UI.Scale.DEFAULT,
    })

    BuildCoverView()
    SubscribeToEvent("MouseButtonUp", "HandleCoverMouseButtonUp")
    print("[NewtonCard] Cover view ready")
end

function Stop()
    print("[NewtonCard] Stop")
    UI.Shutdown()
    uiRoot_ = nil
    mapButtons_ = {}
end

function HandleCoverMouseButtonUp(eventType, eventData)
    if currentView_ ~= "cover" then return end

    local button = eventData["Button"]:GetInt()
    if button == MOUSEB_LEFT then
        print("[NewtonCard] Engine click: entering map")
        BuildMapView()
    end
end

function BuildCoverView()
    currentView_ = "cover"

    uiRoot_ = UI.Panel {
        id = "coverRoot",
        width = "100%",
        height = "100%",
        backgroundImage = CONFIG.coverImage,
        backgroundFit = "cover",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                position = "absolute",
                top = 0,
                left = 0,
                right = 0,
                bottom = 0,
                backgroundGradient = {
                    type = "linear",
                    direction = "to-bottom",
                    from = { 3, 11, 20, 40 },
                    to = { 2, 8, 16, 205 },
                },
                pointerEvents = "none",
            },
            UI.Panel {
                position = "absolute",
                left = 0,
                right = 0,
                top = "32%",
                height = 210,
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = CONFIG.title,
                        fontSize = 58,
                        fontWeight = "bold",
                        fontColor = { 247, 229, 174, 255 },
                        textStroke = { width = 4, color = { 9, 16, 25, 235 } },
                        textShadow = { offsetX = 0, offsetY = 4, blur = 8, color = { 0, 0, 0, 180 } },
                    },
                    UI.Label {
                        text = "公式重写者的异界旅程",
                        marginTop = 12,
                        fontSize = 15,
                        letterSpacing = 4,
                        fontColor = { 205, 218, 212, 245 },
                    },
                    UI.Label {
                        text = CONFIG.subtitle,
                        marginTop = 26,
                        fontSize = 13,
                        fontColor = { 170, 195, 195, 235 },
                    },
                },
            },
            UI.Button {
                id = "coverStartButton",
                position = "absolute",
                left = 0,
                right = 0,
                top = 0,
                bottom = 0,
                padding = 0,
                backgroundColor = { 0, 0, 0, 0 },
                hoverBackgroundColor = { 255, 237, 181, 8 },
                pressedBackgroundColor = { 255, 237, 181, 18 },
                borderWidth = 0,
                boxShadow = false,
                pointerEvents = "auto",
                onClick = function()
                    print("[NewtonCard] Cover clicked: entering map")
                    BuildMapView()
                end,
                onPointerUp = function(event, self)
                    print("[NewtonCard] Cover released: entering map")
                    BuildMapView()
                end,
            },
            UI.Panel {
                position = "absolute",
                left = 0,
                right = 0,
                bottom = 58,
                height = 42,
                alignItems = "center",
                pointerEvents = "none",
                children = {
                    UI.Label {
                        text = "点击任意位置开始",
                        fontSize = 15,
                        fontColor = { 247, 235, 198, 245 },
                        textStroke = { width = 2, color = { 8, 14, 22, 190 } },
                    },
                },
            },
        },
    }

    UI.SetRoot(uiRoot_, true)
end

function BuildMapView()
    currentView_ = "map"
    selectedRegion_ = nil
    mapButtons_ = {}

    uiRoot_ = UI.Panel {
        id = "newtonCardRoot",
        width = "100%",
        height = "100%",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom",
            from = { 11, 18, 34, 255 },
            to = { 25, 38, 57, 255 },
        },
        pointerEvents = "box-none",
        children = {
            CreateMapHeader(),
            CreateMapBoard(),
            CreateMapFooter(),
        },
    }

    UI.SetRoot(uiRoot_, true)
end

function CreateMapHeader()
    return UI.Panel {
        position = "absolute",
        top = 22,
        left = 28,
        right = 28,
        height = 80,
        flexDirection = "row",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            UI.Panel {
                width = 58,
                height = 58,
                borderRadius = 16,
                backgroundGradient = {
                    type = "radial",
                    innerRadius = 2,
                    outerRadius = 42,
                    from = { 236, 188, 92, 255 },
                    to = { 160, 92, 63, 255 },
                },
                borderWidth = 2,
                borderColor = { 255, 220, 146, 180 },
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "∑",
                        fontSize = 30,
                        fontWeight = "bold",
                        fontColor = { 26, 32, 48, 255 },
                    },
                },
            },
            UI.Panel {
                marginLeft = 16,
                gap = 3,
                children = {
                    UI.Label {
                        text = CONFIG.title,
                        fontSize = 28,
                        fontWeight = "bold",
                        fontColor = { 245, 239, 220, 255 },
                        textStroke = { width = 2, color = { 10, 16, 28, 180 } },
                    },
                    UI.Label {
                        text = CONFIG.subtitle,
                        fontSize = 13,
                        fontColor = { 164, 184, 204, 255 },
                    },
                },
            },
            UI.Panel { flexGrow = 1 },
            CreateStrategyPointsBadge(),
        },
    }
end

function CreateStrategyPointsBadge()
    return UI.Panel {
        width = 180,
        height = 56,
        paddingHorizontal = 16,
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        backgroundColor = { 24, 35, 54, 235 },
        borderRadius = 14,
        borderWidth = 1,
        borderColor = { 89, 115, 143, 190 },
        boxShadow = {
            { x = 0, y = 4, blur = 12, spread = 0, color = { 0, 0, 0, 80 } },
        },
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "策略点",
                fontSize = 13,
                fontColor = { 171, 190, 209, 255 },
            },
            UI.Label {
                text = tostring(CONFIG.strategyPoints) .. " / " .. tostring(CONFIG.strategyPoints),
                fontSize = 20,
                fontWeight = "bold",
                fontColor = { 255, 211, 113, 255 },
            },
        },
    }
end

function CreateMapBoard()
    local children = { CreateBoardBackground() }

    for _, region in ipairs(REGIONS) do
        local button = CreateRegionButton(region)
        table.insert(children, button)
        table.insert(mapButtons_, button)
    end

    return UI.Panel {
        id = "mapBoard",
        position = "absolute",
        top = 116,
        left = 28,
        right = 28,
        bottom = 74,
        backgroundColor = { 30, 51, 64, 245 },
        backgroundImage = CONFIG.mapImage,
        backgroundFit = "cover",
        imageTint = { 255, 255, 255, 255 },
        borderRadius = 26,
        borderWidth = 2,
        borderColor = { 76, 116, 126, 210 },
        overflow = "hidden",
        children = children,
    }
end

function CreateBoardBackground()
    return UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        backgroundColor = { 0, 0, 0, 0 },
        pointerEvents = "none",
    }
end

function CreateRegionButton(region)
    local outline = UI.Panel {
        position = "absolute",
        left = 10,
        right = 10,
        top = 10,
        bottom = 10,
        borderRadius = 18,
        borderWidth = 4,
        borderColor = { region.accent[1], region.accent[2], region.accent[3], 255 },
        boxShadow = {
            { x = 0, y = 0, blur = 18, spread = 4, color = { 255, 226, 123, 180 } },
        },
        visible = false,
        pointerEvents = "none",
    }

    local infoCard = UI.Panel {
        position = "absolute",
        left = "-18%",
        right = "-18%",
        bottom = 4,
        minHeight = 62,
        paddingHorizontal = 12,
        paddingVertical = 8,
        gap = 2,
        backgroundColor = { 20, 27, 34, 242 },
        borderRadius = 12,
        borderWidth = 2,
        borderColor = { 255, 229, 130, 245 },
        boxShadow = {
            { x = 0, y = 4, blur = 14, spread = 0, color = { 0, 0, 0, 150 } },
        },
        visible = false,
        pointerEvents = "none",
        children = {
            UI.Label {
                text = region.name,
                fontSize = 17,
                fontWeight = "bold",
                fontColor = { 255, 245, 211, 255 },
                textAlign = "center",
            },
            UI.Label {
                text = region.direction .. " · " .. region.subtitle,
                fontSize = 10,
                fontColor = { 198, 218, 218, 235 },
                textAlign = "center",
                whiteSpace = "normal",
            },
        },
    }

    local landmark = UI.Panel {
        position = "absolute",
        left = 12,
        right = 12,
        top = 4,
        height = 154,
        backgroundImage = region.landmarkImage,
        backgroundFit = "contain",
        pointerEvents = "none",
    }

    local button = UI.Button {
        id = "region_" .. region.id,
        position = "absolute",
        left = region.left,
        top = region.top,
        width = region.width,
        height = region.height,
        padding = 0,
        backgroundColor = { 0, 0, 0, 0 },
        hoverBackgroundColor = { region.accent[1], region.accent[2], region.accent[3], 18 },
        pressedBackgroundColor = { region.accent[1], region.accent[2], region.accent[3], 36 },
        borderRadius = 18,
        borderWidth = 0,
        borderColor = { 0, 0, 0, 0 },
        boxShadow = false,
        transition = "all 0.18s easeOut",
        onPointerEnter = function(event, self)
            outline:Show()
            infoCard:Show()
            self:SetStyle({
                scale = 1.18,
                zIndex = 20,
                borderWidth = 4,
                borderColor = { 255, 229, 130, 235 },
            })
            print("[NewtonCard] Hover landmark: " .. region.name)
        end,
        onPointerLeave = function(event, self)
            outline:Hide()
            infoCard:Hide()
            self:SetStyle({
                scale = 1.0,
                zIndex = 0,
                borderWidth = 0,
                borderColor = { 0, 0, 0, 0 },
            })
        end,
        onClick = function(self)
            EnterRegion(region)
        end,
        children = {
            landmark,
            outline,
            infoCard,
        },
    }

    return button
end

function CreateMapFooter()
    return UI.Panel {
        position = "absolute",
        bottom = 18,
        left = 28,
        right = 28,
        height = 36,
        flexDirection = "row",
        alignItems = "center",
        pointerEvents = "none",
        children = {
            UI.Label {
                text = "点击地标进入探索 · 当前目标：修正四个异常区域",
                fontSize = 12,
                fontColor = { 172, 191, 207, 220 },
            },
            UI.Panel { flexGrow = 1 },
            UI.Label {
                text = "NEWTON CARD  /  FIELD MAP",
                fontSize = 10,
                fontColor = { 119, 146, 163, 210 },
            },
        },
    }
end

function EnterRegion(region)
    selectedRegion_ = region
    currentView_ = "region"
    print("[NewtonCard] Enter region: " .. region.id .. " / " .. region.name)

    local regionRoot = UI.Panel {
        id = "regionView",
        width = "100%",
        height = "100%",
        backgroundGradient = {
            type = "linear",
            direction = "to-bottom-right",
            from = { 15, 25, 39, 255 },
            to = { region.color[1], region.color[2], region.color[3], 255 },
        },
        justifyContent = "center",
        alignItems = "center",
        pointerEvents = "box-none",
        children = {
            UI.Panel {
                width = "82%",
                maxWidth = 620,
                padding = 32,
                gap = 16,
                alignItems = "center",
                backgroundColor = { 11, 21, 33, 225 },
                backgroundImage = region.image,
                backgroundFit = "cover",
                imageTint = { 118, 130, 130, 120 },
                borderRadius = 24,
                borderWidth = 2,
                borderColor = { region.accent[1], region.accent[2], region.accent[3], 180 },
                boxShadow = {
                    { x = 0, y = 10, blur = 30, spread = 0, color = { 0, 0, 0, 120 } },
                },
                pointerEvents = "auto",
                children = {
                    UI.Label {
                        text = region.direction .. "  /  " .. region.name,
                        fontSize = 30,
                        fontWeight = "bold",
                        fontColor = { 255, 245, 216, 255 },
                    },
                    UI.Label {
                        text = region.subtitle,
                        fontSize = 15,
                        fontColor = { 191, 213, 218, 255 },
                    },
                    UI.Divider {
                        width = "85%",
                        color = { region.accent[1], region.accent[2], region.accent[3], 120 },
                    },
                    UI.Label {
                        text = "区域探索入口已建立。\n下一步将在这里加入第一人称移动、场景交互与公式卡牌挑战。",
                        fontSize = 14,
                        lineHeight = 1.5,
                        whiteSpace = "normal",
                        textAlign = "center",
                        fontColor = { 218, 229, 224, 255 },
                    },
                    UI.Button {
                        text = "返回大地图",
                        variant = "secondary",
                        marginTop = 8,
                        onClick = function()
                            print("[NewtonCard] Return to map")
                            BuildMapView()
                        end,
                    },
                },
            },
        },
    }

    UI.SetRoot(regionRoot, true)
end

function GetScreenJoystickPatchString()
    return
        "<patch>" ..
        "    <add sel=\"/element/element[./attribute[@name='Name' and @value='Hat0']]\">" ..
        "        <attribute name=\"Is Visible\" value=\"false\" />" ..
        "    </add>" ..
        "</patch>"
end
