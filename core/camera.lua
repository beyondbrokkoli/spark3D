-- core/camera.lua
CAMERA = {
    x = 0,
    y = 0,
}

function CAMERA.GetViewport(viewW, viewH, cellSize)
    local startX = math.floor(CAMERA.x / cellSize) + 1
    local startY = math.floor(CAMERA.y / cellSize) + 1
    local offsetX = CAMERA.x % cellSize
    local offsetY = CAMERA.y % cellSize
    return startX, startY, offsetX, offsetY
end
