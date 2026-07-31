local CELL = 64
local WALK_FRAME_COUNT = 12

local function Frames(count)
    local frames = {}
    for index = 1, count do
        frames[index] = {
            (index - 1) * CELL,
            0,
            CELL,
            CELL,
            0,
            0,
        }
    end
    return frames
end

return {
    walk = {
        down = { atlasW = WALK_FRAME_COUNT * CELL, atlasH = CELL, frames = Frames(WALK_FRAME_COUNT) },
        up = { atlasW = WALK_FRAME_COUNT * CELL, atlasH = CELL, frames = Frames(WALK_FRAME_COUNT) },
        left = { atlasW = WALK_FRAME_COUNT * CELL, atlasH = CELL, frames = Frames(WALK_FRAME_COUNT) },
        right = { atlasW = WALK_FRAME_COUNT * CELL, atlasH = CELL, frames = Frames(WALK_FRAME_COUNT) },
    },
    idle = {
        down = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
        up = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
        left = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
        right = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
    },
}
