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
    local width, height = 28, 21
    local tiles = Fill(width, height, "grass")
    local solids = {}

    -- 外景暂不启用碰撞，只保留房屋入口传送。
    local portals = {
        ["11:10"] = { target = "home_lower", x = 7, y = 9 },
        ["16:14"] = { target = "guild", x = 7, y = 9 },
        ["12:18"] = { target = "inn", x = 7, y = 9 },
        ["18:21"] = { target = "forge", x = 7, y = 9 },
    }

    return {
        id = "village",
        name = "塔环国 · 垂环镇",
        subtitle = "世界塔之门俯视着城墙内的山谷村庄。",
        width = width,
        height = height,
        backgroundImage = "villageBackground",
        collisionDisabled = true,
        tiles = tiles,
        buildings = {},
        solids = solids,
        portals = portals,
        spawn = { x = 14, y = 17 },
        npcs = {
            {
                id = "mira", name = "米拉", x = 12, y = 11, color = "green", sprite = "npcMira", solid = false,
                portrait = "image/村民米拉像素头像_20260727071205.png",
                lines = {
                    "洛恩，你终于来了！世界塔的大门就在北面石阶尽头。",
                    "中央的红褐色宫殿负责登记候选者，沿主路向北就能看见。",
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
}

local FIRST_PERSON_ROOMS = {
    six_face_room = {
        id = "six_face_room",
        name = "高塔 · 六面谜室",
        initialView = "door",
        views = {
            door = {
                name = "塔纹章之门",
                image = "fpDoor",
                left = "shelves",
                right = "window",
                up = "ceiling",
                down = "floor",
                hotspot = { x = 0.39, y = 0.18, w = 0.22, h = 0.64 },
                target = {
                    hidePortrait = true,
                    name = "塔纹章之门",
                    lines = {
                        "黄铜纹章像一座倒悬的高塔。门把手很冷。",
                        "这扇门通往垂环镇。按下离开按钮即可返回。",
                    },
                },
            },
            window = {
                name = "高塔之窗",
                image = "fpWindow",
                left = "door",
                right = "mirror",
                up = "ceiling",
                down = "floor",
                cardTargets = {
                    {
                        x = 0.66,
                        y = 0.17,
                        w = 0.12,
                        h = 0.18,
                        objectId = "gravity_letter",
                        acceptedCard = "gravity_formula",
                        effectName = "高处的信件",
                        effectLines = {
                            "F=MG 的符号化为一道向下的箭头，信件终于受到重力牵引。",
                            "它从高处飘落，轻轻落在窗边书桌上。",
                        },
                    },
                },
                hotspot = {
                    x = 0.35, y = 0.10, w = 0.30, h = 0.58,
                    objectId = "tower_blocks",
                    acceptedCard = "tower_ink",
                    effectName = "六枚机关块",
                    effectLines = {
                        "塔影墨水渗入铜块的刻痕，六枚机关块依次转向。",
                        "它们最终拼成一句话：镜中缺失的墙，藏在鸟鸣之后。",
                    },
                },
                target = {
                    hidePortrait = true,
                    name = "拱形窗",
                    lines = {
                        "窗外的塔影没有随云层移动。",
                        "六枚铜块排列在桌面上，其中一枚刻着向下的箭头。",
                    },
                },
            },
            mirror = {
                name = "裂镜",
                image = "fpMirror",
                left = "window",
                right = "shelves",
                up = "ceiling",
                down = "floor",
                hotspot = {
                    x = 0.33, y = 0.08, w = 0.34, h = 0.58,
                    objectId = "cracked_mirror",
                    acceptedCard = "mirror_dust",
                    effectName = "裂开的镜子",
                    effectLines = {
                        "镜尘沿裂纹发出银光，迟缓的倒影终于与你同步。",
                        "第七面墙的影子里，浮现出一只上紧发条的机械鸟。",
                    },
                },
                target = {
                    hidePortrait = true,
                    name = "裂开的镜子",
                    lines = {
                        "镜中的房间比现实多出第七面墙。",
                        "你的倒影慢了半拍才抬起头。",
                    },
                },
            },
            shelves = {
                name = "标本书架",
                image = "fpShelves",
                left = "mirror",
                right = "door",
                up = "ceiling",
                down = "floor",
                hotspot = {
                    x = 0.40, y = 0.38, w = 0.18, h = 0.32,
                    objectId = "mechanical_bird",
                    acceptedCard = "clockwork_spring",
                    effectName = "机械鸟标本",
                    effectLines = {
                        "发条嵌入胸腔，机械鸟抖落灰尘，短促地鸣叫六声。",
                        "每次鸣叫都指向不同方向，最后停在天花板的吊灯上。",
                    },
                },
                target = {
                    hidePortrait = true,
                    name = "机械鸟标本",
                    lines = {
                        "机械鸟的胸腔里藏着三个旋钮，全都指向同一个方向。",
                        "空相框背后写着：先看脚下，再看头顶。",
                    },
                },
            },
            ceiling = {
                name = "六烛天花板",
                image = "fpCeiling",
                down = "door",
                left = "shelves",
                right = "window",
                hotspot = {
                    x = 0.35, y = 0.20, w = 0.30, h = 0.55,
                    objectId = "six_candle_lamp",
                    acceptedCard = "ember_rune",
                    effectName = "六角吊灯",
                    effectLines = {
                        "余烬符化作六点火光，依次点亮吊灯上的蜡烛。",
                        "锁链被热力拉直，暗门深处随之响起清脆的开锁声。",
                    },
                },
                target = {
                    hidePortrait = true,
                    name = "六角吊灯",
                    lines = {
                        "六根蜡烛围成不完整的圆，中央垂着一条生锈锁链。",
                        "木梁上刻着一把钥匙，但那只是浅浅的凹痕。",
                    },
                },
            },
            floor = {
                name = "暗门地板",
                image = "fpFloor",
                up = "door",
                left = "shelves",
                right = "window",
                hotspot = {
                    x = 0.31, y = 0.16, w = 0.40, h = 0.68,
                    objectId = "floor_hatch",
                    acceptedCard = "brass_key",
                    effectName = "地毯下的暗门",
                    effectLines = {
                        "黄铜钥匙没入锁孔，六枚石片同时向外滑开。",
                        "暗门已经解锁，但更深处的道路仍被塔的黑暗吞没。",
                    },
                },
                target = {
                    hidePortrait = true,
                    name = "地毯下的暗门",
                    lines = {
                        "六枚石片围住钥匙孔，却没有一枚能插进去。",
                        "暗门下面传来缓慢而均匀的敲击声。",
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
                hidden = true,
                x = 8,
                y = 5,
                w = 1,
                h = 1,
                solid = false,
                name = "二楼储物柜",
                itemId = "healing_herb",
                itemName = "药草",
                amount = 3,
                lines = { "储物柜里放着出发前准备好的补给。" },
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
                    "洛恩，早饭已经准备好了。今天就是候选登记的日子吧？",
                    "你父亲也曾站在这扇门前，带着一样紧张又期待的表情。",
                    "二楼的储物柜里有三株药草，出门前记得带上。",
                    "不管你能爬到塔的第几层，这里永远是你的家。",
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
    if OPTION_ROOMS[id] ~= nil then return BuildOptionRoom(id) end
    return BuildInterior(id)
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
