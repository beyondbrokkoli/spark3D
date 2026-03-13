-- core/region.lua
local bit = require("bit")
REGION = {}

local function markChunksDirty(x1, y1, x2, y2)
    local chunksAcross = math.ceil(NODE.SIZE / CHUNK_SIZE)
    local startCX = math.floor((x1 - 1) / CHUNK_SIZE)
    local endCX   = math.floor((x2 - 1) / CHUNK_SIZE)
    local startCY = math.floor((y1 - 1) / CHUNK_SIZE)
    local endCY   = math.floor((y2 - 1) / CHUNK_SIZE)

    for cy = startCY, endCY do
        for cx = startCX, endCX do
            local cIdx = (cy * chunksAcross) + cx
            if CHUNKS[cIdx] then CHUNKS[cIdx].isDirty = true end
        end
    end
end

function REGION.Apply(x1, y1, x2, y2, flag, operation)
    local size, buffer = NODE.SIZE, NODE.BUFFER
    x1, x2 = math.max(1, x1), math.min(size, x2)
    y1, y2 = math.max(1, y1), math.min(size, y2)

    for y = y1, y2 do
        local rowOffset = (y - 1) * size
        for x = x1, x2 do
            local idx = rowOffset + x
            if operation == "SET" then
                buffer[idx] = bit.bor(buffer[idx], flag)
            else
                buffer[idx] = bit.band(buffer[idx], bit.bnot(flag))
            end
        end
    end
    markChunksDirty(x1, y1, x2, y2)
end

function REGION.RandomFill(x1, y1, x2, y2, density)
    local size, buffer = NODE.SIZE, NODE.BUFFER
    x1, x2 = math.max(1, x1), math.min(size, x2)
    y1, y2 = math.max(1, y1), math.min(size, y2)

    for y = y1, y2 do
        local rowOffset = (y - 1) * size
        for x = x1, x2 do
            if math.random() < (density or 0.5) then
                local idx = rowOffset + x
                buffer[idx] = bit.bor(buffer[idx], NODE.FLAGS.SOLID)
            end
        end
    end
    markChunksDirty(x1, y1, x2, y2)
end
