local Constants = require("src.constants")
local Utils = require("src.utils")

local Logic = {}
Logic.uidCounter = 0

function Logic.getUID()
    Logic.uidCounter = Logic.uidCounter + 1
    return Logic.uidCounter
end

-- Initialize a new empty grid
function Logic.initGrid()
    local grid = {}
    for y = 1, Constants.GRID_SIZE do
        grid[y] = {}
        for x = 1, Constants.GRID_SIZE do
            grid[y][x] = nil -- nil represents empty
        end
    end
    return grid
end

-- Spawn a tile
function Logic.spawnTile(grid)
    local emptyTiles = {}
    for y = 1, Constants.GRID_SIZE do
        for x = 1, Constants.GRID_SIZE do
            if grid[y][x] == nil then
                table.insert(emptyTiles, {x=x, y=y})
            end
        end
    end
    
    if #emptyTiles > 0 then
        local pos = emptyTiles[math.random(#emptyTiles)]
        local value = math.random() < 0.9 and 2 or 4
        
        local tile = {
            id = Logic.getUID(),
            val = value,
            x = pos.x, -- Logical X
            y = pos.y, -- Logical Y
            prevX = nil,
            prevY = nil
        }
        
        grid[pos.y][pos.x] = tile
        return tile -- Return the spawned tile for animation
    end
    return nil
end

-- Deep copy grid (structure only, tiles are references)
-- Use this carefully. If we modify tile internals in the copy, it affects original.
-- For simulation, we need deep copy of tiles too.
function Logic.deepCopyGrid(grid)
    local newGrid = {}
    for y = 1, Constants.GRID_SIZE do
        newGrid[y] = {}
        for x = 1, Constants.GRID_SIZE do
            if grid[y][x] then
                local t = grid[y][x]
                newGrid[y][x] = {id=t.id, val=t.val, x=t.x, y=t.y} 
            else
                newGrid[y][x] = nil
            end
        end
    end
    return newGrid
end

-- Returns: vector of moves, score added
function Logic.move(grid, direction)
    local vector = {x=0, y=0}
    if direction == "left" then vector = {x=-1, y=0}
    elseif direction == "right" then vector = {x=1, y=0}
    elseif direction == "up" then vector = {x=0, y=-1}
    elseif direction == "down" then vector = {x=0, y=1}
    end
    
    local traverseX = {1, 2, 3, 4}
    local traverseY = {1, 2, 3, 4}
    
    -- Always traverse from the direction execution to the opposite
    if direction == "right" then traverseX = {4, 3, 2, 1} end
    if direction == "down" then traverseY = {4, 3, 2, 1} end
    
    local score = 0
    local moved = false
    local moves = {} -- List of {tile, fromX, fromY, toX, toY, type='move'|'merge'}
    
    -- Clear merge flags
    for y=1,4 do for x=1,4 do if grid[y][x] then grid[y][x].merged = false end end end
    
    for _, x in ipairs(traverseX) do
        for _, y in ipairs(traverseY) do
            local tile = grid[y][x]
            if tile then
                local positions = {x = x, y = y}
                
                -- Farthest Position Logic
                local cell = {x=x, y=y}
                local next = {x=cell.x + vector.x, y=cell.y + vector.y}
                
                while next.x >= 1 and next.x <= 4 and next.y >= 1 and next.y <= 4 and not grid[next.y][next.x] do
                    cell = next
                    next = {x=cell.x + vector.x, y=cell.y + vector.y}
                end
                
                local farthest = cell
                local nextTile = nil
                if next.x >= 1 and next.x <= 4 and next.y >= 1 and next.y <= 4 then
                    nextTile = grid[next.y][next.x]
                end
                
                if nextTile and nextTile.val == tile.val and not nextTile.merged then
                    -- Merge
                    local mergedTile = {
                        id = Logic.getUID(),
                        val = tile.val * 2,
                        x = next.x,
                        y = next.y,
                        merged = true
                    }
                    
                    grid[y][x] = nil
                    grid[next.y][next.x] = mergedTile
                    
                    -- Record moves
                    tile.x = next.x
                    tile.y = next.y
                    nextTile.x = next.x
                    nextTile.y = next.y -- stay put but disappear
                    
                    score = score + mergedTile.val
                    moved = true
                    
                    table.insert(moves, {type="merge", tile=mergedTile, source=tile, target=nextTile})
                else
                    -- Move
                    if farthest.x ~= x or farthest.y ~= y then
                        grid[y][x] = nil
                        grid[farthest.y][farthest.x] = tile
                        tile.x = farthest.x
                        tile.y = farthest.y
                        moved = true
                        table.insert(moves, {type="move", tile=tile, fromX=x, fromY=y, toX=farthest.x, toY=farthest.y})
                    end
                end
            end
        end
    end
    
    return moved, score, moves
end

function Logic.canMove(grid)
    for y=1,4 do
        for x=1,4 do
             if grid[y][x] == nil then return true end
             local t = grid[y][x]
             -- check right
             if x < 4 and grid[y][x+1] and grid[y][x+1].val == t.val then return true end
             -- check down
             if y < 4 and grid[y+1][x] and grid[y+1][x].val == t.val then return true end
        end
    end
    return false
end

return Logic
