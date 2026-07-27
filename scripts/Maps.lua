local Maps = {}

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
    local width, height = 28, 22
    local tiles = Fill(width, height, "grass")
    Rect(tiles, 12, 1, 16, height, "road")
    Rect(tiles, 3, 10, 25, 13, "road")
    Rect(tiles, 9, 15, 19, 20, "plaza")
    Rect(tiles, 10, 16, 18, 19, "tower")

    local buildings = {
        { id = "home", target = "home_lower", name = "候选者之家", x = 4, y = 3, w = 6, h = 5, doorX = 7, doorY = 8 },
        { id = "guild", name = "勇者公会", x = 18, y = 3, w = 7, h = 6, doorX = 21, doorY = 9 },
        { id = "inn", name = "登塔人旅店", x = 3, y = 14, w = 6, h = 5, doorX = 6, doorY = 19 },
        { id = "forge", name = "风轮工坊", x = 20, y = 14, w = 6, h = 5, doorX = 23, doorY = 19 },
    }

    local solids = {}
    local portals = {}
    for _, building in ipairs(buildings) do
        AddSolidRect(solids, building.x, building.y, building.w, building.h)
        portals[building.doorY .. ":" .. building.doorX] = {
            target = building.target or building.id,
            x = 7,
            y = 9,
        }
    end

    local objects = {
        { kind = "well", x = 17, y = 11, w = 1, h = 1, solid = true },
        { kind = "tree", x = 2, y = 2, w = 1, h = 1, solid = true, draw = { w = 2, h = 3, ox = -0.5, oy = -2 } },
        { kind = "tree", x = 26, y = 4, w = 1, h = 1, solid = true, draw = { w = 2, h = 3, ox = -0.5, oy = -2 } },
        { kind = "flowers", x = 9, y = 9, w = 1, h = 1 },
        { kind = "flowers", x = 18, y = 13, w = 1, h = 1 },
        { kind = "sign", x = 10, y = 12, w = 1, h = 1, solid = true },
    }
    for _, object in ipairs(objects) do
        AddObjectCollision(solids, object)
    end

    return {
        id = "village",
        name = "塔环国 · 垂环镇",
        subtitle = "道路环绕世界塔延伸，勇者的故事从这里开始。",
        width = width,
        height = height,
        tiles = tiles,
        buildings = buildings,
        solids = solids,
        portals = portals,
        spawn = { x = 7, y = 9 },
        npcs = {
            {
                id = "mira", name = "米拉", x = 11, y = 12, color = "green", sprite = "npcMira",
                portrait = "image/村民米拉像素头像_20260727071205.png",
                lines = {
                    "洛恩，你终于出门啦！今天可是勇者候选登记日。",
                    "一直沿着石路向东走，红屋顶的建筑就是勇者公会。",
                },
            },
        },
        objects = objects,
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
                draw = { w = 2.35, h = 1.35, ox = -0.18, oy = -0.35 },
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
            { x = 7, y = 11, target = "village", spawnX = 7, spawnY = 9, kind = "exitDoor" },
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
        portals = { { x = 7, y = 11, target = "village", spawnX = 21, spawnY = 10, kind = "exitDoor" } },
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
        portals = { { x = 7, y = 11, target = "village", spawnX = 6, spawnY = 20, kind = "exitDoor" } },
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
        portals = { { x = 7, y = 11, target = "village", spawnX = 23, spawnY = 20, kind = "exitDoor" } },
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
}

local function BuildInterior(id)
    local spec = INTERIORS[id]
    local width, height = 13, 11
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
    }
end

function Maps.Get(id)
    if id == "village" then return BuildVillage() end
    return BuildInterior(id)
end

function Maps.IsSolid(map, x, y)
    if x < 1 or y < 1 or x > map.width or y > map.height then return true end
    if map.solids[y .. ":" .. x] then return true end
    for _, npc in ipairs(map.npcs or {}) do
        if npc.x == x and npc.y == y then return true end
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
