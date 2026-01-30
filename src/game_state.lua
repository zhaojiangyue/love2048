local Logic = require("src.game_logic")

local GameState = {}

-- Core game state
GameState.grid = nil
GameState.score = 0
GameState.bestScore = 0
GameState.state = "playing" -- "playing", "gameover", "paused", "won"
GameState.moveCount = 0

-- Settings
GameState.settings = {
    shakeLevel = 2, -- Default: Tiny Shake (1:Off, 2:Tiny, 3:Normal, 4:Chaos)
    shakeMultiplier = 0.25,
    particles = true
}

-- New mechanics state
GameState.dlssCharges = 3
GameState.heatLevel = 0
GameState.gameOverReason = nil -- nil, "overtrained", "no_moves"
GameState.hasWon = false -- Track if player has reached 2048

-- Tile metadata tracking (indexed by tile ID)
GameState.tileMeta = {}
-- Each entry: { training = 0, overtrained = false, overtrainedMoves = 0, isLQ = false, heat = 0 }

-- UI state
GameState.hasLQTile = false
GameState.selectedTileForDLSS = nil -- Track which tile is selected for DLSS

function GameState.init()
    GameState.grid = Logic.initGrid()
    GameState.score = 0
    GameState.moveCount = 0
    GameState.dlssCharges = 3
    GameState.heatLevel = 0
    GameState.state = "playing"
    GameState.tileMeta = {}
    GameState.hasLQTile = false
    GameState.hasLQTile = false
    GameState.gameOverReason = nil
    GameState.hasWon = false
end

function GameState.reset()
    GameState.init()
end

-- Get metadata for a tile
function GameState.getTileMeta(tileId)
    if not GameState.tileMeta[tileId] then
        GameState.tileMeta[tileId] = {
            training = 0,
            overtrained = false,
            overtrainedMoves = 0,
            isLQ = false,
            heat = 0
        }
    end
    return GameState.tileMeta[tileId]
end

-- Set metadata for a tile
function GameState.setTileMeta(tileId, meta)
    GameState.tileMeta[tileId] = meta
end

-- Remove metadata for a tile (when merged/removed)
function GameState.removeTileMeta(tileId)
    GameState.tileMeta[tileId] = nil
end

-- Update training levels for all tiles on the board
function GameState.updateTraining()
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                local meta = GameState.getTileMeta(tile.id)

                -- Increment training level
                meta.training = meta.training + 1

                -- Check for overtrained state (30+ moves)
                if meta.training >= 30 and not meta.overtrained then
                    meta.overtrained = true
                    meta.overtrainedMoves = 0
                    print(string.format("⚠ Tile at (%d,%d) is now OVERTRAINED! Merge within 12 moves!", x, y))
                end

                -- Increment overtrained countdown
                if meta.overtrained then
                    meta.overtrainedMoves = meta.overtrainedMoves + 1

                    -- Game over if overtrained tile not merged within 12 moves
                    if meta.overtrainedMoves > 12 then
                        GameState.state = "gameover"
                        GameState.gameOverReason = "overtrained"
                        return false
                    end
                end
            end
        end
    end
    return true
end

-- Calculate current heat level based on high-tier tiles
function GameState.calculateHeat()
    local totalHeat = 0
    local heatValues = {
        [32] = 5,    -- RTX 2080 Ti
        [64] = 12,   -- RTX 3090
        [128] = 22,  -- RTX 4090
        [256] = 35,  -- A100
        [512] = 50,  -- H100
        [1024] = 70, -- GB200
        [2048] = 100 -- Jensen's Kitchen
    }

    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                local heatContribution = heatValues[tile.val] or 0
                totalHeat = totalHeat + heatContribution
            end
        end
    end

    GameState.heatLevel = math.min(100, totalHeat)
    return GameState.heatLevel
end

-- Cool down heat (called after each move)
function GameState.coolDown()
    GameState.heatLevel = math.max(0, GameState.heatLevel - 1)
end

-- Check if there are any LQ tiles on the board
function GameState.checkForLQTiles()
    GameState.hasLQTile = false
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                local meta = GameState.getTileMeta(tile.id)
                if meta.isLQ then
                    GameState.hasLQTile = true
                    return true
                end
            end
        end
    end
    return false
end

-- Add DLSS charge (called when scoring milestones reached)
function GameState.addDLSSCharge()
    if GameState.dlssCharges < 3 then
        GameState.dlssCharges = GameState.dlssCharges + 1
    end
end

