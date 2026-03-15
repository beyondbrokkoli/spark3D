-- core/vision.lua
local ffi = require("ffi")
local bit = require("bit")

VISION = {
    buffer = nil, img = nil, ptr = nil,
    w = 0, h = 0,
    minX = 0, minY = 0, maxX = 0, maxY = 0
}

VISION.dollyActive = false
VISION.subjectScale = 1

function VISION.ToggleDolly()
    VISION.dollyActive = not VISION.dollyActive
    -- Capture the scale of the object at Z=0 relative to current focal/offset
    -- This ensures the subject stays exactly this size.
    VISION.subjectScale = SETTINGS.FOCAL_LENGTH / SETTINGS.Z_OFFSET
    print("Dolly Zoom: " .. (VISION.dollyActive and "ACTIVE" or "OFF"))
end

function VISION.ApplyDolly(targetFocal, dt)
    if not VISION.dollyActive then return end

    local speed = 2.0 -- How fast the lens "zooms"
    -- Smoothly Lerp the Focal Length
    SETTINGS.FOCAL_LENGTH = SETTINGS.FOCAL_LENGTH + (targetFocal - SETTINGS.FOCAL_LENGTH) * (dt * speed)

    -- Counter-move the Z_OFFSET to maintain subject scale
    SETTINGS.Z_OFFSET = SETTINGS.FOCAL_LENGTH / VISION.subjectScale
end

function VISION.Init()
    local w, h = love.graphics.getDimensions()
    VISION.w, VISION.h = w, h
    VISION.buffer = love.image.newImageData(w, h)
    VISION.img = love.graphics.newImage(VISION.buffer)
    VISION.ptr = ffi.cast("uint32_t*", VISION.buffer:getPointer())

    -- ALLOCATE Z-BUFFER
    VISION.zBuffer = ffi.new("float[?]", w * h)

    VISION.minX, VISION.minY = 0, 0
    VISION.maxX, VISION.maxY = w - 1, h - 1
end

function VISION.Update(dt)
    for i = 0, NODE.objCount - 1 do
        local obj = NODE.OBJECTS[i]
        if obj.active then
            obj.rx = obj.rx + dt * (0.5 + (i * 0.1))
            obj.ry = obj.ry + dt * (0.3 + (i * 0.05))
        end
    end
end

function VISION.Draw3D(zoom, screenW, screenH)
    local w, h = VISION.w, VISION.h
    if not VISION.ptr then return end

    -- 1. Dirty Clear (Now including Z-Buffer)
    for y = VISION.minY, VISION.maxY do
        if y >= 0 and y < h then
            local rowOffset = y * w + VISION.minX
            local width = (VISION.maxX - VISION.minX + 1)
            ffi.fill(VISION.ptr + rowOffset, width * 4, 0)
            -- Clear Z-Buffer to a very far distance (e.g., 10000)
            for x = 0, width - 1 do
                VISION.zBuffer[rowOffset + x] = 10000
            end
        end
    end

    -- ... Projection math remains the same until the pixel write ...
    local curMinX, curMinY, curMaxX, curMaxY = w, h, 0, 0

    -- focalLength controls the "strength" of the 3D effect.
    -- Lower = Wide Angle (more depth), Higher = Telephoto (flatter).
    local focalLength = SETTINGS.FOCAL_LENGTH
    local zOffset = SETTINGS.Z_OFFSET -- Anchors the center of the object to scale 1:1

    for i = 0, NODE.objCount - 1 do
        local obj = NODE.OBJECTS[i]
        if obj.active then
            local isFixed = bit.band(obj.flags, NODE.FLAGS.FIXED) ~= 0
            local cosA, sinA = math.cos(obj.rx), math.sin(obj.rx)
            local cosB, sinB = math.cos(obj.ry), math.sin(obj.ry)

            for lz = 0, obj.d - 1 do
                local sliceOffset = obj.vOffset + (lz * obj.h * NODE.STRIDE)
                local localZ = lz - (obj.d / 2)

                for ly = 0, obj.h - 1 do
                    local rowOffset = sliceOffset + (ly * NODE.STRIDE)
                    local localY = ly - (obj.h / 2)

                    for lx = 0, obj.w - 1 do
                        local idx = rowOffset + lx + 1
                        if bit.band(NODE.BUFFER[idx], NODE.FLAGS.SOLID) ~= 0 then
                            local localX = lx - (obj.w / 2)
                            local rx, ry, rz

                            if isFixed then
                                -- No rotation, but still gets 3D perspective
                                rx, ry, rz = localX, localY, localZ
                            else
                                -- Full Rotation Pipeline
                                local tx = localX * cosA - localZ * sinA
                                local tz = localX * sinA + localZ * cosA
                                rx = tx
                                ry = localY * cosB - tz * sinB
                                rz = localY * sinB + tz * cosB
                            end

                            -- 2. Projection Math
                            -- We calculate the perspective factor in world units first.
                            local finalZ = rz + zOffset
                            if finalZ > SETTINGS.NEAR_PLANE and finalZ < SETTINGS.FAR_PLANE then
                                -- local perspective = focalLength / finalZ
                                local perspective = 1.0
                                -- 3. The "Zero-Drift" Anchor:
                                -- We project the local offset, add it to the world position,
                                -- and THEN apply the 2D zoom/Camera transform.
                                local ix = math.floor(((obj.x + rx * perspective) * zoom) - CAMERA.x)
                                local iy = math.floor(((obj.y + ry * perspective) * zoom) - CAMERA.y)

                                if ix >= 0 and ix < w and iy >= 0 and iy < h then
                                    local pixelIdx = iy * w + ix
                                    -- 4. THE DEPTH TEST
                                    -- Only draw if this pixel is CLOSER than what's already there
                                    if finalZ < VISION.zBuffer[pixelIdx] then
                                        VISION.zBuffer[pixelIdx] = finalZ
                                        VISION.ptr[pixelIdx] = obj.color

                                        -- Update Dirty Rect
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
            end
        end
    end

    VISION.minX, VISION.minY, VISION.maxX, VISION.maxY = curMinX, curMinY, curMaxX, curMaxY
    VISION.img:replacePixels(VISION.buffer)
    love.graphics.draw(VISION.img, 0, 0)
end

