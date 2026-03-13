-- core/portal.lua
PORTAL = {}

-- This is where the heavy JSON objects live, indexed by grid position
DATA_REGISTRY = {}

function PORTAL.Inject(idx, data)
    if not idx then return end
    NODE.Update(idx, NODE.FLAGS.DATA, "SET") -- Now marks DIRTY automatically
    DATA_REGISTRY[idx] = data
end

function PORTAL.Get(idx)
    return DATA_REGISTRY[idx]
end

-- Your industrial-grade walker adapted for the portal
function PORTAL.WalkAndInject(node, startIdx)
    if type(node) ~= "table" then return end

    local offset = 0
    for k, v in pairs(node) do
        local targetIdx = startIdx + offset

        -- Guard against walking off the world
        if targetIdx <= (NODE.SIZE * NODE.SIZE) then
            PORTAL.Inject(targetIdx, {key = k, value = v})
        end

        -- If it's a nested table, we could recurse or just move to next cell
        if type(v) == "table" then
            -- Optional: recursion logic here if you want "Data Branches"
        end

        offset = offset + 1
    end
end
