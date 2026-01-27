local Logic = require("src.game_logic")
local Renderer = require("src.ui.renderer")
local Storage = require("src.storage")

local bestScore = 0

function love.load()
    love.window.setTitle("NVIDIA 2048")
    math.randomseed(os.time())
    Renderer.load()
    
    local saved = Storage.loadGame()
    if saved then
        grid = saved.grid
        score = saved.score
        bestScore = saved.highscore or 0
        state = "playing"
        
        Renderer.reset()
        -- Restore visual state
        for y = 1, 4 do
            for x = 1, 4 do
                if grid[y][x] then
                    -- Reset visual properties since we are loading fresh
                    grid[y][x].x = x
                    grid[y][x].y = y
                    Renderer.addTile(grid[y][x])
                end
            end
        end
        if not Logic.canMove(grid) then
            state = "gameover"
        end
    else
        resetGame()
    end
end

function love.update(dt)
    local success, err = pcall(function()
        Renderer.update(dt)
    end)
    if not success then
        print("ERROR in update: " .. tostring(err))
    end
end

function love.mousepressed(x, y, button)
    if state == "gameover" then
        resetGame()
    end
end

function love.quit()
    Storage.saveGame(grid, score, math.max(score, bestScore))
end

function resetGame()
    grid = Logic.initGrid()
    Renderer.reset()
    score = 0
    state = "playing"
    
    local t1 = Logic.spawnTile(grid)
    if t1 then Renderer.addTile(t1) end
    local t2 = Logic.spawnTile(grid)
    if t2 then Renderer.addTile(t2) end
end

function love.keypressed(key)
    if key == "r" then
        if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
            -- Shift+R: Wipe Save and Restart
            Storage.clearSave()
            -- Reset best score manually since we just wiped it
            bestScore = 0
            resetGame()
        else
            -- Regular R: Just restart current game (keeps high score if we were saving it separately, but currently highscore is in savefile)
            -- Actually, Storage.saveGame writes both.
            resetGame() 
        end
        return
    end

    if state == "gameover" then
        return
    end
    
    local moved, scoreAdd, moves = false, 0, {}
    
    if key == "left" or key == "right" or key == "up" or key == "down" then
        moved, scoreAdd, moves = Logic.move(grid, key)
        
        if moved then
            score = score + scoreAdd
            if score > bestScore then bestScore = score end
            
            Renderer.onMove(moves)
            
            local t = Logic.spawnTile(grid)
            if t then 
                Renderer.addTile(t) 
            end
            
            -- Auto-save on move? Maybe too expensive for disk IO every move?
            -- Let's stick to love.quit for now, or maybe every 10 moves.
            
            if not Logic.canMove(grid) then
                state = "gameover"
            end
        end
    end
end

function love.draw()
    Renderer.draw(score, state, bestScore)
end

