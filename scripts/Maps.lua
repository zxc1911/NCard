local Maps = {}

local FINE_CELLS_PER_TILE = 4

local function FineCellKey(x, y)
    return tostring(y) .. ":" .. tostring(x)
end

local function Fill(width, height, value)
    local tiles = {}
    for y = 1, height do
        tiles[y] = {}
        for x = 1, width do
            tiles[y][x] = value
        end
    end
    return tiles
end

local function Rect(tiles, x1, y1, x2, y2, value)
    for y = y1, y2 do
        for x = x1, x2 do
            tiles[y][x] = value
        end
    end
end

local function AddSolidRect(solids, x, y, width, height)
    for tileY = y, y + height - 1 do
        for tileX = x, x + width - 1 do
            solids[tileY .. ":" .. tileX] = true
        end
    end
end

local function AddObjectCollision(solids, object)
    if object.collision ~= nil then
        for _, rect in ipairs(object.collision) do
            AddSolidRect(
                solids,
                object.x + (rect.ox or 0),
                object.y + (rect.oy or 0),
                rect.w or 1,
                rect.h or 1
            )
        end
    elseif object.solid then
        AddSolidRect(solids, object.x, object.y, object.w or 1, object.h or 1)
    end
end

local function BuildVillage()
    local width, height = 18, 10
    local tiles = Fill(width, height, "grass")
    local solids = {}

    -- 外景碰撞设计（18×10）：沿城墙、建筑外墙和花坛布置可编辑阻挡区。
    -- 传送点使用独立 portal 配置，可在游戏内按 F3 开启，右键设置、鼠标中键删除。
    local collision = {
        { x = 1, y = 1, w = 18, h = 1 },
        { x = 1, y = 10, w = 18, h = 1 },
        { x = 1, y = 1, w = 1, h = 10 },
        { x = 18, y = 1, w = 1, h = 10 },
        { x = 2, y = 2, w = 5, h = 2 },
        { x = 12, y = 2, w = 5, h = 3 },
        { x = 2, y = 7, w = 4, h = 2 },
        { x = 13, y = 7, w = 4, h = 2 },
        { x = 7, y = 3, w = 2, h = 2 },
        { x = 10, y = 3, w = 2, h = 2 },
        { x = 7, y = 8, w = 2, h = 1 },
        { x = 10, y = 8, w = 2, h = 1 },
    }
    for _, rect in ipairs(collision) do
        AddSolidRect(solids, rect.x, rect.y, rect.w, rect.h)
    end

    local portals = {
        ["3:5"] = { target = "home_lower", x = 7, y = 9 },
        ["7:5"] = { target = "guild", x = 7, y = 9 },
        ["7:8"] = { target = "inn", x = 7, y = 9 },
        ["7:14"] = { target = "church", x = 8, y = 7 },
        ["2:9"] = { target = "tower_floor1", x = 8, y = 11 },
        ["8:15"] = { target = "forge", x = 7, y = 9 },
    }
    for key in pairs(portals) do solids[key] = nil end

    return {
        id = "village",
        name = "塔环国 · 垂环镇",
        subtitle = "城墙内的石板广场连接着住宅、教堂与高塔入口。",
        width = width,
        height = height,
        backgroundImage = "villageBackground",
        tiles = tiles,
        buildings = {},
        solids = solids,
        portals = portals,
        spawn = { x = 9, y = 8 },
        npcs = {
            {
                id = "mira", name = "米拉", x = 9, y = 6, color = "green", sprite = "npcMira", solid = false,
                portrait = "image/村民米拉像素头像_20260727071205.png",
                lines = {
                    "洛恩，你终于来了！世界塔的大门就在城镇北侧。",
                    "右侧的大教堂是主教的所在，中央高塔入口通往塔的第一层。",
                },
            },
        },
        objects = {},
        features = {},
    }
end

