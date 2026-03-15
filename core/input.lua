-- core/input.lua
INPUT = {}
function INPUT.ToIdx(pixelX, pixelY, zoom)
    local size = NODE.STRIDE
    local gridX = math.floor(pixelX / zoom) + 1
    local gridY = math.floor(pixelY / zoom) + 1
    if gridX < 1 or gridX > size or gridY < 1 or gridY > size then
        return nil
    end


    local idx = (gridY - 1) * size + gridX
    if not idx or idx < 1 or idx > (size * size) then
        return nil
    end
    return idx
end

function INPUT.GetMouseGrid(zoom)
    local mx, my = love.mouse.getPosition()
    local worldX = mx + CAMERA.x
    local worldY = my + CAMERA.y
    return INPUT.ToIdx(worldX, worldY, zoom)
end
