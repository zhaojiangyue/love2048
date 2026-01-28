local Constants = require("src.constants")
local Logic = require("src.game_logic")

local Storage = {}

-- File names
local FILENAME_V2 = "savegame_v2.txt"
local FILENAME_V1 = "savegame_v1.json"  -- Legacy format

-- ============================================================================
-- SAVE FORMAT VERSION 2
-- ============================================================================
-- Line 1: version=2
-- Line 2: score,bestscore,moveCount
-- Line 3: dlssCharges,heatLevel
-- Line 4: grid (16 tile values, comma-separated, 0 for empty)
-- Line 5: tileMeta (JSON-like format for metadata)

-- ============================================================================
-- SERIALIZATION HELPERS
-- ============================================================================

-- Serialize tile metadata to string
local function serializeTileMeta(tileMeta)
    local parts = {}
    for tileId, meta in pairs(tileMeta) do
        local metaStr = string.format("%d:{t=%d,o=%s,lq=%s}",
            tileId,
            meta.training or 0,
            meta.overtrained and "1" or "0",
            meta.isLQ and "1" or "0"
        )
        table.insert(parts, metaStr)
    end
    return table.concat(parts, "|")
end

-- Deserialize tile metadata from string
local function deserializeTileMeta(metaStr)
    if not metaStr or metaStr == "" then
        return {}
    end

    local tileMeta = {}
    for entry in metaStr:gmatch("[^|]+") do
        local tileId, training, overtrained, isLQ = entry:match("(%d+):{t=(%d+),o=([01]),lq=([01])}")
        if tileId then
            tileMeta[tonumber(tileId)] = {
                training = tonumber(training) or 0,
                overtrained = overtrained == "1",
                overtrainedMoves = 0,
                isLQ = isLQ == "1",
                heat = 0
            }
        end
    end
    return tileMeta
end

-- ============================================================================
-- SAVE GAME (VERSION 2)
-- ============================================================================

function Storage.saveGame(gameStateExport)
    -- gameStateExport should be from GameState.export()
    local data = {}

    -- Line 1: Version marker
    table.insert(data, "version=2")

    -- Line 2: Core game state
    table.insert(data, string.format("%d,%d,%d",
        gameStateExport.score or 0,
        gameStateExport.bestScore or 0,
        gameStateExport.moveCount or 0
    ))

    -- Line 3: Mechanics state
    table.insert(data, string.format("%d,%.2f",
        gameStateExport.dlssCharges or 3,
        gameStateExport.heatLevel or 0
    ))

    -- Line 4: Grid data (16 tile values)
    local gridValues = {}
    local grid = gameStateExport.grid
    for y = 1, 4 do
        for x = 1, 4 do
            local val = grid[y] and grid[y][x] and grid[y][x].val or 0
            table.insert(gridValues, tostring(val))
        end
    end
    table.insert(data, table.concat(gridValues, ","))

    -- Line 5: Tile metadata
    table.insert(data, serializeTileMeta(gameStateExport.tileMeta or {}))

    -- Write to file
    local content = table.concat(data, "\n")
    local success = love.filesystem.write(FILENAME_V2, content)

    if success then
        print("Game saved successfully (v2 format)")
    else
        print("ERROR: Failed to save game")
    end

    return success
end

-- ============================================================================
-- LOAD GAME (WITH AUTO-UPGRADE FROM V1)
-- ============================================================================

function Storage.loadGame()
    -- Try loading v2 format first
    local v2Data = Storage.loadGameV2()
    if v2Data then
        print("Loaded game from v2 save format")
        return v2Data
    end

    -- Fall back to v1 format and auto-upgrade
    local v1Data = Storage.loadGameV1()
    if v1Data then
        print("Loaded game from v1 save format (auto-upgrading to v2)")

        -- Convert v1 to v2 format
        local upgraded = {
            grid = v1Data.grid,
            score = v1Data.score,
            bestScore = v1Data.highscore or v1Data.score,
            moveCount = 0,  -- Unknown in v1
            dlssCharges = 3,  -- Default
            heatLevel = 0,  -- Will be recalculated
            tileMeta = {},  -- Empty, will be initialized
            state = "playing"
        }

        -- Save in v2 format for next time
        Storage.saveGame(upgraded)

        return upgraded
    end

    -- No save file found
    return nil
