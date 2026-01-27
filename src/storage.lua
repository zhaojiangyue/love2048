local Constants = require("src.constants")
local Logic = require("src.game_logic")

local Storage = {}
local FILENAME = "savegame_v1.json"
local HIGHSCORE_FILE = "highscore.txt"

-- Simple JSON serializer (hand-rolled to avoid dependencies for now)
-- Only supports simple tables, numbers, strings
local function serialize(tbl)
    local parts = {}
    table.insert(parts, "{")
    for k, v in pairs(tbl) do
        local keyStr = '"' .. tostring(k) .. '"'
        local valStr = ""
        if type(v) == "table" then
            valStr = serialize(v)
        elseif type(v) == "string" then
            valStr = '"' .. v .. '"'
        else
            valStr = tostring(v)
        end
        table.insert(parts, keyStr .. ":" .. valStr .. ",")
    end
    table.insert(parts, "}")
    return table.concat(parts)
end

-- We will use a simpler custom format for the grid to avoid JSON parsing issues without a library
-- Format: score|best|v1,v2,v3,v4... (16 values)
-- Wait, Logic uses Objects now. Serialization is harder.
-- Actually, we can just save the Values (0, 2, 4...) and reconstruct objects on load.

function Storage.saveGame(grid, score, highscore)
    local data = ""
    data = data .. tostring(score) .. "\n"
    data = data .. tostring(highscore) .. "\n"
    
    for y = 1, 4 do
        for x = 1, 4 do
            local val = grid[y][x] and grid[y][x].val or 0
            data = data .. val .. ","
        end
    end
    
    love.filesystem.write(FILENAME, data)
end

function Storage.loadGame()
    if not love.filesystem.getInfo(FILENAME) then return nil end
    
    local content, size = love.filesystem.read(FILENAME)
    if not content then return nil end
    
    local lines = {}
    for s in content:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end
    
    if #lines < 3 then return nil end
    
    local score = tonumber(lines[1])
    local highscore = tonumber(lines[2])
    local gridData = lines[3]
    
    local grid = Logic.initGrid()
    local x, y = 1, 1
    
    for valStr in gridData:gmatch("([^,]+)") do
        local val = tonumber(valStr)
        if val > 0 then
            grid[y][x] = {
                id = Logic.getUID(),
                val = val,
                x = x,
                y = y
            }
        end
        
        x = x + 1
        if x > 4 then
            x = 1
            y = y + 1
        end
    end
    
    return {
        grid = grid,
        score = score,
        highscore = highscore
    }
end

function Storage.clearSave()
    if love.filesystem.getInfo(FILENAME) then
        love.filesystem.remove(FILENAME)
    end
end

return Storage

