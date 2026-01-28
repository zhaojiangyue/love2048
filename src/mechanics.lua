local GameState = require("src.game_state")
local Renderer = require("src.ui.renderer")
local Constants = require("src.constants")

local Mechanics = {}

-- ============================================================================
-- HEAT MANAGEMENT SYSTEM
-- ============================================================================

-- Heat contribution values for high-tier tiles - INCREASED for more pressure
Mechanics.HEAT_VALUES = {
    [32] = 5,    -- RTX 2080 Ti
    [64] = 12,   -- RTX 3090
    [128] = 22,  -- RTX 4090
    [256] = 35,  -- A100
    [512] = 50,  -- H100
    [1024] = 70, -- GB200
    [2048] = 100 -- Jensen's Kitchen (instant max heat!)
}

-- Thermal state thresholds
Mechanics.THERMAL_THRESHOLDS = {
    NORMAL = 0,
    WARM = 50,
    HOT = 75,
    THROTTLING = 90
}

-- Calculate heat based on high-tier tiles on board
function Mechanics.calculateHeat(grid)
    local totalHeat = 0

    for y = 1, 4 do
        for x = 1, 4 do
            local tile = grid[y][x]
            if tile then
                local heatContribution = Mechanics.HEAT_VALUES[tile.val] or 0
                totalHeat = totalHeat + heatContribution
            end
        end
    end

    return math.min(100, totalHeat)
end

-- Get current thermal state based on heat level
function Mechanics.getThermalState(heatLevel)
    if heatLevel >= Mechanics.THERMAL_THRESHOLDS.THROTTLING then
        return "throttling"
    elseif heatLevel >= Mechanics.THERMAL_THRESHOLDS.HOT then
        return "hot"
    elseif heatLevel >= Mechanics.THERMAL_THRESHOLDS.WARM then
        return "warm"
    else
        return "normal"
    end
end

-- Apply thermal throttling effects to score
function Mechanics.applyThermalScoreMultiplier(score, heatLevel)
    local thermalState = Mechanics.getThermalState(heatLevel)

    if thermalState == "throttling" then
        -- 50% score reduction when throttling
        return math.floor(score * 0.5)
    elseif thermalState == "hot" then
        -- 25% score reduction when hot
        return math.floor(score * 0.75)
    else
        return score
    end
end

-- Check if tile spawning should be restricted due to heat
function Mechanics.canSpawnTileValue(value, heatLevel)
    local thermalState = Mechanics.getThermalState(heatLevel)

    -- When hot or throttling, can't spawn tiles > 64
    if thermalState == "hot" or thermalState == "throttling" then
        return value <= 64
    end

    return true
end

