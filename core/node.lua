-- core/node.lua
local ffi = require("ffi")
local bit = require("bit")

NODE = {
    FLAGS = { SOLID=1, LIT=2, DIRTY=4, DATA=8 },
    BUFFER = nil,
    SIZE = 0
}

CHUNK_SIZE = 32
CHUNKS = {}

function NODE.Init(size)
    NODE.SIZE = size
    NODE.BUFFER = ffi.new("uint8_t[?]", (size * size) + 1)

    local chunksAcross = math.ceil(size / CHUNK_SIZE)
    local totalChunks = chunksAcross * chunksAcross

    CHUNKS = {}
    for i = 0, totalChunks - 1 do
        -- 1. Create the raw data buffer (RAM)
        local data = love.image.newImageData(CHUNK_SIZE, CHUNK_SIZE)

        -- 2. Create the actual GPU texture (VRAM) immediately
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")

        CHUNKS[i] = {
            isDirty = true,
            data = data,
            img = img -- No more nil!
        }
    end
end

function NODE.Update(idx, flag, operation)
    -- 1. Standard Bitwise Update
    local val = NODE.BUFFER[idx]
    if operation == "SET" then val = bit.bor(val, flag)
    elseif operation == "CLEAR" then val = bit.band(val, bit.bnot(flag))
    end
    NODE.BUFFER[idx] = bit.bor(val, NODE.FLAGS.DIRTY)

    -- 2. Correct 2D Chunk Mapping
    local gx = ((idx - 1) % NODE.SIZE) + 1
    local gy = math.floor((idx - 1) / NODE.SIZE) + 1

    local cx = math.floor((gx - 1) / CHUNK_SIZE)
    local cy = math.floor((gy - 1) / CHUNK_SIZE)
    local chunksAcross = math.ceil(NODE.SIZE / CHUNK_SIZE)
    local chunkIdx = (cy * chunksAcross) + cx

    if CHUNKS[chunkIdx] then
        CHUNKS[chunkIdx].isDirty = true
    end
end

function NODE.Has(nodeValue, flag)
    return bit.band(nodeValue, flag) ~= 0
end

function NODE.Set(nodeValue, flag)
    return bit.bor(nodeValue, flag)
end

function NODE.Clear(nodeValue, flag)
    return bit.band(nodeValue, bit.bnot(flag))
end
