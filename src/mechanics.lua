local GameState = require("src.game_state")
local Renderer = require("src.ui.renderer")
local Constants = require("src.constants")

local Mechanics = {}

-- ============================================================================
-- HEAT MANAGEMENT SYSTEM
-- ============================================================================


-- Heat values are now pulled from Constants.MECHANICS.HEAT_VALUES
-- Thermal thresholds are now pulled from Constants.MECHANICS.THERMAL_THRESHOLDS


-- Calculate heat based on high-tier tiles on board
function Mechanics.calculateHeat(grid)
    local totalHeat = 0

    for y = 1, 4 do
        for x = 1, 4 do
            local tile = grid[y][x]
            if tile then
                local heatContribution = Constants.MECHANICS.HEAT_VALUES[tile.val] or 0
                totalHeat = totalHeat + heatContribution
            end
        end
    end

    return math.min(100, totalHeat)
end

-- Get current thermal state based on heat level
-- Get current thermal state based on heat level
function Mechanics.getThermalState(heatLevel)
    if heatLevel >= Constants.MECHANICS.THERMAL_THRESHOLDS.THROTTLING then
        return "throttling"
    elseif heatLevel >= Constants.MECHANICS.THERMAL_THRESHOLDS.HOT then
        return "hot"
    elseif heatLevel >= Constants.MECHANICS.THERMAL_THRESHOLDS.WARM then
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
    if heatLevel < Constants.MECHANICS.THERMAL_THRESHOLDS.THROTTLING then
        return false
    end

    -- Chance per throttling tick to downgrade a random high-tier tile
    if math.random() < Constants.MECHANICS.THERMAL_THROTTLE_CHANCE then
        local highTierTiles = {}

        for y = 1, 4 do
            for x = 1, 4 do
                local tile = grid[y][x]
                if tile and tile.val >= 16 then  -- Target GTX 1080 Ti and above
                    table.insert(highTierTiles, {tile = tile, x = x, y = y})
                end
            end
        end

        if #highTierTiles > 0 then
            local target = highTierTiles[math.random(#highTierTiles)]
            local oldVal = target.tile.val
            target.tile.val = math.max(2, target.tile.val / 2)

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
Mechanics.DLSS_REGEN_POINTS = 500  -- Points needed to regenerate 1 charge (every 500 points)

-- Apply DLSS upscaling to ANY tile - strategic power-up!
function Mechanics.applyDLSS(tile)
    -- Can't upgrade max tier
    -- Can't upgrade max tier OR the tier just before it
    -- You must manually merge for the final victory (Jensen's Kitchen)
    if tile.val >= 1024 then
        return false, "Cannot use DLSS on GB200! You must merge manually to reach Jensen's Kitchen."
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
-- Detect SLI bridges (connected groups of identical tiles) using Flood Fill
function Mechanics.detectSLIBridges(grid)
    local bridges = {}
    local processed = {} -- Set of processed tile IDs

    for y = 1, 4 do
        for x = 1, 4 do
            local startTile = grid[y][x]
            if startTile and not processed[startTile.id] then
                -- Start a new cluster search
                local cluster = {startTile}
                local clusterPositions = {{x, y}}
                processed[startTile.id] = true
                
                -- Queue for BFS
                local queue = {{tile=startTile, x=x, y=y}}
                local head = 1
                
                while head <= #queue do
                    local curr = queue[head]
                    head = head + 1
                    
                    -- Check all 4 neighbors
                    local neighbors = {
                        {x = curr.x + 1, y = curr.y}, -- Right
                        {x = curr.x - 1, y = curr.y}, -- Left
                        {x = curr.x, y = curr.y + 1}, -- Down
                        {x = curr.x, y = curr.y - 1}  -- Up
                    }
                    
                    for _, pos in ipairs(neighbors) do
                        if pos.x >= 1 and pos.x <= 4 and pos.y >= 1 and pos.y <= 4 then
                            local neighborTile = grid[pos.y][pos.x]
                            
                            -- If match found and not processed
                            if neighborTile and neighborTile.val == startTile.val and not processed[neighborTile.id] then
                                table.insert(cluster, neighborTile)
                                table.insert(clusterPositions, {pos.x, pos.y})
                                processed[neighborTile.id] = true
                                table.insert(queue, {tile=neighborTile, x=pos.x, y=pos.y})
                            end
                        end
                    end
                end

                -- If valid bridge (2+ tiles), save it
                if #cluster >= 2 then
                    table.insert(bridges, {
                        tiles = cluster,
                        positions = clusterPositions,
                        count = #cluster
                    })
                end
            end
        end
    end

    return bridges
end

-- Calculate SLI bridge bonus - MUCH STRONGER!
function Mechanics.getSLIBridgeBonus(bridgeCount)
    if bridgeCount == 2 then
        return 3.0  -- +200% score (was 1.5x)
    elseif bridgeCount == 3 then
        return 5.0  -- +400% score (was 2.0x)
    elseif bridgeCount >= 4 then
        return 10.0  -- +900% score!! (was 3.0x)
    end
    return 1.0
end

-- Get visual connections for renderer (all adjacent pairs in a bridge)
function Mechanics.getSLIConnections(bridges)
    local connections = {}

    for _, bridge in ipairs(bridges) do
        -- For every tile in the bridge, check every other tile
        -- If they are adjacent, add a connection
        for i = 1, #bridge.tiles do
            local t1 = bridge.tiles[i]
            -- Only check j > i to avoid duplicates
            for j = i + 1, #bridge.tiles do
                local t2 = bridge.tiles[j]
                
                -- Check adjacency logic (manhattan distance == 1)
                -- We need coordinates. Since tiles store logical x/y, we use that.
                -- Note: logic x/y might be updated by move, but bridge detection runs on current grid.
                -- Let's trust the tiles' internal x/y or use the positions captured.
                -- Using tile.x and tile.y should be safe if grid is consistent.
                
                local dx = math.abs(t1.x - t2.x)
                local dy = math.abs(t1.y - t2.y)
                
                if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) then
                     table.insert(connections, {
                        tile1 = t1.id,
                        tile2 = t2.id
                    })
                end
            end
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