-- Apply thermal throttling - randomly downgrade tiles when at 90%+ heat
function Mechanics.applyThermalThrottling(grid, heatLevel)
    if heatLevel < Mechanics.THERMAL_THRESHOLDS.THROTTLING then
        return false
    end

    -- 30% chance per throttling tick to downgrade a random high-tier tile (increased from 20%)
    if math.random() < 0.3 then
        local highTierTiles = {}

        for y = 1, 4 do
            for x = 1, 4 do
                local tile = grid[y][x]
                if tile and tile.val >= 64 then  -- Target RTX 3090 and above
                    table.insert(highTierTiles, {tile = tile, x = x, y = y})
                end
            end
        end

        if #highTierTiles > 0 then
            local target = highTierTiles[math.random(#highTierTiles)]
            local oldVal = target.tile.val
            target.tile.val = math.max(2, target.tile.val / 2)

            -- Visual feedback
            Renderer.updateTileMeta(target.tile.id, GameState.getTileMeta(target.tile.id))

            return true, target.x, target.y, oldVal, target.tile.val
        end
    end

    return false
end

-- Cool down heat (called after each action)
function Mechanics.coolDownHeat(currentHeat, amount)
    amount = amount or 1
    return math.max(0, currentHeat - amount)
end

-- ============================================================================
-- TENSOR CORE CASCADES
-- ============================================================================

-- RTX-tier cards that trigger tensor operations (RTX 2080 Ti and above)
Mechanics.RTX_TIERS = {
    [32] = true,   -- RTX 2080 Ti
    [64] = true,   -- RTX 3090
    [128] = true,  -- RTX 4090
    [256] = true,  -- A100
    [512] = true,  -- H100
    [1024] = true, -- GB200
    [2048] = true  -- Jensen's Kitchen
}

-- Check if a tile value is RTX-tier
function Mechanics.isRTXTier(value)
    return Mechanics.RTX_TIERS[value] == true
end

-- Apply tensor cascade effect when RTX tiles merge
function Mechanics.applyTensorCascade(grid, mergeX, mergeY)
    if not Mechanics.isRTXTier(grid[mergeY][mergeX].val) then
        return false
    end

    -- Find adjacent tiles
    local adjacentTiles = {}
    local directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}} -- up, right, down, left

    for _, dir in ipairs(directions) do
        local nx = mergeX + dir[1]
        local ny = mergeY + dir[2]

        if nx >= 1 and nx <= 4 and ny >= 1 and ny <= 4 then
            local tile = grid[ny][nx]
            if tile and tile.val < 2048 then -- Don't boost max tier
                table.insert(adjacentTiles, {tile = tile, x = nx, y = ny})
            end
        end
    end

    -- Boost a random adjacent tile
    if #adjacentTiles > 0 then
        local target = adjacentTiles[math.random(#adjacentTiles)]
        local oldVal = target.tile.val
        target.tile.val = target.tile.val * 2

        -- Visual effect
        Renderer.addTensorCascadeEffect(target.x, target.y)

        return true, target.x, target.y, oldVal, target.tile.val
    end

    return false
end

-- ============================================================================
-- NEURAL NETWORK TRAINING EPOCHS
-- ============================================================================

-- Training level thresholds
Mechanics.TRAINING_THRESHOLDS = {
    TRAINED = 10,      -- Tile becomes trained (2x score bonus)
    OVERTRAINED = 30,  -- Tile becomes overtrained (increased from 25)
    OVERTRAINED_DEADLINE = 12  -- Moves until game over (increased from 8)
}

-- Update training levels for all tiles (call each move)
function Mechanics.updateTrainingLevels(grid, tileMeta, moveCount)
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = grid[y][x]
            if tile then
                local meta = tileMeta[tile.id] or {}

                -- Initialize if needed
                if not meta.training then
                    meta.training = 0
                    meta.overtrained = false
                    meta.overtrainedMoves = 0
                end

                -- Increment training level
                meta.training = meta.training + 1

                -- Check for overtrained state
                if meta.training >= Mechanics.TRAINING_THRESHOLDS.OVERTRAINED and not meta.overtrained then
                    meta.overtrained = true
                    meta.overtrainedMoves = 0
                end

                -- Increment overtrained countdown
                if meta.overtrained then
                    meta.overtrainedMoves = meta.overtrainedMoves + 1

                    -- Game over if overtrained tile not merged within deadline
                    if meta.overtrainedMoves > Mechanics.TRAINING_THRESHOLDS.OVERTRAINED_DEADLINE then
                        return false, tile, x, y
                    end
                end

                tileMeta[tile.id] = meta
            end
        end
    end

    return true
end

-- Check if tile is trained (10+ moves)
function Mechanics.isTrained(meta)
    return meta and meta.training and meta.training >= Mechanics.TRAINING_THRESHOLDS.TRAINED
        and not meta.overtrained
end

-- Check if tile is overtrained
function Mechanics.isOvertrained(meta)
    return meta and meta.overtrained == true
end

-- Apply training bonus to score
function Mechanics.applyTrainingBonus(score, meta)
    if Mechanics.isTrained(meta) then
        return score * 2
    end
    return score
end

-- ============================================================================
-- DLSS MODE (AI UPSCALING) - REDESIGNED
-- ============================================================================

Mechanics.DLSS_MAX_CHARGES = 3
Mechanics.DLSS_REGEN_POINTS = 2000  -- Points needed to regenerate 1 charge (harder to get)

-- Apply DLSS upscaling to ANY tile - strategic power-up!
function Mechanics.applyDLSS(tile)
    -- Can't upgrade max tier
    if tile.val >= 2048 then
        return false, "Cannot upgrade max tier tile!"
    end

    -- Upscale tile (double its value)
    local oldVal = tile.val
    tile.val = tile.val * 2

    -- Return bonus score equal to the upgrade value
    local bonusScore = tile.val
    return true, bonusScore, oldVal
end

-- Calculate DLSS charge regeneration
function Mechanics.checkDLSSRegen(currentScore, previousScore, currentCharges)
    local currentMilestone = math.floor(currentScore / Mechanics.DLSS_REGEN_POINTS)
    local previousMilestone = math.floor(previousScore / Mechanics.DLSS_REGEN_POINTS)

    if currentMilestone > previousMilestone and currentCharges < Mechanics.DLSS_MAX_CHARGES then
        return true
    end

    return false
end

-- Detect SLI bridges (adjacent identical tiles)
function Mechanics.detectSLIBridges(grid)
    local bridges = {}
    local processed = {}

    for y = 1, 4 do
        for x = 1, 4 do
            local tile = grid[y][x]
            if tile and not processed[tile.id] then
                local bridge = {tile}
                local bridgePositions = {{x, y}}
                processed[tile.id] = true

                -- Check right
                local nx = x + 1
                if nx <= 4 then
                    local rightTile = grid[y][nx]
                    if rightTile and rightTile.val == tile.val and not processed[rightTile.id] then
                        table.insert(bridge, rightTile)
                        table.insert(bridgePositions, {nx, y})
                        processed[rightTile.id] = true

                        -- Check for third tile
                        nx = nx + 1
                        if nx <= 4 then
                            local tile3 = grid[y][nx]
                            if tile3 and tile3.val == tile.val and not processed[tile3.id] then
                                table.insert(bridge, tile3)
                                table.insert(bridgePositions, {nx, y})
                                processed[tile3.id] = true

                                -- Check for fourth tile
                                nx = nx + 1
                                if nx <= 4 then
                                    local tile4 = grid[y][nx]
                                    if tile4 and tile4.val == tile.val and not processed[tile4.id] then
                                        table.insert(bridge, tile4)
                                        table.insert(bridgePositions, {nx, y})
                                        processed[tile4.id] = true
                                    end
                                end
                            end
                        end
                    end
                end

                -- Check down (only if not already in horizontal bridge)
                if #bridge == 1 then
                    local ny = y + 1
                    if ny <= 4 then
                        local downTile = grid[ny][x]
                        if downTile and downTile.val == tile.val and not processed[downTile.id] then
                            table.insert(bridge, downTile)
                            table.insert(bridgePositions, {x, ny})
                            processed[downTile.id] = true

                            -- Check for third tile
                            ny = ny + 1
                            if ny <= 4 then
                                local tile3 = grid[ny][x]
                                if tile3 and tile3.val == tile.val and not processed[tile3.id] then
                                    table.insert(bridge, tile3)
                                    table.insert(bridgePositions, {x, ny})
                                    processed[tile3.id] = true

                                    -- Check for fourth tile
                                    ny = ny + 1
                                    if ny <= 4 then
                                        local tile4 = grid[ny][x]
                                        if tile4 and tile4.val == tile.val and not processed[tile4.id] then
                                            table.insert(bridge, tile4)
                                            table.insert(bridgePositions, {x, ny})
                                            processed[tile4.id] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                -- Only record bridges with 2+ tiles
                if #bridge >= 2 then
                    table.insert(bridges, {
                        tiles = bridge,
                        positions = bridgePositions,
                        count = #bridge
                    })
                end
            end
        end
    end

    return bridges
end

-- Calculate SLI bridge bonus
function Mechanics.getSLIBridgeBonus(bridgeCount)
    if bridgeCount == 2 then
        return 1.5  -- +50% score
    elseif bridgeCount == 3 then
        return 2.0  -- +100% score
    elseif bridgeCount >= 4 then
        return 3.0  -- +200% score
    end
    return 1.0
end

-- Get visual connections for renderer
function Mechanics.getSLIConnections(bridges)
    local connections = {}

    for _, bridge in ipairs(bridges) do
        for i = 1, #bridge.tiles - 1 do
            table.insert(connections, {
                tile1 = bridge.tiles[i].id,
                tile2 = bridge.tiles[i + 1].id
            })
        end
    end

    return connections
end

-- Apply SLI bonus when tiles in a bridge are merged
function Mechanics.applySLIBonus(score, tiles)
    -- Count how many tiles were in SLI formation
    local bridgeCount = #tiles
    local bonus = Mechanics.getSLIBridgeBonus(bridgeCount)

    return math.floor(score * bonus), bonus
end

return Mechanics