local INTERIORS = {
    home_upper = {
        name = "候选者之家 · 二楼",
        subtitle = "晨光照进洛恩的卧室，楼下传来早餐的香气。",
        floor = "upperFloor",
        spawn = { x = 6, y = 8 },
        portals = {},
        transitions = {
            {
                id = "stairs_down", x = 8, y = 8, w = 4, h = 2,
                target = "home_lower", spawnX = 8, spawnY = 5,
                proximity = 0.85,
            },
        },
        objects = {
            { kind = "bed", asset = "bedVertical", orientation = "vertical", x = 2, y = 2, w = 2, h = 3, solid = true, draw = { w = 2.3, h = 3.4, ox = -0.15, oy = -0.35 } },
            { kind = "nightstand", x = 4, y = 2, w = 1, h = 1, solid = true, draw = { w = 1.2, h = 1.2, ox = -0.1, oy = -0.2 } },
            { kind = "bookshelf", asset = "bookshelfHorizontal", orientation = "horizontal", x = 5, y = 2, w = 3, h = 1, solid = true, draw = { w = 3.4, h = 1.65, ox = -0.2, oy = -0.65 } },
            { kind = "wardrobe", asset = "wardrobeHorizontal", orientation = "horizontal", x = 11, y = 2, w = 2, h = 1, solid = true, draw = { w = 2.35, h = 1.75, ox = -0.18, oy = -0.75 } },
            { kind = "desk", asset = "deskHorizontal", orientation = "horizontal", x = 2, y = 6, w = 3, h = 1, solid = true, draw = { w = 3.25, h = 1.55, ox = -0.12, oy = -0.5 } },
            { kind = "chair", asset = "chairOrthogonal", x = 3, y = 7, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.25, ox = -0.12, oy = -0.2 } },
            { kind = "sofaHorizontal", x = 5, y = 6, w = 2, h = 1, solid = true, draw = { w = 2.35, h = 1.4, ox = -0.18, oy = -0.35 } },
            { kind = "roundTable", x = 7, y = 6, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.25, ox = -0.12, oy = -0.2 } },
            { kind = "lowBookshelf", x = 2, y = 9, w = 2, h = 1, solid = true, draw = { w = 2.3, h = 1.35, ox = -0.15, oy = -0.3 } },
            { kind = "screenHorizontal", x = 5, y = 9, w = 2, h = 1, solid = true, draw = { w = 2.3, h = 1.4, ox = -0.15, oy = -0.4 } },
            { kind = "rugLong", x = 5, y = 7, w = 3, h = 2, layer = "floor", draw = { w = 3.2, h = 2.2, ox = -0.1, oy = -0.1 } },
            { kind = "plant", x = 12, y = 6, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.35, ox = -0.12, oy = -0.3 } },
            { kind = "floorLamp", x = 11, y = 6, w = 1, h = 1, solid = true, draw = { w = 1.2, h = 1.4, ox = -0.1, oy = -0.4 } },
            { kind = "familyPortrait", x = 3, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 1.35, h = 1.35, ox = -0.18, oy = -0.45 } },
            { kind = "towerPainting", x = 6, y = 1, w = 2, h = 1, layer = "wall", draw = { w = 2.4, h = 1.5, ox = -0.2, oy = -0.55 } },
            { kind = "wallSconce", x = 9, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 1, h = 1.25, oy = -0.35 } },
            {
                kind = "stairsDown", asset = "staircaseDownRight", orientation = "horizontal",
                x = 8, y = 8, w = 4, h = 2,
                collision = { { ox = 0, oy = 0, w = 4, h = 1 } },
                draw = { w = 4.25, h = 2.35, ox = -0.12, oy = -0.35 },
            },
        },
        features = {
            {
                id = "starter_chest", kind = "chest", asset = "chestHorizontal",
                x = 9, y = 2, w = 2, h = 1, solid = true,
                draw = { w = 2.0, h = 1.20, ox = 0.0, oy = -0.20 },
                name = "父亲的旧木箱", itemId = "healing_herb", itemName = "药草", amount = 3,
                lines = { "箱子沿墙摆放，里面整齐放着出发前的补给。" },
            },
            {
                id = "father_map", kind = "map", x = 10, y = 1, w = 1, h = 1, solid = true,
                draw = { w = 1.2, h = 1.2, ox = -0.1, oy = -0.25 },
                name = "父亲的登塔地图",
                lines = { "地图上标出了塔的前九层。第九层旁边留着父亲最后的笔记。" },
            },
        },
    },
    home_lower = {
        name = "候选者之家 · 一楼",
        subtitle = "壁炉烧得正旺，母亲正在准备出门前的早餐。",
        floor = "lowerFloor",
        spawn = { x = 7, y = 9 },
        portals = {
            { x = 7, y = 11, target = "village", spawnX = 10, spawnY = 12, kind = "exitDoor" },
        },
        transitions = {
            {
                id = "stairs_up", x = 8, y = 3, w = 4, h = 2,
                target = "home_upper", spawnX = 8, spawnY = 7,
                proximity = 0.85,
            },
        },
        npcs = {
            {
                id = "mother", name = "母亲 · 塞拉", x = 4, y = 5, color = "mother", sprite = "npcMother",
                portrait = "image/母亲塞拉像素头像_20260727072703.png",
                lines = {
                    "洛恩，早饭已经准备好了。今天就是候选登记的日子吧？",
                    "你父亲也曾站在这扇门前，带着一样紧张又期待的表情。",
                    "二楼的旧木箱里有三株药草，出门前记得带上。",
                    "不管你能爬到塔的第几层，这里永远是你的家。",
                },
            },
        },
        objects = {
            { kind = "kitchenCounter", x = 2, y = 2, w = 3, h = 1, solid = true, draw = { w = 3.4, h = 1.55, ox = -0.2, oy = -0.55 } },
            { kind = "stove", asset = "stoveHorizontal", orientation = "horizontal", x = 5, y = 2, w = 2, h = 1, solid = true, draw = { w = 2.35, h = 1.55, ox = -0.18, oy = -0.55 } },
            { kind = "cupboard", asset = "cupboardHorizontal", orientation = "horizontal", x = 11, y = 2, w = 2, h = 1, solid = true, draw = { w = 2.35, h = 1.7, ox = -0.18, oy = -0.7 } },
            { kind = "diningTable", asset = "tableHorizontal", orientation = "horizontal", x = 2, y = 7, w = 3, h = 1, solid = true, draw = { w = 3.35, h = 1.5, ox = -0.18, oy = -0.45 } },
            { kind = "chair", asset = "chairOrthogonal", x = 2, y = 6, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.25, ox = -0.12, oy = -0.2 } },
            { kind = "chair", asset = "chairOrthogonal", x = 4, y = 8, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.25, ox = -0.12, oy = -0.2 } },
            { kind = "fireplace", asset = "fireplaceHorizontal", orientation = "horizontal", x = 10, y = 6, w = 2, h = 1, solid = true, draw = { w = 2.4, h = 1.75, ox = -0.2, oy = -0.75 } },
            { kind = "sofaHorizontal", x = 9, y = 8, w = 2, h = 1, solid = true, draw = { w = 2.4, h = 1.5, ox = -0.2, oy = -0.5 } },
            { kind = "roundTable", x = 11, y = 8, w = 1, h = 1, solid = true, draw = { w = 1.3, h = 1.3, ox = -0.15, oy = -0.25 } },
            { kind = "lowBookshelf", x = 2, y = 9, w = 2, h = 1, solid = true, draw = { w = 2.35, h = 1.4, ox = -0.18, oy = -0.35 } },
            { kind = "barrelCrate", x = 12, y = 9, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.25, ox = -0.12, oy = -0.2 } },
            { kind = "rugLong", x = 5, y = 7, w = 3, h = 2, layer = "floor", draw = { w = 3.3, h = 2.2, ox = -0.15, oy = -0.1 } },
            { kind = "floorLamp", x = 11, y = 5, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.45, ox = -0.12, oy = -0.45 } },
            { kind = "towerPainting", x = 5, y = 1, w = 2, h = 1, layer = "wall", draw = { w = 2.4, h = 1.5, ox = -0.2, oy = -0.55 } },
            { kind = "familyPortrait", x = 9, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 1.35, h = 1.35, ox = -0.18, oy = -0.45 } },
            {
                kind = "stairsUp", asset = "staircaseLeft", orientation = "horizontal",
                x = 8, y = 3, w = 4, h = 2,
                collision = { { ox = 0, oy = 1, w = 4, h = 1 } },
                draw = { w = 4.25, h = 2.35, ox = -0.12, oy = -0.35 },
            },
            { kind = "exitDoor", asset = "exitDoorOrthogonal", x = 7, y = 11, w = 1, h = 1, draw = { w = 1.2, h = 1.3, ox = -0.1, oy = -0.3 } },
            { kind = "plant", x = 12, y = 6, w = 1, h = 1, solid = true, draw = { w = 1.25, h = 1.35, ox = -0.12, oy = -0.3 } },
        },
        features = {},
    },
    guild = {
        name = "勇者公会", subtitle = "候选者在这里立下登塔誓约。", floor = "stoneFloor",
        spawn = { x = 7, y = 9 },
        portals = { { x = 7, y = 11, target = "village", spawnX = 14, spawnY = 17, kind = "exitDoor" } },
        npcs = {
            {
                id = "ada", name = "公会长艾达", x = 7, y = 3, color = "red", sprite = "npcAda",
                portrait = "image/公会长艾达像素头像_20260727071206.png",
                lines = { "洛恩，我已经等你很久了。", "去塔门广场看看吧，回来后我会为你登记第一份委托。" },
            },
        },
        objects = {
            { kind = "rugLong", x = 5, y = 6, w = 3, h = 2, layer = "floor", draw = { w = 3, h = 2 } },
            { kind = "counter", asset = "counterHorizontal", orientation = "horizontal", x = 4, y = 4, w = 6, h = 1, solid = true, draw = { w = 6, h = 1.35, oy = -0.35 } },
            { kind = "towerPainting", x = 6, y = 1, w = 2, h = 1, layer = "wall", draw = { w = 2, h = 1 } },
            { kind = "banner", x = 3, y = 1, w = 1, h = 1, layer = "wall" },
            { kind = "banner", x = 10, y = 1, w = 1, h = 1, layer = "wall" },
            { kind = "wallSconce", x = 5, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 0.75, h = 0.75, ox = 0.12, oy = 0.1 } },
            { kind = "wallSconce", x = 9, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 0.75, h = 0.75, ox = 0.12, oy = 0.1 } },
            { kind = "bench", asset = "benchHorizontal", orientation = "horizontal", x = 2, y = 8, w = 3, h = 1, solid = true },
            { kind = "bench", asset = "benchHorizontal", orientation = "horizontal", x = 9, y = 8, w = 3, h = 1, solid = true },
            { kind = "roundTable", x = 2, y = 5, w = 1, h = 1, solid = true },
            { kind = "roundTable", x = 11, y = 5, w = 1, h = 1, solid = true },
            { kind = "plant", x = 2, y = 3, w = 1, h = 1, solid = true },
            { kind = "plant", x = 12, y = 3, w = 1, h = 1, solid = true },
            { kind = "exitDoor", asset = "exitDoorOrthogonal", x = 7, y = 11, w = 1, h = 1 },
        },
        features = {},
    },
    inn = {
        name = "登塔人旅店", subtitle = "旅人交换着楼层传闻。", floor = "lowerFloor",
        spawn = { x = 7, y = 9 },
        portals = { { x = 7, y = 11, target = "village", spawnX = 20, spawnY = 13, kind = "exitDoor" } },
        objects = {
            { kind = "rugLong", x = 5, y = 7, w = 3, h = 2, layer = "floor", draw = { w = 3, h = 2 } },
            { kind = "counter", asset = "counterHorizontal", orientation = "horizontal", x = 2, y = 3, w = 4, h = 1, solid = true, draw = { w = 4, h = 1.35, oy = -0.35 } },
            { kind = "diningTable", asset = "tableHorizontal", orientation = "horizontal", x = 8, y = 5, w = 3, h = 1, solid = true, draw = { w = 3, h = 1.25, oy = -0.2 } },
            { kind = "chair", asset = "chairOrthogonal", x = 8, y = 4, w = 1, h = 1, solid = true },
            { kind = "chair", asset = "chairOrthogonal", x = 10, y = 6, w = 1, h = 1, solid = true },
            { kind = "fireplace", asset = "fireplaceHorizontal", orientation = "horizontal", x = 10, y = 2, w = 2, h = 1, solid = true, draw = { w = 2, h = 1.5, oy = -0.5 } },
            { kind = "towerPainting", x = 6, y = 1, w = 2, h = 1, layer = "wall", draw = { w = 2, h = 1 } },
            { kind = "wallSconce", x = 9, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 0.75, h = 0.75, ox = 0.12, oy = 0.1 } },
            { kind = "screenHorizontal", x = 2, y = 7, w = 2, h = 1, solid = true, draw = { w = 2, h = 1.2, oy = -0.2 } },
            { kind = "barrelCrate", x = 11, y = 8, w = 1, h = 1, solid = true },
            { kind = "floorLamp", x = 2, y = 9, w = 1, h = 1, solid = true },
            { kind = "plant", x = 12, y = 9, w = 1, h = 1, solid = true },
            { kind = "exitDoor", asset = "exitDoorOrthogonal", x = 7, y = 11, w = 1, h = 1 },
        },
        features = {
            { id = "inn_board", kind = "board", x = 2, y = 2, w = 1, h = 1, solid = true, name = "旅人留言板", lines = { "第三层的风，会记住每一个说谎者的名字。" } },
        },
    },
    forge = {
        name = "风轮工坊", subtitle = "这里打造抵抗高层风压的装备。", floor = "stoneFloor",
        spawn = { x = 7, y = 9 },
        portals = { { x = 7, y = 11, target = "village", spawnX = 21, spawnY = 17, kind = "exitDoor" } },
        objects = {
            { kind = "rugLong", x = 5, y = 7, w = 3, h = 2, layer = "floor", draw = { w = 3, h = 2 } },
            { kind = "anvil", asset = "anvilOrthogonal", x = 4, y = 5, w = 1, h = 1, solid = true },
            { kind = "forge", asset = "forgeHorizontal", orientation = "horizontal", x = 9, y = 3, w = 2, h = 1, solid = true, draw = { w = 2, h = 1.5, oy = -0.5 } },
            { kind = "storage", asset = "cupboardHorizontal", orientation = "horizontal", x = 2, y = 2, w = 2, h = 1, solid = true, draw = { w = 2, h = 1.35, oy = -0.35 } },
            { kind = "barrelCrate", x = 2, y = 4, w = 1, h = 1, solid = true },
            { kind = "barrelCrate", x = 11, y = 3, w = 1, h = 1, solid = true },
            { kind = "counter", asset = "counterHorizontal", orientation = "horizontal", x = 8, y = 6, w = 4, h = 1, solid = true, draw = { w = 4, h = 1.35, oy = -0.35 } },
            { kind = "towerPainting", x = 5, y = 1, w = 2, h = 1, layer = "wall", draw = { w = 2, h = 1 } },
            { kind = "wallSconce", x = 8, y = 1, w = 1, h = 1, layer = "wall", draw = { w = 0.75, h = 0.75, ox = 0.12, oy = 0.1 } },
            { kind = "screenHorizontal", x = 2, y = 8, w = 2, h = 1, solid = true, draw = { w = 2, h = 1.2, oy = -0.2 } },
            { kind = "floorLamp", x = 11, y = 9, w = 1, h = 1, solid = true },
            { kind = "exitDoor", asset = "exitDoorOrthogonal", x = 7, y = 11, w = 1, h = 1 },
        },
        features = {
            { id = "climbing_hook", kind = "hook", x = 6, y = 3, w = 1, h = 1, solid = true, name = "登塔钩索", lines = { "钩索末端镶着塔石碎片，似乎能抓住逆风中的墙面。" } },
        },
    },
    church = {
        name = "垂环镇大教堂", subtitle = "彩窗下，主教正在等待带着邀请函的候选者。", floor = "stoneFloor",
        backgroundImage = "churchInterior",
        width = 12,
        height = 8,
        spawn = { x = 8, y = 7 },
        portals = { { x = 8, y = 8, target = "village", spawnX = 14, spawnY = 7, kind = "exitDoor" } },
        collision = {
            { x = 1, y = 1, w = 12, h = 1 },
            { x = 1, y = 1, w = 1, h = 8 },
            { x = 12, y = 1, w = 1, h = 8 },
            { x = 1, y = 8, w = 7, h = 1 },
            { x = 9, y = 8, w = 4, h = 1 },
            { x = 3, y = 3, w = 2, h = 1 },
            { x = 8, y = 3, w = 2, h = 1 },
            { x = 3, y = 5, w = 2, h = 1 },
            { x = 8, y = 5, w = 2, h = 1 },
        },
        npcs = {
            {
                id = "bishop", name = "主教", x = 6, y = 2, color = "red", sprite = "npcAda",
                portrait = "image/公会长艾达像素头像_20260727071206.png",
                lines = {
                    "欢迎你，洛恩。邀请函上的火漆证明了你的候选者身份。",
                    "在踏入塔门之前，记住：每一层都在考验你对法则的理解。",
                },
            },
        },
        objects = {},
        features = {},
    },
    tower_floor1 = {
        name = "世界塔 · 第一层", subtitle = "废弃的机关与旋梯，构成登塔之路的第一道试炼。", floor = "tower",
        backgroundImage = "towerFloor1",
        width = 8,
        height = 12,
        spawn = { x = 8, y = 11 },
        portals = { { x = 8, y = 12, target = "village", spawnX = 9, spawnY = 2, kind = "exitDoor" } },
        collision = {
            { x = 1, y = 1, w = 8, h = 1 },
            { x = 1, y = 1, w = 1, h = 12 },
            { x = 8, y = 1, w = 1, h = 12 },
            { x = 1, y = 12, w = 7, h = 1 },
            { x = 3, y = 2, w = 1, h = 3 },
            { x = 6, y = 2, w = 1, h = 2 },
            { x = 2, y = 6, w = 1, h = 2 },
            { x = 7, y = 6, w = 1, h = 2 },
            { x = 2, y = 10, w = 1, h = 1 },
            { x = 6, y = 10, w = 2, h = 1 },
        },
        objects = {},
        features = {},
    },
}