-- Use DLSS charge
function GameState.useDLSSCharge()
    if GameState.dlssCharges > 0 then
        GameState.dlssCharges = GameState.dlssCharges - 1
        return true
    end
    return false
end

-- Check thermal throttling effects
function GameState.getThermalState()
    if GameState.heatLevel >= 90 then
        return "throttling"
    elseif GameState.heatLevel >= 75 then
        return "hot"
    elseif GameState.heatLevel >= 50 then
        return "warm"
    else
        return "normal"
    end
end

-- Export state for saving
function GameState.export()
    return {
        grid = GameState.grid,
        score = GameState.score,
        bestScore = GameState.bestScore,
        moveCount = GameState.moveCount,
        dlssCharges = GameState.dlssCharges,
        heatLevel = GameState.heatLevel,
        tileMeta = GameState.tileMeta,
        heatLevel = GameState.heatLevel,
        tileMeta = GameState.tileMeta,
        state = GameState.state,
        hasWon = GameState.hasWon,
        settings = GameState.settings
    }
end

-- Import state from save
function GameState.import(data)
    GameState.grid = data.grid or Logic.initGrid()
    GameState.score = data.score or 0
    GameState.bestScore = data.bestScore or 0
    GameState.moveCount = data.moveCount or 0
    GameState.dlssCharges = data.dlssCharges or 3
    GameState.heatLevel = data.heatLevel or 0
    GameState.tileMeta = data.tileMeta or {}
    GameState.state = data.state or "playing"
    GameState.gameOverReason = nil
    GameState.hasWon = data.hasWon or false
    
    -- Load settings if present, otherwise default
    if data.settings then
        GameState.settings = data.settings
    else
        -- Default to Tiny Shake
        GameState.settings = {
            shakeLevel = 2,
            shakeMultiplier = 0.25,
            particles = true
        }
    end

    -- Recalculate derived state
    GameState.checkForLQTiles()
    GameState.calculateHeat()

    -- Recalculate derived state
    GameState.checkForLQTiles()
    GameState.calculateHeat()

    -- REGENERATE ALL TILE IDs
    -- The previous bug caused ID collisions in saved games.
    -- We must issue new unique IDs to all tiles to fix this.
    Logic.uidCounter = 0
    local newTileMeta = {}
    
    for y = 1, 4 do
        for x = 1, 4 do
            if GameState.grid[y][x] then
                local tile = GameState.grid[y][x]
                local oldId = tile.id
                
                -- Generate new unique ID
                tile.id = Logic.getUID()
                
                -- Migrate metadata to new ID if it exists
                if GameState.tileMeta[oldId] then
                    newTileMeta[tile.id] = GameState.tileMeta[oldId]
                end
            end
        end
    end
    
    -- Replace old metadata table with new one
    GameState.tileMeta = newTileMeta
end

-- Clean up metadata for tiles that no longer exist
function GameState.cleanupOrphanedMeta()
    local existingTileIds = {}

    -- Collect all tile IDs currently on the board
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                existingTileIds[tile.id] = true
            end
        end
    end

    -- Remove metadata for tiles that don't exist
    for tileId, _ in pairs(GameState.tileMeta) do
        if not existingTileIds[tileId] then
            GameState.tileMeta[tileId] = nil
        end
    end
end

-- Get all tiles as a flat list (useful for mechanics processing)
function GameState.getAllTiles()
    local tiles = {}
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                table.insert(tiles, {
                    tile = tile,
                    x = x,
                    y = y,
                    meta = GameState.getTileMeta(tile.id)
                })
            end
        end
    end
    return tiles
end

-- Find a specific tile by position
function GameState.getTileAt(x, y)
    if x >= 1 and x <= 4 and y >= 1 and y <= 4 then
        return GameState.grid[y][x]
    end
    return nil
end

-- Find first LQ tile on the board
function GameState.findFirstLQTile()
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                local meta = GameState.getTileMeta(tile.id)
                if meta.isLQ then
                    return tile, x, y, meta
                end
            end
        end
    end
    return nil
end

-- Get game state as a table for renderer (avoids exposing full state)
function GameState.getDisplayState()
    return {
        score = GameState.score,
        bestScore = GameState.bestScore,
        state = GameState.state,
        dlssCharges = GameState.dlssCharges,
        heatLevel = GameState.heatLevel,
        hasLQTile = GameState.hasLQTile,
        gameOverReason = GameState.gameOverReason,
        moveCount = GameState.moveCount,
        thermalState = GameState.getThermalState()
    }
end

return GameState
