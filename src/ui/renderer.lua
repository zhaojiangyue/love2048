local Constants = require("src.constants")
local flux = require("src.lib.flux")

local Renderer = {}
Renderer.visualTiles = {} -- List of {id, val, x, y, opacity, scale, isDead}

function Renderer.load()
    Renderer.fontSmall = love.graphics.newFont(14)
    Renderer.fontLarge = love.graphics.newFont(24)
    Renderer.fontHuge = love.graphics.newFont(40)
end

function Renderer.getDrawPos(lx, ly)
    local drawX = Constants.BOARD_PADDING + Constants.TILE_GAP + (lx-1) * (Constants.TILE_SIZE + Constants.TILE_GAP)
    local drawY = 150 + Constants.TILE_GAP + (ly-1) * (Constants.TILE_SIZE + Constants.TILE_GAP)
    return drawX, drawY
end

function Renderer.reset()
    Renderer.visualTiles = {}
    flux.clear()
end

function Renderer.addTile(tile)
    local tx, ty = Renderer.getDrawPos(tile.x, tile.y)
    local vt = {
        id = tile.id,
        val = tile.val,
        x = tx,
        y = ty,
        w = Constants.TILE_SIZE,
        h = Constants.TILE_SIZE,
        scale = 0, -- Pop in effect
        opacity = 1
    }
    table.insert(Renderer.visualTiles, vt)
    
    -- Pop animation
    flux.to(vt, 0.2, { scale = 1 })
end

Renderer.shake = 0

function Renderer.addShake(amount)
    Renderer.shake = Renderer.shake + amount
end

function Renderer.onMove(moves)
    -- Handle moves and merges
    local merged = false
    for _, move in ipairs(moves) do
        if move.type == "move" then
            -- Find the visual tile
            local vt = Renderer.findVisualTile(move.tile.id)
            if vt then
                local targetX, targetY = Renderer.getDrawPos(move.toX, move.toY)
                flux.to(vt, 0.15, { x = targetX, y = targetY })
            end
            
        elseif move.type == "merge" then
            merged = true
            -- 1. Animate Source sliding to Target
             local vSource = Renderer.findVisualTile(move.source.id)
             local vTarget = Renderer.findVisualTile(move.target.id)
             local destX, destY = Renderer.getDrawPos(move.tile.x, move.tile.y)
             
             if vSource then
                 local t = flux.to(vSource, 0.15, { x = destX, y = destY })
                 t.onComplete = function() vSource.isDead = true end
             end
             
             if vTarget then
                 -- Target stays put but dies after merge
                 vTarget.isDead = true
                 local t = flux.to(vTarget, 0.15, { x = destX, y = destY }) -- Ensure alignment
                 t.onComplete = function() vTarget.isDead = true end
             end
             
             -- 2. Create the new Merged Tile
             local vNew = {
                id = move.tile.id,
                val = move.tile.val,
                x = destX,
                y = destY,
                w = Constants.TILE_SIZE,
                h = Constants.TILE_SIZE,
                scale = 0, 
                opacity = 1
             }
             
             table.insert(Renderer.visualTiles, vNew)
             
             -- Hack: Tween a dummy value for delay
             local dummy = {v=0}
             local t = flux.to(dummy, 0.15, {v=1})
             t.onComplete = function()
                 local t2 = flux.to(vNew, 0.15, { scale = 1.1 })
                 t2.onComplete = function()
                     flux.to(vNew, 0.1, { scale = 1 })
                 end
             end
        end
    end
    
    if merged then
        Renderer.addShake(5)
    end
end

function Renderer.findVisualTile(id)
    for _, vt in ipairs(Renderer.visualTiles) do
        if vt.id == id then return vt end
    end
    return nil
end

function Renderer.update(dt)
    flux.update(dt)
    
    -- Cleanup dead tiles
    for i = #Renderer.visualTiles, 1, -1 do
        if Renderer.visualTiles[i].isDead then
            table.remove(Renderer.visualTiles, i)
        end
    end
    
    -- Shake Decay
    if Renderer.shake > 0 then
        Renderer.shake = Renderer.shake - 60 * dt
        if Renderer.shake < 0 then Renderer.shake = 0 end
    end
end

function Renderer.draw(score, state, bestScore)
    love.graphics.push()
    
    if Renderer.shake > 0 then
        local dx = math.random() * Renderer.shake - Renderer.shake/2
        local dy = math.random() * Renderer.shake - Renderer.shake/2
        love.graphics.translate(dx, dy)
    end

    -- Background
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- HUD
    love.graphics.setColor(Constants.COLORS.TEXT)
    love.graphics.setFont(Renderer.fontHuge)
    love.graphics.print("NVIDIA 2048", 20, 20)
    
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.print("Score: " .. score, 20, 80)
    love.graphics.print("Best: " .. (bestScore or 0), 220, 80)
    
    -- Board Background
    local startX = 20
    local startY = 150
    local totalSize = (Constants.TILE_SIZE + Constants.TILE_GAP) * 4 + Constants.TILE_GAP
    
    love.graphics.setColor(Constants.COLORS.BOARD)
    love.graphics.rectangle("fill", startX, startY, totalSize, totalSize, 10, 10)
    
    -- Draw Empty Slots
    for y=1,4 do
        for x=1,4 do
             local dx, dy = Renderer.getDrawPos(x, y)
             love.graphics.setColor(0.2, 0.2, 0.22)
             love.graphics.rectangle("fill", dx, dy, Constants.TILE_SIZE, Constants.TILE_SIZE, 5, 5)
        end
    end
    
    -- Draw Visual Tiles
    for _, vt in ipairs(Renderer.visualTiles) do
         local tier = Constants.TIERS[vt.val]
         local color = tier and tier.color or {1,1,1}
         
         love.graphics.setColor(color[1], color[2], color[3], vt.opacity)
         
         -- Draw centered with scale
         local size = Constants.TILE_SIZE * vt.scale
         local offset = (Constants.TILE_SIZE - size) / 2
         
         love.graphics.rectangle("fill", vt.x + offset, vt.y + offset, size, size, 5, 5)
         
         -- Text
         if tier then
            love.graphics.setColor(1, 1, 1, vt.opacity)
            local txt = tier.name
             -- Dynamic font sizing
            local font = Renderer.fontLarge
            if string.len(txt) > 8 then font = Renderer.fontSmall end
            love.graphics.setFont(font)
            
            local w = font:getWidth(txt)
            local h = font:getHeight()
            
            -- Center text in the zoomed rect
            love.graphics.print(txt, 
                vt.x + offset + size/2 - w/2, 
                vt.y + offset + size/2 - h/2)
         end
    end
    
    if state == "gameover" then
        -- Draw over shake? Or with shake? 
        -- Generally ui over shake
        love.graphics.pop()
        
         love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(Renderer.fontHuge)
        love.graphics.printf("SYSTEM CRASHED", 0, 300, love.graphics.getWidth(), "center")
        love.graphics.setFont(Renderer.fontLarge)
        love.graphics.printf("Click to Reboot", 0, 360, love.graphics.getWidth(), "center")
        return -- already popped
    else
        love.graphics.pop()
    end
end

return Renderer
