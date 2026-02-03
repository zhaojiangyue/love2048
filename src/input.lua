local GameState = require("src.game_state")
local Mechanics = require("src.mechanics")
local Renderer = require("src.ui.renderer")
local Audio = require("src.audio")
local Storage = require("src.storage")
local Constants = require("src.constants")

local Input = {}

-- Helper to handle the DLSS selection cursor movement
local function moveDLSSCursor(dx, dy)
    if not GameState.selectedTileForDLSS then return end
    
    local newX = GameState.selectedTileForDLSS.x + dx
    local newY = GameState.selectedTileForDLSS.y + dy
    
    -- Clamp to grid
    if newX >= 1 and newX <= 4 then GameState.selectedTileForDLSS.x = newX end
    if newY >= 1 and newY <= 4 then GameState.selectedTileForDLSS.y = newY end
    
    -- Logging (optional, kept from original logic)
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

-- Execute the DLSS Action on the currently selected tile
local function executeDLSS()
    if GameState.dlssCharges == 0 then
        print("DLSS unavailable: Out of charges! Earn points to regenerate.")
        return
    end

    local tx = GameState.selectedTileForDLSS.x
    local ty = GameState.selectedTileForDLSS.y
    local tile = GameState.grid[ty][tx]

    if tile then
        local success, bonusScore, oldVal = Mechanics.applyDLSS(tile)

        if success then
            GameState.useDLSSCharge()
            Renderer.addDLSSEffect(tx, ty)
            
            -- Update visual meta
            local meta = GameState.getTileMeta(tile.id)
            Renderer.updateTileMeta(tile.id, meta, tile.val)

            -- Score & Feedback
            GameState.score = GameState.score + bonusScore
            if GameState.score > GameState.bestScore then
                GameState.bestScore = GameState.score
            end

            Renderer.addScorePopup(tx, ty, bonusScore, "dlss")
            Renderer.addShake(6)
            Audio.playSFX("dlss_upgrade")
            
            -- Recalculate heat
            GameState.calculateHeat()

            print(string.format("DLSS Upscaling! %d -> %d (+%d points). Charges: %d/3",
                oldVal, tile.val, bonusScore, GameState.dlssCharges))

            -- Check Victory
            if not GameState.hasWon and tile.val == 2048 then
                GameState.hasWon = true
                GameState.state = "won"
                print("WINNER! Triggering Victory Screen (via DLSS).")
            end

            GameState.selectedTileForDLSS = nil -- Exit mode
        else
            print(bonusScore) -- Error message
        end
    else
        print("No tile at selected position!")
    end
end

-- Main key handler
function Input.handle(key)
    -- Global: Mute
    if key == "m" then
        if Audio.toggleMute() then print("Audio Muted") else print("Audio Unmuted") end
        return
    end

    -- Global: Splash Screen Exit
    if GameState.state == "splash" then
        if not (key:match("ctrl") or key:match("alt") or key:match("shift")) then
             GameState.state = "playing"
        end
        return
    end

    -- Global: Restart (Ctrl+R)
    if key == "r" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        GameState.selectedTileForDLSS = nil
        -- We need a callback or access to resetGame. 
        -- For now, we return a command string that main.lua interprets, 
        -- OR we can require main... no, circular dependency.
        -- Better: Return an action table.
        return { action = "reset" }
    elseif key == "r" and GameState.state ~= "splash" then
        print("Press Ctrl+R to restart the game")
    end

    -- Global: Cheat Codes
    if (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) and 
       (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
        if key == "f1" then return { action = "cheat_upgrade" } end
        if key == "f2" then return { action = "cheat_wipe" } end
    end

    -- State: Won
    if GameState.state == "won" then
        if key == "return" then
            GameState.state = "playing" -- Continue
        end
        return
    end

    -- State: Playing or Paused
    if key == "escape" then
        if GameState.selectedTileForDLSS then
            print("DLSS selection cancelled")
            GameState.selectedTileForDLSS = nil
        elseif GameState.state == "playing" then
            GameState.state = "paused"
            Audio.pauseBGM()
        elseif GameState.state == "paused" then
            GameState.state = "playing"
            Audio.playBGM()
        end
        return
    end

    -- Stop processing if paused or gameover
    if GameState.state ~= "playing" then return end

    -- DLSS Selection Mode
    if GameState.selectedTileForDLSS then
        if key == "left" then moveDLSSCursor(-1, 0)
        elseif key == "right" then moveDLSSCursor(1, 0)
        elseif key == "up" then moveDLSSCursor(0, -1)
        elseif key == "down" then moveDLSSCursor(0, 1)
        elseif key == "space" then executeDLSS()
        end
        return
    end

    -- Activation: Enter DLSS Mode
    if key == "space" then
        if GameState.dlssCharges == 0 then
            print("DLSS unavailable: Out of charges!")
        else
            print("DLSS READY: Select tile and press SPACE.")
            -- Find first non-empty or default to 1,1
            GameState.selectedTileForDLSS = {x=1, y=1}
            local found = GameState.findFirstLQTile() -- Prioritize LQ? No, per new design any tile.
             -- Just find any tile to start cursor on
            for y=1,4 do for x=1,4 do if GameState.grid[y][x] then GameState.selectedTileForDLSS={x=x,y=y} goto found end end end
            ::found::
        end
        return
    end

    -- Gameplay: Movement
    if key == "left" or key == "right" or key == "up" or key == "down" then
        return { action = "move", direction = key }
    end
end

return Input