end

-- ============================================================================
-- LOAD GAME V2
-- ============================================================================

function Storage.loadGameV2()
    if not love.filesystem.getInfo(FILENAME_V2) then
        return nil
    end

    local content = love.filesystem.read(FILENAME_V2)
    if not content then
        return nil
    end

    local lines = {}
    for s in content:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end

    -- Verify version
    if #lines < 5 or not lines[1]:match("version=2") then
        print("Invalid v2 save format")
        return nil
    end

    -- Parse Line 2: Core game state
    local score, bestScore, moveCount = lines[2]:match("(%d+),(%d+),(%d+)")
    if not score then
        print("Failed to parse core game state")
        return nil
    end

    -- Parse Line 3: Mechanics state
    local dlssCharges, heatLevel = lines[3]:match("(%d+),([%d%.]+)")
    if not dlssCharges then
        print("Failed to parse mechanics state")
        return nil
    end

    -- Parse Line 4: Grid data
    local grid = Logic.initGrid()
    local gridValues = {}
    for val in lines[4]:gmatch("[^,]+") do
        table.insert(gridValues, tonumber(val) or 0)
    end

    if #gridValues ~= 16 then
        print("Invalid grid data")
        return nil
    end

    local idx = 1
    for y = 1, 4 do
        for x = 1, 4 do
            local val = gridValues[idx]
            if val > 0 then
                grid[y][x] = {
                    id = Logic.getUID(),
                    val = val,
                    x = x,
                    y = y
                }
            end
            idx = idx + 1
        end
    end

    -- Parse Line 5: Tile metadata
    local tileMeta = deserializeTileMeta(lines[5])

    return {
        grid = grid,
        score = tonumber(score),
        bestScore = tonumber(bestScore),
        moveCount = tonumber(moveCount),
        dlssCharges = tonumber(dlssCharges),
        heatLevel = tonumber(heatLevel),
        tileMeta = tileMeta,
        state = "playing"
    }
end

-- ============================================================================
-- LOAD GAME V1 (LEGACY SUPPORT)
-- ============================================================================

function Storage.loadGameV1()
    if not love.filesystem.getInfo(FILENAME_V1) then
        return nil
    end

    local content = love.filesystem.read(FILENAME_V1)
    if not content then
        return nil
    end

    local lines = {}
    for s in content:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end

    if #lines < 3 then
        return nil
    end

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

-- ============================================================================
-- CLEAR SAVE
-- ============================================================================

function Storage.clearSave()
    -- Clear both v1 and v2 save files
    if love.filesystem.getInfo(FILENAME_V2) then
        love.filesystem.remove(FILENAME_V2)
        print("Cleared v2 save file")
    end
    if love.filesystem.getInfo(FILENAME_V1) then
        love.filesystem.remove(FILENAME_V1)
        print("Cleared v1 save file")
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get save file info
function Storage.getSaveInfo()
    local v2Info = love.filesystem.getInfo(FILENAME_V2)
    local v1Info = love.filesystem.getInfo(FILENAME_V1)

    return {
        hasV2Save = v2Info ~= nil,
        hasV1Save = v1Info ~= nil,
        v2ModTime = v2Info and v2Info.modtime or 0,
        v1ModTime = v1Info and v1Info.modtime or 0
    }
end

-- Export current save data for debugging
function Storage.exportSaveAsText()
    if not love.filesystem.getInfo(FILENAME_V2) then
        return "No save file found"
    end

    local content = love.filesystem.read(FILENAME_V2)
    return content or "Failed to read save file"
end

return Storage
