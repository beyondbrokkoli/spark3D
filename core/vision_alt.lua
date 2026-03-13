-- core/vision_alt.lua
require("core.palette")
local ffi = require("ffi")
local bit = require("bit")

VISION = {  
    angle = 0, buffer = nil, img = nil, ptr = nil,
    w = 0, h = 0,
    -- Bounding box for the "Dirty Region"
    minX = 0, minY = 0, maxX = 0, maxY = 0
}

function VISION.Init3D()
    local w, h = love.graphics.getDimensions()
    VISION.w, VISION.h = w, h
    VISION.buffer = love.image.newImageData(w, h)
    VISION.img = love.graphics.newImage(VISION.buffer)
    VISION.ptr = ffi.cast("uint32_t*", VISION.buffer:getPointer())
    -- Initial box covers screen
    VISION.minX, VISION.minY = 0, 0
    VISION.maxX, VISION.maxY = w - 1, h - 1
end

-- Restored 2D logic remains same as previous turn...
-- [Insert Draw2D here]

-- --- 2D CHUNK LOGIC (The "Magic Trick") ---

local function rebuildChunk(cIdx)
    local chunk = CHUNKS[cIdx]
    if not chunk then return end
    
    local chunksAcross = math.ceil(NODE.SIZE / CHUNK_SIZE)
    local cy, cx = math.floor(cIdx / chunksAcross), cIdx % chunksAcross
    local startGX, startGY = cx * CHUNK_SIZE + 1, cy * CHUNK_SIZE + 1
    local white, transparent = 0xFFFFFFFF, 0x00000000
    local pointer = ffi.cast("uint32_t*", chunk.data:getPointer())

    for y = 0, CHUNK_SIZE - 1 do
        local gy = startGY + y
        local rowBase = (gy - 1) * NODE.SIZE
        local rowPtr = pointer + (y * CHUNK_SIZE)
        for x = 0, CHUNK_SIZE - 1 do
            local gx = startGX + x
            local val = NODE.BUFFER[rowBase + gx]
            rowPtr[x] = bit.band(val, NODE.FLAGS.SOLID) ~= 0 and white or transparent
        end
    end
    chunk.img:replacePixels(chunk.data)
    chunk.isDirty = false
end

function VISION.Draw2D(viewW, viewH, cellSize)
    local chunksAcross = math.ceil(NODE.SIZE / CHUNK_SIZE)
    local startCX = math.floor(CAMERA.x / (CHUNK_SIZE * cellSize))
    local startCY = math.floor(CAMERA.y / (CHUNK_SIZE * cellSize))
    local endCX = math.floor((CAMERA.x + (viewW * cellSize)) / (CHUNK_SIZE * cellSize))
    local endCY = math.floor((CAMERA.y + (viewH * cellSize)) / (CHUNK_SIZE * cellSize))

    -- Clamp boundaries
    startCX, startCY = math.max(0, startCX), math.max(0, startCY)
    endCX = math.min(chunksAcross - 1, endCX)
    endCY = math.min(chunksAcross - 1, endCY)

    love.graphics.setColor(1, 1, 1, 1) -- Keep chunks original color
    for cy = startCY, endCY do
        local rowOffset = cy * chunksAcross
        for cx = startCX, endCX do
            local cIdx = rowOffset + cx
            local chunk = CHUNKS[cIdx]
            if chunk then
                if chunk.isDirty then rebuildChunk(cIdx) end
                local drawX = (cx * CHUNK_SIZE * cellSize) - CAMERA.x
                local drawY = (cy * CHUNK_SIZE * cellSize) - CAMERA.y
                love.graphics.draw(chunk.img, drawX, drawY, 0, cellSize, cellSize)
            end
        end
    end
end


function VISION.Draw3D(cellSize)
    local w, h = love.graphics.getDimensions()
    
    -- SAFETY: Re-init if window size changed (fixes fullscreen crash)
    if not VISION.ptr or w ~= VISION.w or h ~= VISION.h then 
        VISION.Init3D() 
    end

    -- 1. DIRTY CLEAR: Only clear the area used last frame
    for y = VISION.minY, VISION.maxY do
        local row = y * w
        ffi.fill(VISION.ptr + row + VISION.minX, (VISION.maxX - VISION.minX + 1) * 4, 0)
    end

    -- Reset box for current frame
    local curMinX, curMinY = w, h
    local curMaxX, curMaxY = 0, 0

    local focalLength = 500 * cellSize
    local worldMid = (NODE.SIZE / 2) * cellSize
    local relCenterX, relCenterY = worldMid - CAMERA.x, worldMid - CAMERA.y
    local zOffset = 2.5
    local cosA, sinA = math.cos(VISION.angle), math.sin(VISION.angle)
    local cosB, sinB = math.cos(VISION.angle * 0.5), math.sin(VISION.angle * 0.5)
    
    -- Endian-safe Blue/Teal: 0xAABBGGRR
    local color = 0xFFCCAA33  
    local cubeSize = 64

    for z = 0, cubeSize - 1 do
        local sliceOffset = z * cubeSize * NODE.SIZE
        local localZ = (z / cubeSize) - 0.5   
        for y = 0, cubeSize - 1 do
            local rowOffset = sliceOffset + (y * NODE.SIZE)
            local localY = (y / cubeSize) - 0.5
            for x = 0, cubeSize - 1 do
                local idx = rowOffset + x + 1
                if bit.band(NODE.BUFFER[idx], NODE.FLAGS.SOLID) ~= 0 then
                    local localX = (x / cubeSize) - 0.5
                    
                    -- Rotation
                    local rx = localX * cosA - localZ * sinA
                    local rz = localX * sinA + localZ * cosA
                    local ry = localY * cosB - rz * sinB
                    rz = localY * sinB + rz * cosB
                    local finalZ = rz + zOffset

                    if finalZ > 0.1 then   
                        local ix = math.floor((rx / finalZ) * focalLength + relCenterX)
                        local iy = math.floor((ry / finalZ) * focalLength + relCenterY)
                        
                        if ix >= 0 and ix < w and iy >= 0 and iy < h then
                            VISION.ptr[iy * w + ix] = color
                            
                            -- Expand current frame's bounding box
                            if ix < curMinX then curMinX = ix end
                            if ix > curMaxX then curMaxX = ix end
                            if iy < curMinY then curMinY = iy end
                            if iy > curMaxY then curMaxY = iy end
                        end
                    end
                end
            end
        end
    end
    
    -- Store box for clearing next frame
    VISION.minX, VISION.minY = curMinX, curMinY
    VISION.maxX, VISION.maxY = curMaxX, curMaxY

    VISION.img:replacePixels(VISION.buffer)
    love.graphics.draw(VISION.img, 0, 0)
end

function VISION.Update(dt)
    VISION.angle = VISION.angle + dt
end