local FIRST_PERSON_ROOMS = {
    six_face_room = {
        id = "six_face_room",
        name = "候选者之家 · 高塔窗台",
        initialView = "window",
        views = {
            window = {
                name = "高塔窗台",
                image = "fpWindow",
                cardTargets = {
                    {
                        x = 0.53,
                        y = 0.17,
                        w = 0.12,
                        h = 0.18,
                        objectId = "gravity_letter",
                        actionValue = 3,
                        acceptedCards = { "gravity_formula", "vector_direction" },
                        effectName = "高处的邀请函",
                        effectLines = {
                            "F=MG 让邀请函响应重力矢量 g，默认方向为右。",
                            "再用矢量改向卡把 g 调整为向下，才能让邀请函落到窗台。",
                        },
                    },
                },
                hotspot = {
                    x = 0.35, y = 0.10, w = 0.30, h = 0.58,
                },
                target = {
                    name = "洛恩",
                    portrait = "image/主角洛恩像素头像_20260727071202.png",
                    lines = {
                        "窗外，高塔刺破晨雾，塔顶的灯火还没有熄灭。",
                        "那封盖着教皇火漆的邀请函悬在高处，我现在还够不到。",
                        "先把法则卡用在正确的目标上，再把邀请函拿下来。",
                    },
                },
            },
        },
    },
}

