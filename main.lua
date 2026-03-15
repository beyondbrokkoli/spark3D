-- main.lua
require("core.settings")
require("core.node")
require("core.vision")
require("core.camera")
require("core.input")

local resizeTimer = 0
local pendingResize = false

function love.resize(w, h)
    pendingResize = true
    resizeTimer = 0.2 -- Wait 200ms of "silence" before re-init
end

function love.load()
    NODE.Init(SETTINGS.VOXEL_POOL_SIZE)
    VISION.Init()

    local dim = 12
    local bigDim = 60
    local r = (dim / 2) - 0.5

    -- Precise Memory Management
    local currentOffset = 0

    -- 1. CUBE
    local cubeBase = currentOffset
    for z = 0, dim - 1 do
        for y = 0, dim - 1 do
            for x = 0, dim - 1 do
                NODE.BUFFER[cubeBase + NODE.GetIndex(x, y, z, dim, dim)] = NODE.FLAGS.SOLID
            end
        end
    end
    currentOffset = currentOffset + (dim * dim * NODE.STRIDE)

    -- 2. PYRAMID
    local pyrBase = currentOffset
    for z = 0, dim - 1 do
        local inset = math.floor(z / 2)
        for y = inset, (dim - 1) - inset do
            for x = inset, (dim - 1) - inset do
                NODE.BUFFER[pyrBase + NODE.GetIndex(x, y, z, dim, dim)] = NODE.FLAGS.SOLID
            end
        end
    end
    currentOffset = currentOffset + (dim * dim * NODE.STRIDE)

    -- 3. SPHERE
    local sphereBase = currentOffset
    for z = 0, dim - 1 do
        for y = 0, dim - 1 do
            for x = 0, dim - 1 do
                local dx, dy, dz = x - r, y - r, z - r
                if (dx*dx + dy*dy + dz*dz) <= (r*r) then
                    NODE.BUFFER[sphereBase + NODE.GetIndex(x, y, z, dim, dim)] = NODE.FLAGS.SOLID
                end
            end
        end
    end
    currentOffset = currentOffset + (dim * dim * NODE.STRIDE)

    -- 4. OCTAHEDRON
    local octBase = currentOffset
    for z = 0, dim - 1 do
        for y = 0, dim - 1 do
            for x = 0, dim - 1 do
                local dx, dy, dz = math.abs(x-r), math.abs(y-r), math.abs(z-r)
                if (dx + dy + dz) <= r then
                    NODE.BUFFER[octBase + NODE.GetIndex(x, y, z, dim, dim)] = NODE.FLAGS.SOLID
                end
            end
        end
    end
    currentOffset = currentOffset + (dim * dim * NODE.STRIDE)

    -- 5. THE MONOLITH
    local monoBase = currentOffset
    for z = 0, bigDim - 1 do
        for y = 0, bigDim - 1 do
            for x = 0, bigDim - 1 do
                NODE.BUFFER[monoBase + NODE.GetIndex(x, y, z, bigDim, bigDim)] = NODE.FLAGS.SOLID
            end
        end
    end

    -- SPAWN OBJECTS
    -- Massive reference points (one at center, one offset)
    --NODE.CreateObject(800, 800, 0, bigDim, bigDim, bigDim, 0xFF444444, monoBase, NODE.FLAGS.FIXED)
    --NODE.CreateObject(1600, 400, 0, bigDim, bigDim, bigDim, 0xFF333333, monoBase, NODE.FLAGS.FIXED)
    -- gemini created square sized pentagram black holes in my cpu :D
    NODE.CreateObject(800, 800, 0, bigDim, bigDim, bigDim, 0xFF444444, monoBase)
    NODE.CreateObject(1600, 400, 0, bigDim, bigDim, bigDim, 0xFF333333, monoBase)

    local bases = {cubeBase, pyrBase, sphereBase, octBase}
    for i = 1, 40 do
        local x, y = math.random(200, 2000), math.random(200, 2000)
        local base = bases[math.random(#bases)]
        NODE.CreateObject(x, y, 0, dim, dim, dim, 0xFF00AAFF + (i * 5000), base)
    end
end

function love.draw()
    -- Only draw if the hardware and FFI pointers are synchronized
    if not pendingResize then
        local w, h = love.graphics.getDimensions()
        -- instead of a separate MatrixFloor function we will integrate
        -- a regular 3D object (big flat floor object)
        -- into 3D space without rotation
        -- after gemini has helped me set this up
        VISION.Draw3D(SETTINGS.ZOOM, w, h)
    else
        -- Provide feedback during the brief re-allocation pause
        love.graphics.clear(0.05, 0.05, 0.05)
        love.graphics.setColor(0, 1, 0.4)
        love.graphics.print("SYNCHRONIZING MEMORY...", 20, 20)
        love.graphics.setColor(1, 1, 1)
    end

    -- love.graphics.print("WASD: Move | Objects: " .. NODE.objCount, 10, 10)
end

function love.update(dt)
    if pendingResize then
        resizeTimer = resizeTimer - dt
        if resizeTimer <= 0 then
            VISION.Init() -- Re-syncs the FFI pointers to new dimensions
            pendingResize = false -- Opens the gate for love.draw
            print("Surgical Re-init complete. Rendering resumed.")
        end
    end

    -- Calculate speed with a floor (Min Speed)
    local rawSpeed = SETTINGS.CAMERA_SPEED * (1 / SETTINGS.ZOOM)
    local adjustedSpeed = math.max(SETTINGS.MIN_CAMERA_SPEED, rawSpeed) * dt

    if love.keyboard.isDown("w") then CAMERA.y = CAMERA.y - adjustedSpeed end
    if love.keyboard.isDown("s") then CAMERA.y = CAMERA.y + adjustedSpeed end
    if love.keyboard.isDown("a") then CAMERA.x = CAMERA.x - adjustedSpeed end
    if love.keyboard.isDown("d") then CAMERA.x = CAMERA.x + adjustedSpeed end

    -- Apply the Dolly Zoom effect if active
    -- We target Focal Length 2 (Wide) or 50 (Telephoto) based on a timer or toggle
    local target = (math.sin(love.timer.getTime()) > 0) and 2 or 60
    VISION.ApplyDolly(target, dt)

    CAMERA.Clamp(NODE.STRIDE, SETTINGS.ZOOM)
    VISION.Update(dt)
end

function love.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()

    -- "Screen-to-World" Mouse Position
    local worldMouseX = mx + CAMERA.x
    local worldMouseY = my + CAMERA.y

    local oldZoom = SETTINGS.ZOOM
    local zoomSpeed = 1.15

    -- Zoom In/Out
    if y > 0 then
        SETTINGS.ZOOM = math.min(50, SETTINGS.ZOOM * zoomSpeed)
    elseif y < 0 then
        SETTINGS.ZOOM = math.max(0.5, SETTINGS.ZOOM / zoomSpeed)
    end

    local ratio = SETTINGS.ZOOM / oldZoom

    -- The "Perfect Zoom" Math:
    -- Adjusts camera so the world point under the mouse stays under the mouse.
    CAMERA.x = (CAMERA.x + mx) * ratio - mx
    CAMERA.y = (CAMERA.y + my) * ratio - my
end

function love.quit()
    print("Ogre Engine: Initiating safe shutdown...")
    -- Clear the FFI pointers so the GC doesn't trip over them later
    VISION.ptr = nil
    VISION.buffer = nil
    NODE.BUFFER = nil
    NODE.OBJECTS = nil
    return false -- Allow the app to close
end

function love.keypressed(key)
    if key == "f" then
        local isFullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not isFullscreen)
    -- elseif key == "v" then
        -- VISION.ToggleDolly()
    elseif key == "escape" then
        love.event.quit()
    end
end
