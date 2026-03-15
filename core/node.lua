-- core/node.lua
local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
    typedef struct {
        int x, y, z;
        int w, h, d;
        float rx, ry, rz;
        bool active;
        uint32_t id;
        uint32_t color;
        uint32_t vOffset;
        uint32_t flags;
    } NodeObject;
]]

NODE = {
    FLAGS = { SOLID=1, LIT=2, DIRTY=4, DATA=8, FIXED=16 },
    BUFFER = nil,
    STRIDE = 0,
    MAX_OBJECTS = 512,
    OBJECTS = nil,
    objCount = 0
}

CHUNK_SIZE = 32
CHUNKS = {}

function NODE.Init(stride)
    NODE.STRIDE = stride
    NODE.BUFFER = ffi.new("uint8_t[?]", (stride * stride) + 1)
    NODE.OBJECTS = ffi.new("NodeObject[?]", NODE.MAX_OBJECTS)

    local chunksAcross = math.ceil(stride / CHUNK_SIZE)
    for i = 0, (chunksAcross * chunksAcross) - 1 do
        local data = love.image.newImageData(CHUNK_SIZE, CHUNK_SIZE)
        local img = love.graphics.newImage(data)
        img:setFilter("nearest", "nearest")
        CHUNKS[i] = { isDirty = true, data = data, img = img }
    end
end

function NODE.CreateObject(x, y, z, w, h, d, color, vOffset, flags)
    if NODE.objCount >= NODE.MAX_OBJECTS then return nil end
    local obj = NODE.OBJECTS[NODE.objCount]
    -- ... existing assignments ...
    obj.x, obj.y, obj.z = x, y, z
    obj.w, obj.h, obj.d = w, h, d
    obj.rx, obj.ry, obj.rz = 0, 0, 0
    obj.active = true
    obj.id = NODE.objCount
    obj.color = color or 0xFFCCAA33
    obj.vOffset = vOffset or 0
    -- added new flags logic
    obj.flags = flags or 0 -- Set the flags here
    -- ...
    NODE.objCount = NODE.objCount + 1
    return obj
end

-- Helpers
function NODE.Has(nodeValue, flag) return bit.band(nodeValue, flag) ~= 0 end
function NODE.Set(nodeValue, flag) return bit.bor(nodeValue, flag) end
function NODE.Clear(nodeValue, flag) return bit.band(nodeValue, bit.bnot(flag)) end

-- x, y, z: local coordinate within the template
-- w, h: the width and height of the template (used for vertical slicing)
function NODE.GetIndex(x, y, z, w, h)
    -- A "Slice" jump must be (height * STRIDE)
    local sliceOffset = z * h * NODE.STRIDE
    -- A "Row" jump must be (STRIDE)
    local rowOffset = y * NODE.STRIDE

    return sliceOffset + rowOffset + x + 1
end