local OPTION_ROOMS = {
    home_upper = {
        name = "候选者之家 · 二楼",
        subtitle = "晨光洒进宽敞的二楼起居室，通往一楼的阶梯位于西南角。",
        width = 18,
        height = 10,
        backgroundImage = "optionRoomUpper",
        spawn = { x = 5, y = 7 },
        portals = {
            {
                x = 2,
                y = 3,
                mode = "firstPerson",
                roomId = "six_face_room",
                returnMap = "home_upper",
                returnX = 2,
                returnY = 4,
                returnDirection = "down",
            },
        },
        transitions = {
            {
                id = "stairs_down",
                x = 1,
                y = 8,
                w = 2,
                h = 2,
                target = "home_lower",
                spawnX = 4,
                spawnY = 7,
                proximity = 0.9,
            },
        },
        -- 碰撞设计（18×10）：
        -- 北侧桌柜/床铺与中央承重墙不可穿过；西南楼梯保持可接近。
        -- 擦边按整格阻挡，中央墙在南侧留出绕行空间。
        collision = {
            { x = 2, y = 2, w = 1, h = 2 },
            { x = 3, y = 3, w = 3, h = 2 },
            { x = 7, y = 2, w = 3, h = 4 },
            { x = 7, y = 5, w = 2, h = 1 },
            { x = 10, y = 1, w = 1, h = 7 },
            { x = 11, y = 2, w = 2, h = 2 },
            { x = 11, y = 3, w = 1, h = 2 },
            { x = 14, y = 2, w = 2, h = 3 },
            { x = 11, y = 5, w = 2, h = 1 },
            { x = 15, y = 5, w = 1, h = 3 },
            { x = 14, y = 8, w = 2, h = 1 },
            { x = 7, y = 8, w = 3, h = 2 },
        },
        features = {
            {
                id = "starter_chest",
                kind = "chest",
                asset = "chest",
                x = 14,
                y = 8,
                w = 1,
                h = 1,
                solid = true,
                draw = { w = 1.0, h = 1.0, ox = 0.0, oy = 0.0 },
                name = "教皇的礼物",
                rewardCardIds = { "gravity_formula", "vector_direction" },
                itemId = "pope_cards",
                itemName = "黄色基础卡与矢量改向卡",
                amount = 1,
                lines = {
                    "箱盖内侧烙着教皇的太阳纹章。",
                    "丝绒衬垫上放着黄色的 F=MG 基础卡，以及一张紫色的矢量改向卡。",
                },
            },
            {
                id = "father_map",
                kind = "map",
                hidden = true,
                x = 8,
                y = 8,
                w = 1,
                h = 1,
                solid = false,
                name = "桌上的登塔笔记",
                lines = { "摊开的笔记标出了塔的前九层，第九层旁留着父亲最后的字迹。" },
            },
        },
    },
    home_lower = {
        name = "候选者之家 · 一楼",
        subtitle = "壁炉、厨房与餐厅围绕中央起居区展开。",
        width = 15,
        height = 10,
        backgroundImage = "optionRoomLower",
        spawn = { x = 7, y = 8 },
        portals = {
            { x = 7, y = 10, target = "village", spawnX = 7, spawnY = 9 },
        },
        transitions = {
            {
                id = "stairs_up",
                x = 2,
                y = 7,
                w = 2,
                h = 2,
                target = "home_upper",
                spawnX = 4,
                spawnY = 7,
                proximity = 0.95,
            },
        },
        npcs = {
            {
                id = "mother",
                name = "母亲 · 塞拉",
                x = 8,
                y = 6,
                color = "mother",
                sprite = "npcMother",
                portrait = "image/母亲塞拉像素头像_20260727072703.png",
                lines = {
                    "总算下来啦。今天可是你正式参加爬塔候选的日子。",
                    "出发前还有一件东西要交给你。教皇送来的生日礼物就放在二楼。",
                    "先去看看吧。等准备好了，再带上邀请函去教堂见主教。",
                },
            },
        },
        -- 碰撞设计（15×10）：
        -- 西侧楼梯是触发区；沙发、壁炉、厨房、餐桌与隔墙均阻挡。
        -- 南侧正门在 (7,10) 留出单格出口，避免门槛卡住自动传送。
        collision = {
            { x = 1, y = 2, w = 4, h = 1 },
            { x = 1, y = 3, w = 4, h = 2 },
            { x = 2, y = 2, w = 2, h = 2 },
            { x = 7, y = 2, w = 2, h = 2 },
            { x = 10, y = 2, w = 2, h = 2 },
            { x = 13, y = 2, w = 3, h = 2 },
            { x = 9, y = 1, w = 1, h = 4 },
            { x = 9, y = 5, w = 1, h = 3 },
            { x = 11, y = 5, w = 3, h = 3 },
            { x = 14, y = 4, w = 1, h = 3 },
            { x = 6, y = 4, w = 2, h = 3 },
        },
        features = {},
    },
}

