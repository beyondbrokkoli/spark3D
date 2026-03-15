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

    local dim = 12 -- Template size (12x12x12)


    -- 1. CUBE TEMPLATE (at offset 0)
    for z = 0, dim - 1 do
        for y = 0, dim - 1 do
            for x = 0, dim - 1 do
                NODE.BUFFER[NODE.GetIndex(x, y, z, dim, dim)] = NODE.FLAGS.SOLID
            end
        end
    end

    -- 2. PYRAMID TEMPLATE
    local pyramidBase = (dim * dim * NODE.STRIDE) + 100
    for z = 0, dim - 1 do
        local inset = math.floor(z / 2)
        for y = inset, (dim - 1) - inset do
            for x = inset, (dim - 1) - inset do
                local idx = pyramidBase + NODE.GetIndex(x, y, z, dim, dim)
                NODE.BUFFER[idx] = NODE.FLAGS.SOLID
            end
        end
    end

    -- 3. SPAWN THE MATRIX
    -- The "Great Green Pyramid" at center
    NODE.CreateObject(400, 400, 0, dim, dim, dim, 0xFF00FF44, pyramidBase)

    -- Scattered Neon Cubes
    for i = 1, 15 do
        local x = math.random(100, 1500)
        local y = math.random(100, 1500)
        -- Variations: some cubes, some smaller pyramids
        local isPyramid = math.random() > 0.7
        local color = isPyramid and 0xFF00FFFF or (i % 2 == 0 and 0xFFCCAA33 or 0xFFFF00FF)
        local offset = isPyramid and pyramidBase or 0

        NODE.CreateObject(x, y, 0, dim, dim, dim, color, offset)
    end
    -- In main.lua, inside love.load()
    local floorColor = 0xFF222222
    NODE.CreateObject(400, 600, 0, 60, 1, 60, floorColor, 0, NODE.FLAGS.FIXED)
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

    love.graphics.print("WASD: Move | Objects: " .. NODE.objCount, 10, 10)
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

    -- Movement and camera logic (Safe to run during resize)
    local adjustedSpeed = SETTINGS.CAMERA_SPEED * (SETTINGS.ZOOM / 1) * dt
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
    if key == "v" then
        VISION.ToggleDolly()
    end
end
