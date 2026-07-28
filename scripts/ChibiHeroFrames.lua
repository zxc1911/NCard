local CELL = 67

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
        down = { atlasW = 17 * CELL, atlasH = CELL, frames = Frames(17) },
        up = { atlasW = 18 * CELL, atlasH = CELL, frames = Frames(18) },
        left = { atlasW = 16 * CELL, atlasH = CELL, frames = Frames(16) },
        right = { atlasW = 26 * CELL, atlasH = CELL, frames = Frames(26) },
    },
    idle = {
        down = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
        up = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
        left = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
        right = { atlasW = CELL, atlasH = CELL, frames = Frames(1) },
    },
}