local function BuildOptionRoom(id)
    local spec = OPTION_ROOMS[id]
    local tiles = Fill(spec.width, spec.height, "stoneFloor")
    local solids = {}

    for x = 1, spec.width do
        solids["1:" .. x] = true
        solids[spec.height .. ":" .. x] = true
    end
    for y = 1, spec.height do
        solids[y .. ":1"] = true
        solids[y .. ":" .. spec.width] = true
    end

    for _, rect in ipairs(spec.collision or {}) do
        AddSolidRect(solids, rect.x, rect.y, rect.w, rect.h)
    end

    local portals = {}
    for _, portal in ipairs(spec.portals or {}) do
        local key = portal.y .. ":" .. portal.x
        solids[key] = nil
        portals[key] = {
            target = portal.target,
            x = portal.spawnX,
            y = portal.spawnY,
            mode = portal.mode,
            roomId = portal.roomId,
            returnMap = portal.returnMap,
            returnX = portal.returnX,
            returnY = portal.returnY,
            returnDirection = portal.returnDirection,
        }
    end

    return {
        id = id,
        name = spec.name,
        subtitle = spec.subtitle,
        width = spec.width,
        height = spec.height,
        tiles = tiles,
        solids = solids,
        portals = portals,
        transitions = spec.transitions or {},
        spawn = spec.spawn,
        npcs = spec.npcs or {},
        features = spec.features or {},
        objects = {},
        buildings = {},
        backgroundImage = spec.backgroundImage,
    }
