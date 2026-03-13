-- main.lua
require("core.settings")
require("core.node")
require("core.region")
require("core.vision_alt")
require("core.input")
require("core.camera")
require("core.portal")
require("core.bench")

function love.load()
    NODE.Init(SETTINGS.GRID_BUFFER_SIZE)
    local midCoord = math.floor(SETTINGS.GRID_BUFFER_SIZE / 2)
    REGION.Apply(midCoord, midCoord, midCoord + 5, midCoord + 5, NODE.FLAGS.SOLID, "SET")
    --BENCH.Run("Full Grid Fill", function()
    --    REGION.Apply(1, 1, SETTINGS.GRID_BUFFER_SIZE, SETTINGS.GRID_BUFFER_SIZE, NODE.FLAGS.LIT, "SET")
    --end)
    local midIdx = (midCoord - 1) * SETTINGS.GRID_BUFFER_SIZE + midCoord
    local myData = { status = "Giga-Ogre Online", kernel = "LÖVE 11.5", arch = "FFI" }
    PORTAL.WalkAndInject(myData, midIdx)
    -- hi gemini i didnt change the old love.load stuff i thought i can just overwrite in case i target the same grids
    -- Create a "Wireframe" cube by drawing squares in different slices
    for z = 0, 63 do
        local startRow = z * 64 + 1
        -- Only draw the front and back face fully, and just corners for the middle
        if z == 0 or z == 63 then
            REGION.Apply(1, startRow, 64, startRow + 64, NODE.FLAGS.SOLID, "SET")
        else
            -- Draw just the "hollow" square outline for the middle slices
            REGION.Apply(1, startRow, 64, startRow, NODE.FLAGS.SOLID, "SET") -- Top
            REGION.Apply(1, startRow + 64, 64, startRow + 64, NODE.FLAGS.SOLID, "SET") -- Bottom
        end
    end
end

function love.mousepressed(x, y, button)
    local idx = INPUT.GetMouseGrid(SETTINGS.CELL_SIZE)
    if idx then
        local op = love.keyboard.isDown(SETTINGS.KEYS.ERASE) and "CLEAR" or "SET"
        NODE.Update(idx, NODE.FLAGS.SOLID, op)
    end
end

function love.draw()
    local cellSize = SETTINGS.CELL_SIZE
    local w, h = love.graphics.getDimensions()
    local viewW, viewH = math.ceil(w / cellSize), math.ceil(h / cellSize)

    -- 1. Draw the 2D "Background" World (Static/Efficient)
    BENCH.Run("2D Pass", function()
        VISION.Draw2D(viewW, viewH, cellSize)
    end)

    -- 2. Draw the 3D "Ogre" Projection (Dynamic Overlay)
    BENCH.Run("3D Pass", function()
        VISION.Draw3D(cellSize)
    end)
end

function love.keypressed(key)
    if key == "c" then
        BENCH.Run("Chaos Fill", function()
            local cellSize = SETTINGS.CELL_SIZE
            local gx = math.floor(CAMERA.x / cellSize) + 1
            local gy = math.floor(CAMERA.y / cellSize) + 1
            REGION.RandomFill(gx, gy, gx + 500, gy + 500, 0.5)
        end)
    end
    if key == "t" then
        local midCoord = math.floor(SETTINGS.GRID_BUFFER_SIZE / 2)
        CAMERA.x = (midCoord - 1) * SETTINGS.CELL_SIZE
        CAMERA.y = (midCoord - 1) * SETTINGS.CELL_SIZE
    end
    if key == SETTINGS.KEYS.FULLSCREEN then
        local isFull = love.window.getFullscreen()
        love.window.setFullscreen(not isFull, "desktop")
    end
    if key == "escape" then love.event.quit() end
end

function love.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    local worldX = mx + CAMERA.x
    local worldY = my + CAMERA.y

    local oldZoom = SETTINGS.CELL_SIZE
    local zoomSpeed = 1.2

    -- GUARDRAIL: Set a floor (1.0 for VM health) and a ceiling (e.g., 100)
    if y > 0 then
        SETTINGS.CELL_SIZE = math.min(100, SETTINGS.CELL_SIZE * zoomSpeed)
    elseif y < 0 then
        SETTINGS.CELL_SIZE = math.max(1.0, SETTINGS.CELL_SIZE / zoomSpeed)
    end

    local newZoom = SETTINGS.CELL_SIZE
    local ratio = newZoom / oldZoom

    CAMERA.x = (CAMERA.x + mx) * ratio - mx
    CAMERA.y = (CAMERA.y + my) * ratio - my
end

function love.update(dt)
    local cfg = SETTINGS
    local screenW, screenH = love.graphics.getDimensions()
    local maxPixel = NODE.SIZE * cfg.CELL_SIZE

    -- Movement speed should scale with zoom!
    -- When zoomed out, move faster; when zoomed in, move precisely.
    local adjustedSpeed = cfg.CAMERA_SPEED / math.max(1, (1 / cfg.CELL_SIZE))

    if love.keyboard.isDown(cfg.KEYS.RIGHT) then CAMERA.x = CAMERA.x + adjustedSpeed * dt end
    if love.keyboard.isDown(cfg.KEYS.LEFT)  then CAMERA.x = CAMERA.x - adjustedSpeed * dt end
    if love.keyboard.isDown(cfg.KEYS.DOWN)  then CAMERA.y = CAMERA.y + adjustedSpeed * dt end
    if love.keyboard.isDown(cfg.KEYS.UP)    then CAMERA.y = CAMERA.y - adjustedSpeed * dt end

    -- IMPROVED CLAMPING:
    -- If world > screen: Keep camera within [0, world-screen]
    -- If world < screen: Force camera to center the world
    if maxPixel > screenW then
        CAMERA.x = math.max(0, math.min(CAMERA.x, maxPixel - screenW))
    else
        CAMERA.x = (maxPixel - screenW) / 2
    end

    if maxPixel > screenH then
        CAMERA.y = math.max(0, math.min(CAMERA.y, maxPixel - screenH))
    else
        CAMERA.y = (maxPixel - screenH) / 2
    end

    VISION.Update(dt)

    -- ... rest of mouse logic ...
    local idx = INPUT.GetMouseGrid(cfg.CELL_SIZE)
    if idx then
        if love.mouse.isDown(1) then
            local op = love.keyboard.isDown(cfg.KEYS.ERASE) and "CLEAR" or "SET"
            -- CALL NODE.Update to trigger the Dirty Flag!
            NODE.Update(idx, NODE.FLAGS.SOLID, op)
        end
    end
end
