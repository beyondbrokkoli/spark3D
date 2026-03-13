-- core/vision_alt.lua
require("core.palette")
local ffi = require("ffi")

VISION = {}
VISION.angle = 0

function VISION.Update(dt)
    VISION.angle = VISION.angle + dt
end

function VISION.Draw(viewW, viewH, cellSize)
    local w, h = love.graphics.getDimensions()
    
    -- 1. Sync the 3D "Projection Power" with the 2D Zoom
    -- This ensures the cube grows at the same rate as the background grid
    local baseFocal = 500
    local focalLength = baseFocal * cellSize
    
    -- 2. The world-mid is our anchor point in world-space pixels
    local worldMid = (NODE.SIZE / 2) * cellSize
    local relCenterX = worldMid - CAMERA.x
    local relCenterY = worldMid - CAMERA.y
    
    local cubeSize, numSlices = 64, 64
    local zOffset = 2.5 

    local cosA, sinA = math.cos(VISION.angle), math.sin(VISION.angle)
    local cosB, sinB = math.cos(VISION.angle * 0.5), math.sin(VISION.angle * 0.5)

    love.graphics.setColor(PALETTE.ACTIVE)

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
                        
                        -- Atom size scales with both distance (1/z) and engine zoom
                        local atomSize = (1 / finalZ) * cellSize * 1.5
                        
                        love.graphics.rectangle("fill", screenX, screenY, atomSize, atomSize)
                    end
                end
            end
        end
    end
end