end

local function BuildInterior(id)
    local spec = INTERIORS[id]
    local width = spec.width or 13
    local height = spec.height or 11
    local tiles = Fill(width, height, spec.floor or "floor")
    local solids = {}

    -- 碰撞示意：W=一整格墙体，D=可通行门洞，F=室内地板。
    -- WWWWWWWWWWWWW
    -- WFFFFFFFFFFFW
    -- WWWWWWDWWWWWW
    for x = 1, width do
        tiles[1][x] = "wallTop"
        tiles[height][x] = "wallBottom"
        solids["1:" .. x] = true
        solids[height .. ":" .. x] = true
    end
    for y = 2, height - 1 do
        tiles[y][1] = "wallLeft"
        tiles[y][width] = "wallRight"
        solids[y .. ":1"] = true
        solids[y .. ":" .. width] = true
    end
    tiles[1][1] = "wallTop"
    tiles[1][width] = "wallTop"
    tiles[height][1] = "wallBottom"
    tiles[height][width] = "wallBottom"

    local portals = {}
    for _, portal in ipairs(spec.portals or {}) do
        local key = portal.y .. ":" .. portal.x
        solids[key] = nil
        tiles[portal.y][portal.x] = "doorway"
        portals[key] = {
            target = portal.target,
            x = portal.spawnX,
            y = portal.spawnY,
        }
    end

    local objects = {}
    for _, object in ipairs(spec.objects or {}) do
        table.insert(objects, object)
        AddObjectCollision(solids, object)
    end

    for _, rect in ipairs(spec.collision or {}) do
        AddSolidRect(solids, rect.x, rect.y, rect.w, rect.h)
    end

    -- 自定义碰撞矩形可能覆盖门洞，传送点最终必须保持可通行。
    for _, portal in ipairs(spec.portals or {}) do
        solids[portal.y .. ":" .. portal.x] = nil
        tiles[portal.y][portal.x] = "doorway"
    end

    local features = {}
    for _, feature in ipairs(spec.features or {}) do
        table.insert(features, feature)
        if feature.solid ~= false then
            AddSolidRect(solids, feature.x, feature.y, feature.w or 1, feature.h or 1)
        end
    end

    return {
        id = id,
        name = spec.name,
        subtitle = spec.subtitle,
        width = width,
        height = height,
        tiles = tiles,
        solids = solids,
        portals = portals,
        transitions = spec.transitions or {},
        spawn = spec.spawn,
        npcs = spec.npcs or {},
        features = features,
        objects = objects,
        backgroundImage = spec.backgroundImage,
    }
