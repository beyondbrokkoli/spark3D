-- core/camera.lua
CAMERA = {
    x = 0,
    y = 0,
}

function CAMERA.Clamp(worldSize, zoom)
    local screenW, screenH = love.graphics.getDimensions()
    local maxPixel = worldSize * zoom

    -- Allow the camera to move freely.
    -- Only clamp if you want to prevent seeing "outside" the 4096 grid.
    CAMERA.x = math.max(-screenW, math.min(CAMERA.x, maxPixel))
    CAMERA.y = math.max(-screenH, math.min(CAMERA.y, maxPixel))
end
