local Logic = require("src.game_logic")
local Renderer = require("src.ui.renderer")
local Storage = require("src.storage")
local GameState = require("src.game_state")
local Mechanics = require("src.mechanics")
local Constants = require("src.constants")
local Audio = require("src.audio")
local Input = require("src.input")

local autoSaveCounter = 0

function love.load()
    love.window.setTitle("NVIDIA 2048: Neural Edition")
    math.randomseed(os.time())
    Renderer.load()

    local saved = Storage.loadGame()
    if saved then
        -- Import saved state
        GameState.import(saved)

        Renderer.reset()
        -- Restore visual state
        for y = 1, 4 do
            for x = 1, 4 do
                if GameState.grid[y][x] then
                    local tile = GameState.grid[y][x]
                    tile.x = x
                    tile.y = y
                    local meta = GameState.getTileMeta(tile.id)
                    Renderer.addTile(tile, meta)
                end
            end
        end

        if not Logic.canMove(GameState.grid) then
            GameState.state = "gameover"
            GameState.gameOverReason = "no_moves"
        end
    else
        resetGame()
    end

    -- Initialize Audio
    Audio.load()
    Audio.playBGM()

    -- FORCE SPLASH STATE ON LOAD
    GameState.state = "splash"
end

function love.update(dt)
    if GameState.state == "won" then
        Renderer.update(dt)
        return
    end

    local success, err = pcall(function()
        Renderer.update(dt)
        
        -- Check if game over crash animation is complete
        if GameState.state == "gameover_animating" and Renderer.isGameOverAnimComplete() then
            GameState.state = "gameover"
        end

        -- Update heat calculation every frame (for visuals)
        GameState.calculateHeat()

        -- Check for LQ tiles (Legacy support, though spawning removed)
        GameState.checkForLQTiles()

        -- Check for Win Condition (Reached 2048 - Jensen's Kitchen)
        if not GameState.hasWon then
            for y = 1, 4 do
                for x = 1, 4 do
                    local tile = GameState.grid[y][x]
                    if tile and tile.val >= 2048 then
                        GameState.state = "won"
                        GameState.hasWon = true
                        Renderer.addShake(20) 
                        Renderer.addConfetti()
                        print("VICTORY! Jensen's Kitchen reached!")
                        break
                    end
                end
                if GameState.state == "won" then break end
            end
        end

        -- Detect and display SLI bridges
        if GameState.state == "playing" then
            local bridges = Mechanics.detectSLIBridges(GameState.grid)
            local connections = Mechanics.getSLIConnections(bridges)
            
            -- Play SFX when new SLI bridge forms
            local currentBridgeCount = #bridges
            if not Renderer.lastBridgeCount then Renderer.lastBridgeCount = 0 end
            if currentBridgeCount > Renderer.lastBridgeCount then
                Audio.playSFX("sli_appear")
            end
            Renderer.lastBridgeCount = currentBridgeCount
            
            Renderer.setSLIConnections(connections)
        elseif GameState.state == "splash" then
             -- Splash Screen FX
             if math.random() < 0.05 then
                 local x = math.random(0, love.graphics.getWidth())
                 local y = math.random(0, love.graphics.getHeight())
                 table.insert(Renderer.particles, {
                     x = x, y = y,
                     vx = math.random(-20, 20), vy = math.random(-20, 20),
                     life = 2, maxLife = 2,
                     size = math.random(2, 4),
                     color = {0, 1, math.random(), 0.5}
                 })
             end
        end
    end)
    if not success then
        print("ERROR in update: " .. tostring(err))
    end
end

function love.mousepressed(x, y, button)
    if GameState.state == "splash" then
        GameState.state = "playing"
        return
    end

    if GameState.state == "gameover" then
        resetGame()
    end
end

function love.quit()
    Storage.saveGame(GameState.export())
end

function resetGame()
    GameState.init()
    Renderer.reset()
    autoSaveCounter = 0

    local t1 = Logic.spawnTile(GameState.grid)
    if t1 then
        local meta = GameState.getTileMeta(t1.id)
        Renderer.addTile(t1, meta)
    end
    local t2 = Logic.spawnTile(GameState.grid)
    if t2 then
        local meta = GameState.getTileMeta(t2.id)
        Renderer.addTile(t2, meta)
    end
    
    Audio.playBGM()
end

-- Process game movement logic
local function processMove(direction)
    -- Snapshot for SLI bonuses
    local preMoveSLIBridges = Mechanics.detectSLIBridges(GameState.grid)

    local moved, scoreAdd, moves = Logic.move(GameState.grid, direction)

    if not moved then return end

    -- Core Game Loop Steps
    GameState.decrementCooling()
    GameState.moveCount = GameState.moveCount + 1

    -- 1. Training Updates
    local trainingOk, failedTile, fx, fy = Mechanics.updateTrainingLevels(
        GameState.grid,
        GameState.tileMeta,
        GameState.moveCount
    )

    -- 2. Heat Updates
    GameState.calculateHeat()
    for _, move in ipairs(moves) do
        if move.type == "merge" then
            GameState.addHeat(move.tile.val)
        end
    end

    -- 3. Thermal Throttling
    if GameState.heatLevel >= Constants.MECHANICS.THERMAL_THROTTLE_TRIGGER then
        if not GameState.heatMaxWarningPlayed then
            Audio.playSFX("heat_max")
            GameState.heatMaxWarningPlayed = true
        end
        
        local throttled, tx, ty, oldVal, newVal = Mechanics.applyThermalThrottling(GameState.grid, GameState.heatLevel)
        if throttled then
             Renderer.animateDowngrade(GameState.grid[ty][tx].id, newVal, tx, ty)
             Renderer.addHeatTransferEffect(tx, ty)
             Renderer.addScorePopup(tx, ty, "THROTTLED", "overheat")
             Renderer.addShake(15)
             Audio.playSFX("downgrade")
             GameState.resetHeat()
             Renderer.heatWasInactive = (GameState.heatLevel <= 0)
        end
    end

    -- Check for Training Failure
    if not trainingOk then
        GameState.state = "gameover_animating"
        GameState.gameOverReason = "overtrained"
        Audio.playSFX("game_over")
        Audio.stopBGM()
        Renderer.triggerGameOverCrash()
        if failedTile then
            print(string.format("Neural collapse! Tile %s at (%d,%d) died.", failedTile.val, fx, fy))
        end
        return
    end

    -- 4. Scoring & Bonuses (Training + SLI)
    for _, move in ipairs(moves) do
        if move.type == "merge" then
            local baseMergeScore = move.tile.val
            if baseMergeScore >= 64 then
                Renderer.addScorePopup(move.tile.x, move.tile.y, baseMergeScore, "merge")
            end

            -- Training Bonus
            local sourceMeta = move.source and GameState.tileMeta[move.source.id]
            local targetMeta = move.target and GameState.tileMeta[move.target.id]
            
            if Mechanics.isTrained(sourceMeta) or Mechanics.isTrained(targetMeta) then
                scoreAdd = scoreAdd + baseMergeScore -- Doubles the score for this merge
                Renderer.addScorePopup(move.tile.x, move.tile.y, baseMergeScore, "training")
                Renderer.addShake(1.5)
            end

            -- SLI Bonus
            for _, bridge in ipairs(preMoveSLIBridges) do
                local inBridge = false
                -- Check if merged tiles were part of this bridge
                for _, tile in ipairs(bridge.tiles) do
                    if (move.source and tile.id == move.source.id) or
                       (move.target and tile.id == move.target.id) then
                        inBridge = true
                    end
                end

                if inBridge then
                    local bonusedScore, multiplier = Mechanics.applySLIBonus(baseMergeScore, bridge.tiles)
                    local sliBonusScore = bonusedScore - baseMergeScore
                    scoreAdd = scoreAdd + sliBonusScore

                    Renderer.addScorePopup(move.tile.x, move.tile.y, sliBonusScore, "sli")
                    Renderer.addSLIMergeEffect(move.tile.x, move.tile.y)
                    Renderer.addShake(12)
                    Audio.playSFX("sli_merge")
                    
                    if bridge.count >= 4 then print("QUAD-GPU ACHIEVEMENT!") end
                    break -- Max one SLI bonus per merge pair
                end
            end
        end
    end

    GameState.score = GameState.score + scoreAdd
    if GameState.score > GameState.bestScore then GameState.bestScore = GameState.score end
    
    GameState.cleanupOrphanedMeta()

    -- 5. Tensor Cascades (RTX Merges)
    for _, move in ipairs(moves) do
        if move.type == "merge" and Mechanics.isRTXTier(move.tile.val) then
            local cascaded, cx, cy, oldVal, newVal = Mechanics.applyTensorCascade(GameState.grid, move.tile.x, move.tile.y)
            if cascaded then
                Renderer.addTensorCascadeEffect(cx, cy)
                local cascadeBonus = math.floor(newVal * 0.5)
                GameState.score = GameState.score + cascadeBonus
                Renderer.addScorePopup(cx, cy, cascadeBonus, "tensor")
                Renderer.addShake(8)
            end
        end
    end

    -- Finalize Move
    Renderer.onMove(moves)
    
    -- Visual Update: SLI Connections
    local postMoveBridges = Mechanics.detectSLIBridges(GameState.grid)
    Renderer.setSLIConnections(Mechanics.getSLIConnections(postMoveBridges))

    -- Visual Update: Tile Meta
    for y = 1, 4 do
        for x = 1, 4 do
            local tile = GameState.grid[y][x]
            if tile then
                local meta = GameState.getTileMeta(tile.id)
                Renderer.updateTileMeta(tile.id, meta, tile.val)
            end
        end
    end

    -- Spawn New Tile
    local t = Logic.spawnTile(GameState.grid)
    if t then
        Renderer.addTile(t, GameState.getTileMeta(t.id))
    end

    -- DLSS Regen
    local previousScore = GameState.score - scoreAdd
    if Mechanics.checkDLSSRegen(GameState.score, previousScore, GameState.dlssCharges) then
        GameState.addDLSSCharge()
    end

    -- Auto Save
    autoSaveCounter = autoSaveCounter + 1
    if autoSaveCounter >= 10 then
        Storage.saveGame(GameState.export())
        autoSaveCounter = 0
    end

    -- Game Over Check
    if GameState.state == "playing" and not Logic.canMove(GameState.grid) then
        GameState.state = "gameover_animating"
        GameState.gameOverReason = "no_moves"
        Audio.playSFX("game_over")
        Audio.stopBGM()
        Renderer.triggerGameOverCrash()
    end
end

local function handleCheat(type)
    if type == "cheat_upgrade" then
        local bridges = Mechanics.detectSLIBridges(GameState.grid)
        if #bridges > 0 then
            for _, bridge in ipairs(bridges) do
                if #bridge.tiles >= 2 then
                    local t1, t2 = bridge.tiles[1], bridge.tiles[2]
                    t1.val = t1.val * 2
                    t2.val = t2.val * 2
                    GameState.addHeat(t1.val); GameState.addHeat(t2.val)
                    Renderer.updateTileMeta(t1.id, nil, t1.val)
                    Renderer.updateTileMeta(t2.id, nil, t2.val)
                    Renderer.addScorePopup(t1.x, t1.y, t1.val, "training")
                    Renderer.addScorePopup(t2.x, t2.y, t2.val, "training")
                    Renderer.addShake(10)
                    -- Update lines
                    Renderer.setSLIConnections(Mechanics.getSLIConnections(Mechanics.detectSLIBridges(GameState.grid)))
                    break
                end
            end
        end
    elseif type == "cheat_wipe" then
        Storage.clearSave()
        resetGame()
        Renderer.addScorePopup(2, 2, "SAVE WIPED", "training")
    end
end

function love.keypressed(key)
    local result = Input.handle(key)
    
    if result then
        if result.action == "move" then
            processMove(result.direction)
        elseif result.action == "reset" then
            resetGame()
        elseif result.action:match("cheat") then
            handleCheat(result.action)
        end
    end
end

function love.draw()
    if GameState.state == "splash" then
        Renderer.drawSplash()
        return
    end
    
    if GameState.state == "won" then
        Renderer.draw(GameState.score, "playing", GameState.bestScore, GameState.getDisplayState())
        Renderer.drawVictory()
        return
    end

    local displayState = GameState.getDisplayState()
    displayState.selectedTileForDLSS = GameState.selectedTileForDLSS
    Renderer.draw(GameState.score, GameState.state, GameState.bestScore, displayState)

    -- Pause overlay
    if GameState.state == "paused" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Renderer.fontHuge)
        love.graphics.printf("PAUSED", 0, 250, love.graphics.getWidth(), "center")
        love.graphics.setFont(Renderer.fontLarge)
        love.graphics.printf("Press ESC to resume", 0, 310, love.graphics.getWidth(), "center")

        love.graphics.setFont(Renderer.fontSmall)
        love.graphics.setColor(1, 1, 0)
        love.graphics.printf("SPACE: Use DLSS Upgrade tile (except GB200)", 0, 370, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Ctrl+R: Restart Game", 0, 395, love.graphics.getWidth(), "center")
    end
end