end

function Maps.Get(id)
    if id == "village" then return BuildVillage() end
    if OPTION_ROOMS[id] ~= nil then return BuildOptionRoom(id) end
    if INTERIORS[id] ~= nil then return BuildInterior(id) end
    return BuildVillage()
end

function Maps.GetFirstPersonRoom(id)
    return FIRST_PERSON_ROOMS[id]
end

function Maps.ExpandCoarseSolids(map)
    local fineSolids = {}
    for key, solid in pairs(map.solids or {}) do
        if solid then
            local coarseYText, coarseXText = key:match("^(%-?%d+):(%-?%d+)$")
            local coarseX = tonumber(coarseXText)
            local coarseY = tonumber(coarseYText)
            if coarseX ~= nil and coarseY ~= nil then
                local startX = (coarseX - 1) * FINE_CELLS_PER_TILE + 1
                local startY = (coarseY - 1) * FINE_CELLS_PER_TILE + 1
                for fineY = startY, startY + FINE_CELLS_PER_TILE - 1 do
                    for fineX = startX, startX + FINE_CELLS_PER_TILE - 1 do
                        fineSolids[FineCellKey(fineX, fineY)] = true
                    end
                end
            end
        end
    end
    return fineSolids
end

function Maps.IsSolidAt(map, worldX, worldY)
    if worldX < 0.5 or worldY < 0.5
        or worldX >= map.width + 0.5 or worldY >= map.height + 0.5 then
        return true
    end

    if map.collisionDisabled then return false end

    local tileX = math.floor(worldX + 0.5)
    local tileY = math.floor(worldY + 0.5)
    if map.fineCollision then
        local fineX = math.floor((worldX - 0.5) * FINE_CELLS_PER_TILE) + 1
        local fineY = math.floor((worldY - 0.5) * FINE_CELLS_PER_TILE) + 1
        if map.fineSolids ~= nil and map.fineSolids[FineCellKey(fineX, fineY)] then
            return true
        end
    elseif map.solids[tileY .. ":" .. tileX] then
        return true
    end

    for _, npc in ipairs(map.npcs or {}) do
        if npc.solid ~= false and npc.x == tileX and npc.y == tileY then return true end
    end
    return false
end

function Maps.IsSolid(map, x, y)
    if x < 1 or y < 1 or x > map.width or y > map.height then return true end
    if map.collisionDisabled then return false end
    if map.solids[y .. ":" .. x] then return true end
    for _, npc in ipairs(map.npcs or {}) do
        if npc.solid ~= false and npc.x == x and npc.y == y then return true end
    end
    return false
end

function Maps.GetPortal(map, x, y)
    return map.portals[y .. ":" .. x]
end

function Maps.GetFacingTarget(map, x, y)
    for _, npc in ipairs(map.npcs or {}) do
        if npc.x == x and npc.y == y then return npc end
    end
    for _, feature in ipairs(map.features or {}) do
        local width = feature.w or 1
        local height = feature.h or 1
        if x >= feature.x and x < feature.x + width and y >= feature.y and y < feature.y + height then
            return feature
        end
    end
    return nil
end

return Maps
