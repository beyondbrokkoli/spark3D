-- core/vision_alt.lua
require("core.palette")
local ffi = require("ffi")
VISION = { angle = 0, buffer = nil, img = nil, ptr = nil }

function VISION.Update(dt)
    VISION.angle = VISION.angle + dt
end

function VISION.Init()
    local w, h = love.graphics.getDimensions()
    VISION.buffer = love.image.newImageData(w, h)
    VISION.img = love.graphics.newImage(VISION.buffer)
    VISION.ptr = ffi.cast("uint32_t*", VISION.buffer:getPointer())
end

function VISION.Draw(viewW, viewH, cellSize)
    local w, h = love.graphics.getDimensions()
    if not VISION.ptr then VISION.Init() end

    -- Clear the buffer (Black/Transparent)
    ffi.fill(VISION.ptr, w * h * 4, 0)

    local focalLength = 500 * cellSize
    local worldMid = (NODE.SIZE / 2) * cellSize
    local relCenterX = worldMid - CAMERA.x
    local relCenterY = worldMid - CAMERA.y
    local zOffset = 2.5
    
    local cosA, sinA = math.cos(VISION.angle), math.sin(VISION.angle)
    local cosB, sinB = math.cos(VISION.angle * 0.5), math.sin(VISION.angle * 0.5)

    local color = 0xFFBB9933 -- AABBGGRR (Blue-ish)

    local cubeSize, numSlices = 64, 64

    for z = 0, numSlices - 1 do
        local sliceOffset = z * cubeSize * NODE.SIZE
        local localZ = (z / numSlices) - 0.5 

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
                        -- The projection now respects the cellSize-based Focal Length
                        local screenX = (rx / finalZ) * focalLength + relCenterX
                        local screenY = (ry / finalZ) * focalLength + relCenterY
                        
                        -- Inside the loop, after calculating screenX and screenY:
                        local ix, iy = math.floor(screenX), math.floor(screenY)
                        if ix >= 0 and ix < w and iy >= 0 and iy < h then
                            -- Direct pixel write: Index = (y * width) + x
                            VISION.ptr[iy * w + ix] = color
                        end
                    end
                end
            end
        end
    end
    -- Upload to VRAM once
    VISION.img:replacePixels(VISION.buffer)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(VISION.img, 0, 0)
end
