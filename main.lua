local Logic = require("src.game_logic")
local Renderer = require("src.ui.renderer")
local Storage = require("src.storage")
local GameState = require("src.game_state")
local Mechanics = require("src.mechanics")
local Constants = require("src.constants")
local Audio = require("src.audio")

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

        -- Update heat calculation every frame
        GameState.calculateHeat()

        -- Check for LQ tiles
        GameState.checkForLQTiles()

        -- Check for Win Condition (Reached 2048 - Jensen's Kitchen)
        if not GameState.hasWon then
            for y = 1, 4 do
                for x = 1, 4 do
                    local tile = GameState.grid[y][x]
                    if tile and tile.val >= 2048 then
                        GameState.state = "won"
                        GameState.hasWon = true
                        Renderer.addShake(20) -- Massive shake for victory
                        Renderer.addConfetti() -- Celebration!
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
            Renderer.setSLIConnections(connections)
        elseif GameState.state == "splash" then
             -- Add subtle particle movement on splash
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
        -- Transition to game
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
end

function love.keypressed(key)
    -- Pause/unpause
    if key == "escape" then
        -- If in SPLASH mode, quit? Or just ignore
        if GameState.state == "splash" then
            love.event.quit()
            return
        end

        -- If in DLSS selection mode, exit it first
        if GameState.selectedTileForDLSS then
            print("DLSS selection cancelled")
            GameState.selectedTileForDLSS = nil
            return
        end

        -- Otherwise toggle pause
        if GameState.state == "playing" then
            GameState.state = "paused"
            Audio.pauseBGM()
        elseif GameState.state == "paused" then
            GameState.state = "playing"
            Audio.playBGM()
        end
        return
    end

    -- Mute Toggle (M)
    if key == "m" then
        if Audio.toggleMute() then
            print("Audio Muted")
        else
            print("Audio Unmuted")
        end
        return
    end

    -- Reset commands - Require Ctrl+R to prevent accidental resets
    if key == "r" then
        if GameState.state == "splash" then return end -- Ignore R in splash
        
        if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
            -- Ctrl+R: Restart game
            GameState.selectedTileForDLSS = nil  -- Clear DLSS mode
            resetGame()
            print("Game restarted! (Ctrl+R)")
        else
            -- Just R pressed - show hint
            print("Press Ctrl+R to restart the game")
        end
        return
    end

    -- CHEAT CODE: Ctrl + Alt + F1 (Level up connected items)
    if key == "f1" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
        local bridges = Mechanics.detectSLIBridges(GameState.grid)
        local cheated = false
        if #bridges > 0 then
            -- Find a bridge with at least 2 tiles
            for _, bridge in ipairs(bridges) do
                if #bridge.tiles >= 2 then
                    -- Upgrade first 2 tiles
                    local t1 = bridge.tiles[1]
                    local t2 = bridge.tiles[2]
                    
                    t1.val = t1.val * 2
                    t2.val = t2.val * 2
                    
                    -- Update visuals
                    Renderer.updateTileMeta(t1.id, nil, t1.val)
                    Renderer.updateTileMeta(t2.id, nil, t2.val)
                    
                    Renderer.addScorePopup(t1.x, t1.y, t1.val, "training")
                    Renderer.addScorePopup(t2.x, t2.y, t2.val, "training")
                    Renderer.addShake(10)
                    print("CHEAT EXECUTED: Upgraded connected tiles!")
                    cheated = true
                    
                    -- Rerun detection to update lines
                     local newBridges = Mechanics.detectSLIBridges(GameState.grid)
                     local connections = Mechanics.getSLIConnections(newBridges)
                     Renderer.setSLIConnections(connections)
                    break 
                end
            end
        end
        if not cheated then
            print("CHEAT FAILED: No connected tiles found.")
        end
        return
    end

    -- CHEAT CODE: Ctrl + Alt + F2 (Wipe Save)
    if key == "f2" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
        Storage.clearSave()
        GameState.bestScore = 0
        resetGame()
        Renderer.addScorePopup(2, 2, "SAVE WIPED", "training")
        print("CHEAT EXECUTED: Save data wiped and game reset.")
        return
    end

    -- DLSS upscaling (SPACE key) - REDESIGNED: Upgrade ANY tile!
    if key == "space" then
        if GameState.state == "playing" then
            -- Check if we have charges
            if GameState.dlssCharges == 0 then
                print("DLSS unavailable: Out of charges! Earn 2000 points to regenerate.")
                return
            end

            -- Enter tile selection mode
            if not GameState.selectedTileForDLSS then
                print("DLSS READY: Use arrow keys to select a tile, then press SPACE to upgrade it!")
                GameState.selectedTileForDLSS = {x = 1, y = 1}
                -- Find first non-empty tile
                for y = 1, 4 do
                    for x = 1, 4 do
                        if GameState.grid[y][x] then
                            GameState.selectedTileForDLSS = {x = x, y = y}
                            return
                        end
                    end
                end
            else
                -- Apply DLSS to selected tile
                local tx = GameState.selectedTileForDLSS.x
                local ty = GameState.selectedTileForDLSS.y
                local tile = GameState.grid[ty][tx]

                if tile then
                    local success, bonusScore, oldVal = Mechanics.applyDLSS(tile)

                    if success then
                        -- Use DLSS charge
                        GameState.useDLSSCharge()

                        -- Visual effects
                        Renderer.addDLSSEffect(tx, ty)
                        local meta = GameState.getTileMeta(tile.id)
                        Renderer.updateTileMeta(tile.id, meta, tile.val)

                        -- Award bonus score
                        GameState.score = GameState.score + bonusScore
                        if GameState.score > GameState.bestScore then
                            GameState.bestScore = GameState.score
                        end

                        -- Visual feedback
                        Renderer.addScorePopup(tx, ty, bonusScore, "dlss")
                        Renderer.addShake(6)

                        -- Recalculate heat
                        GameState.calculateHeat()

                        print(string.format("DLSS Upscaling! %d → %d (+%d points). Charges: %d/3",
                            oldVal, tile.val, bonusScore, GameState.dlssCharges))

                        -- CHECK FOR VICTORY (Jensen's Kitchen)
                        if not GameState.hasWon and tile.val == 2048 then
                            GameState.hasWon = true
                            GameState.state = "won"
                            print("WINNER! Triggering Victory Screen (via DLSS).")
                        end

                        GameState.selectedTileForDLSS = nil
                    else
                        print(bonusScore) -- Error message
                    end
                else
                    print("No tile at selected position!")
                end
            end
        end
        return
    end

    -- Arrow key navigation for DLSS tile selection
    if GameState.selectedTileForDLSS then
        local moved = false
        if key == "left" and GameState.selectedTileForDLSS.x > 1 then
            GameState.selectedTileForDLSS.x = GameState.selectedTileForDLSS.x - 1
            moved = true
        elseif key == "right" and GameState.selectedTileForDLSS.x < 4 then
            GameState.selectedTileForDLSS.x = GameState.selectedTileForDLSS.x + 1
            moved = true
        elseif key == "up" and GameState.selectedTileForDLSS.y > 1 then
            GameState.selectedTileForDLSS.y = GameState.selectedTileForDLSS.y - 1
            moved = true
        elseif key == "down" and GameState.selectedTileForDLSS.y < 4 then
            GameState.selectedTileForDLSS.y = GameState.selectedTileForDLSS.y + 1
            moved = true
        end

        if moved then
            local tile = GameState.grid[GameState.selectedTileForDLSS.y][GameState.selectedTileForDLSS.x]
            if tile then
                local tier = Constants.TIERS[tile.val]
                print(string.format("Selected: %s (value: %d) at (%d,%d)",
                    tier and tier.name or "Unknown", tile.val,
                    GameState.selectedTileForDLSS.x, GameState.selectedTileForDLSS.y))
            else
                print(string.format("Empty cell at (%d,%d)",
                    GameState.selectedTileForDLSS.x, GameState.selectedTileForDLSS.y))
            end
        end
        return
    end





    -- Handle Splash Screen Input (Any key starts game)
    if GameState.state == "splash" then
        -- Exclude modifier keys to prevent accidental starts while tabbing
        if key ~= "lctrl" and key ~= "rctrl" and key ~= "lalt" and key ~= "ralt" and key ~= "lshift" and key ~= "rshift" then
             GameState.state = "playing"
        end
        return
    end

    if GameState.state == "gameover" or GameState.state == "paused" then
        return
    end
    
    if GameState.state == "won" then
        if key == "return" then
            -- Continue playing (Endless Mode)
            GameState.state = "playing"
        elseif key == "r" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
            -- Restart
            resetGame()
            GameState.state = "playing" -- resetGame sets derived state, ensure playing
        end
        return
    end

    local moved, scoreAdd, moves = false, 0, {}

    if key == "left" or key == "right" or key == "up" or key == "down" then
        -- Detect SLI bridges BEFORE the move to apply bonuses correctly
        -- The move destroys the original tiles, so we must snapshot the state first.
        local preMoveSLIBridges = Mechanics.detectSLIBridges(GameState.grid)

        moved, scoreAdd, moves = Logic.move(GameState.grid, key)

        if moved then
            -- Increment move counter
            GameState.moveCount = GameState.moveCount + 1

            -- Update training levels for all tiles using Mechanics module
            local trainingOk, failedTile, fx, fy = Mechanics.updateTrainingLevels(
                GameState.grid,
                GameState.tileMeta,
                GameState.moveCount
            )

            -- Recalculate Heat
            GameState.calculateHeat()

            -- Apply Thermal Throttling (Downgrade tiles if too hot)
            local throttled, tx, ty, oldVal, newVal = Mechanics.applyThermalThrottling(GameState.grid, GameState.heatLevel)
            if throttled then
                 -- Update visual meta for the downgraded tile
                 local tile = GameState.grid[ty][tx]
                 Renderer.updateTileMeta(tile.id, nil, tile.val)
                 
                 -- Visual feedback
                 Renderer.addScorePopup(tx, ty, "THROTTLED", "overheat")
                 Renderer.addShake(15)
                 print(string.format("SYSTEM OVERHEAT! Throttling kicked in. Downgraded tile at (%d,%d): %d -> %d", tx, ty, oldVal, newVal))
            end

            if not trainingOk then
                -- Game over due to overtrained tile
                GameState.state = "gameover"
                GameState.gameOverReason = "overtrained"

                -- Show which tile caused the failure
                if failedTile then
                    print(string.format("Neural network collapsed! Tile %s at (%d,%d) exceeded training limits",
                        failedTile.val, fx, fy))
                end
                return
            end

            -- Apply training bonus to score from merges
            -- Also check pre-move SLI bridges for bonus multipliers
            local mergedTileIds = {}

            for _, move in ipairs(moves) do
                if move.type == "merge" then
                    -- Track which tiles were merged
                    if move.source then table.insert(mergedTileIds, move.source.id) end
                    if move.target then table.insert(mergedTileIds, move.target.id) end

                    -- Show base merge score
                    -- Show base merge score (Only for Level 2+ tiles)
                    local baseMergeScore = move.tile.val
                    if baseMergeScore >= 64 then
                        Renderer.addScorePopup(move.tile.x, move.tile.y, baseMergeScore, "merge")
                    end

                    -- Check if either source or target was trained
                    local sourceMeta = move.source and GameState.tileMeta[move.source.id]
                    local targetMeta = move.target and GameState.tileMeta[move.target.id]
                    local hadTrainingBonus = false

                    if Mechanics.isTrained(sourceMeta) or Mechanics.isTrained(targetMeta) then
                        -- Apply training bonus to the merge score
                        local bonusScore = baseMergeScore -- 2x total = original + bonus
                        scoreAdd = scoreAdd + bonusScore
                        hadTrainingBonus = true

                        -- Visual feedback for training bonus
                        Renderer.addScorePopup(move.tile.x, move.tile.y, bonusScore, "training")
                        Renderer.addShake(1.5) -- Level 2: Tiny Shake (Reduced)
                    end

                    -- Check if merged tiles were part of an SLI bridge (using pre-move snapshot)
                    for _, bridge in ipairs(preMoveSLIBridges) do
                        local inBridge = false
                        local bridgeTileIds = {}

                        for _, tile in ipairs(bridge.tiles) do
                            table.insert(bridgeTileIds, tile.id)
                            -- Check if this merged tile was in the bridge
                            if (move.source and tile.id == move.source.id) or
                               (move.target and tile.id == move.target.id) then
                                inBridge = true
                            end
                        end

                        if inBridge then
                            -- Apply SLI bridge bonus
                            local bonusedScore, multiplier = Mechanics.applySLIBonus(baseMergeScore, bridge.tiles)
                            local sliBonusScore = bonusedScore - baseMergeScore

                            scoreAdd = scoreAdd + sliBonusScore

                            -- Visual feedback for SLI bonus
                            Renderer.addScorePopup(move.tile.x, move.tile.y, sliBonusScore, "sli")
                            Renderer.addSLIMergeEffect(move.tile.x, move.tile.y) -- Trigger new NVLink surge
                            Renderer.addShake(12) -- Increased shake for impact

                            -- Special achievement for 4-tile bridge (Quad-GPU)
                            if bridge.count >= 4 then
                                print("QUAD-GPU ACHIEVEMENT! 4-tile SLI bridge merged!")
                            end

                            print(string.format("SLI Bridge bonus! %d-tile formation = %.1fx multiplier (+%d points)",
                                bridge.count, multiplier, sliBonusScore))

                            break -- Only apply bonus once per merge
                        end
                    end
                end
            end

            -- Update score with potential training bonuses
            GameState.score = GameState.score + scoreAdd
            if GameState.score > GameState.bestScore then
                GameState.bestScore = GameState.score
            end

            -- Clean up metadata for merged tiles
            GameState.cleanupOrphanedMeta()

            -- Apply Tensor Core Cascades for RTX merges
            for _, move in ipairs(moves) do
                if move.type == "merge" then
                    local mergedTile = move.tile
                    if Mechanics.isRTXTier(mergedTile.val) then
                        -- Trigger tensor cascade effect
                        local cascaded, cx, cy, oldVal, newVal = Mechanics.applyTensorCascade(
                            GameState.grid,
                            mergedTile.x,
                            mergedTile.y
                        )

                        if cascaded then
                            -- Visual feedback for tensor cascade
                            Renderer.addTensorCascadeEffect(cx, cy)

                            -- Add bonus score for cascade effect
                            local cascadeBonus = math.floor(newVal * 0.5)
                            GameState.score = GameState.score + cascadeBonus

                            -- Show score popup for tensor cascade
                            Renderer.addScorePopup(cx, cy, cascadeBonus, "tensor")
                            Renderer.addShake(8) -- Level 4: Shake + Visuals


                            print(string.format("Tensor cascade! Boosted tile at (%d,%d) from %d to %d (+%d points)",
                                cx, cy, oldVal, newVal, cascadeBonus))
                        end
                    end
                end
            end

            -- Animate moves
            Renderer.onMove(moves)

            -- Update visual NVLink connections (Post-move)
            local postMoveSLIBridges = Mechanics.detectSLIBridges(GameState.grid)
            local connections = Mechanics.getSLIConnections(postMoveSLIBridges)
            Renderer.setSLIConnections(connections)

            -- Update visual metadata for all tiles on board
            for y = 1, 4 do
                for x = 1, 4 do
                    local tile = GameState.grid[y][x]
                    if tile then
                        local meta = GameState.getTileMeta(tile.id)
                        -- Sync BOTH metadata AND value to ensure visuals always match logic
                        Renderer.updateTileMeta(tile.id, meta, tile.val)
                    end
                end
            end

            -- Spawn new tile (NO MORE LQ TILES!)
            local t = Logic.spawnTile(GameState.grid)
            if t then
                local meta = GameState.getTileMeta(t.id)
                Renderer.addTile(t, meta)
            end

            -- Cool down heat by 1% per move
            GameState.coolDown()

            -- Regenerate DLSS charge every 2000 points using Mechanics module
            local previousScore = GameState.score - scoreAdd
            if Mechanics.checkDLSSRegen(GameState.score, previousScore, GameState.dlssCharges) then
                GameState.addDLSSCharge()
                print(string.format("DLSS charge regenerated! Charges: %d/3 - Press SPACE to boost a tile!", GameState.dlssCharges))
            end

            -- Apply thermal throttling when heat >= Throttling Threshold
            if GameState.heatLevel >= Constants.MECHANICS.THERMAL_THRESHOLDS.THROTTLING then
                local throttled, tx, ty, oldVal, newVal = Mechanics.applyThermalThrottling(GameState.grid, GameState.heatLevel)
                if throttled then
                    print(string.format("⚠ THERMAL THROTTLING! Tile at (%d,%d) downgraded: %d → %d", tx, ty, oldVal, newVal))
                    Renderer.updateTileMeta(GameState.grid[ty][tx].id, GameState.getTileMeta(GameState.grid[ty][tx].id), newVal)
                    Renderer.addHeatTransferEffect(tx, ty) -- Visual feedback: Heat Strike!
                    Renderer.addShake(4) -- Level 3: Normal Shake (Reduced)
                    
                    -- Update visual NVLink connections (Post-throttle)
                    local postThrottleBridges = Mechanics.detectSLIBridges(GameState.grid)
                    local connections = Mechanics.getSLIConnections(postThrottleBridges)
                    Renderer.setSLIConnections(connections)
                end
            end

            -- Auto-save every 10 moves
            autoSaveCounter = autoSaveCounter + 1
            if autoSaveCounter >= 10 then
                Storage.saveGame(GameState.export())
                autoSaveCounter = 0
            end

            -- Check for Win Condition (Reached 2048)
            if not GameState.hasWon then
                for y=1,4 do
                    for x=1,4 do
                        local tile = GameState.grid[y][x]
                        if tile and tile.val == 2048 then
                            GameState.hasWon = true
                            GameState.state = "won"
                            Renderer.addConfetti() -- Trigger confetti immediately!
                            Renderer.addShake(20)
                            print("WINNER! Triggering Victory Screen.")
                        end
                    end
                end
            end

            -- Check game over
            if GameState.state == "playing" and not Logic.canMove(GameState.grid) then
                GameState.state = "gameover"
                GameState.gameOverReason = "no_moves"
            end
        end
    end
end

function love.draw()
    if GameState.state == "splash" then
        Renderer.drawSplash()
        return
    end
    
    if GameState.state == "won" then
        Renderer.draw(GameState.score, "playing", GameState.bestScore, GameState.getDisplayState()) -- Draw game behind
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

        -- Show controls
        love.graphics.setFont(Renderer.fontSmall)
        love.graphics.setColor(1, 1, 0) -- Yellow
        love.graphics.printf("SPACE: Use DLSS Upgrade tile (except GB200)", 0, 370, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 1, 1) -- Reset to White
        love.graphics.printf("Ctrl+R: Restart Game", 0, 395, love.graphics.getWidth(), "center")
    end
end
