local Constants = require("src.constants")
local flux = require("src.lib.flux")

local Renderer = {}

-- Visual state
Renderer.visualTiles = {} -- List of {id, val, x, y, opacity, scale, isDead, training, overtrained}
Renderer.particles = {} -- Particle effects
Renderer.sliConnections = {} -- SLI bridge visual connections
Renderer.floatingTexts = {} -- Score popups {text, x, y, vx, vy, life, color, scale}
Renderer.shake = 0
Renderer.shakeMultiplier = 1.0 -- Shake intensity multiplier (0.0 - 1.0+)
Renderer.particlesEnabled = true -- Visual effects toggle

-- Fonts
Renderer.fontSmall = nil
Renderer.fontLarge = nil
Renderer.fontHuge = nil
Renderer.fontTiny = nil

-- UI elements
Renderer.heatMeterAlpha = 0
Renderer.dlssPromptAlpha = 0

function Renderer.load()
    Renderer.fontTiny = love.graphics.newFont(12)
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
    Renderer.particles = {}
    Renderer.sliConnections = {}
    Renderer.floatingTexts = {}
    Renderer.shake = 0
    flux.clear()
end

function Renderer.addTile(tile, meta)
    local tx, ty = Renderer.getDrawPos(tile.x, tile.y)
    local vt = {
        id = tile.id,
        val = tile.val,
        x = tx,
        y = ty,
        w = Constants.TILE_SIZE,
        h = Constants.TILE_SIZE,
        scale = 0, -- Pop in effect
        opacity = 1,
        training = meta and meta.training or 0,
        overtrained = meta and meta.overtrained or false,
        overtrainedMoves = meta and meta.overtrainedMoves or 0,
        isLQ = meta and meta.isLQ or false,
        glowPhase = 0
    }
    table.insert(Renderer.visualTiles, vt)

    -- Pop animation
    flux.to(vt, 0.2, { scale = 1 })
end

function Renderer.addShake(amount)
    Renderer.shake = Renderer.shake + amount * Renderer.shakeMultiplier
end

function Renderer.onMove(moves)
    -- Handle moves and merges
    local maxMergeVal = 0
    for _, move in ipairs(moves) do
        if move.type == "move" then
            -- Find the visual tile
            local vt = Renderer.findVisualTile(move.tile.id)
            if vt then
                local targetX, targetY = Renderer.getDrawPos(move.toX, move.toY)
                flux.to(vt, 0.15, { x = targetX, y = targetY })
            end

        elseif move.type == "merge" then
            if move.tile.val > maxMergeVal then maxMergeVal = move.tile.val end
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
                 local t = flux.to(vTarget, 0.15, { x = destX, y = destY })
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
                opacity = 1,
                training = 0,
                overtrained = false,
                isLQ = false,
                glowPhase = 0
             }

             table.insert(Renderer.visualTiles, vNew)

             -- Delayed pop animation
             local dummy = {v=0}
             local t = flux.to(dummy, 0.15, {v=1})
             t.onComplete = function()
                 if move.tile.val >= 64 then
                     -- Level 2+: Pop animation
                     local t2 = flux.to(vNew, 0.15, { scale = 1.1 })
                     t2.onComplete = function()
                         flux.to(vNew, 0.1, { scale = 1 })
                     end
                 else
                     -- Level 1: No visual effect (Instant appearance)
                     vNew.scale = 1
                 end
             end
        end
    end

    if maxMergeVal > 0 then
        -- Dynamic Shake (Gameplay Feedback Levels)
        local shake = 0
        if maxMergeVal < 64 then
            shake = 0       -- Level 1: No shake (Low tier)
        elseif maxMergeVal < 1024 then
            shake = 2       -- Level 2: Tiny shake (Mid tier)
        else
            shake = 6       -- Level 3: Normal shake (High tier)
        end
        
        if shake > 0 then
            Renderer.addShake(shake)
        end
    end
end

function Renderer.findVisualTile(id)
    for _, vt in ipairs(Renderer.visualTiles) do
        if vt.id == id then return vt end
    end
    return nil
end

function Renderer.updateTileMeta(id, meta, newVal)
    local vt = Renderer.findVisualTile(id)
    if vt then
        if meta then
            vt.training = meta.training or 0
            vt.overtrained = meta.overtrained or false
            vt.overtrainedMoves = meta.overtrainedMoves or 0
            vt.isLQ = meta.isLQ or false
        end
        if newVal then
            vt.val = newVal
        end
    end
end

-- Particle system for effects
function Renderer.addTensorCascadeEffect(x, y)
    if not Renderer.particlesEnabled then return end

    -- Create green energy pulse particles
    local drawX, drawY = Renderer.getDrawPos(x, y)
    local centerX = drawX + Constants.TILE_SIZE / 2
    local centerY = drawY + Constants.TILE_SIZE / 2

    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local particle = {
            x = centerX,
            y = centerY,
            vx = math.cos(angle) * 150,
            vy = math.sin(angle) * 150,
            life = 1.0,
            maxLife = 1.0,
            size = 8,
            color = {0.2, 0.9, 0.3, 1}
        }
        table.insert(Renderer.particles, particle)
    end
end

function Renderer.addDLSSEffect(x, y)
    if not Renderer.particlesEnabled then return end

    -- Rainbow shimmer effect for AI upscaling
    local drawX, drawY = Renderer.getDrawPos(x, y)
    local centerX = drawX + Constants.TILE_SIZE / 2
    local centerY = drawY + Constants.TILE_SIZE / 2

    for i = 1, 20 do
        local angle = math.random() * math.pi * 2
        local dist = math.random() * 40
        local particle = {
            x = centerX + math.cos(angle) * dist,
            y = centerY + math.sin(angle) * dist,
            vx = math.cos(angle) * 50,
            vy = math.sin(angle) * 50,
            life = 0.8,
            maxLife = 0.8,
            size = 6,
            color = {math.random(), math.random(), math.random(), 1}
        }
        table.insert(Renderer.particles, particle)
    end
end

-- Add floating score text popup
function Renderer.addScorePopup(x, y, score, bonusType)
    local drawX, drawY = Renderer.getDrawPos(x, y)
    local centerX = drawX + Constants.TILE_SIZE / 2
    local centerY = drawY + Constants.TILE_SIZE / 2

    local color = {1, 1, 1, 1} -- Default white
    local prefix = "+"
    local scale = 1.0

    if bonusType == "training" then
        color = {0, 1, 1, 1} -- Cyan for training bonus
        prefix = "+T:"
        scale = 1.2
    elseif bonusType == "sli" then
        color = {0.3, 0.8, 1, 1} -- Blue for SLI bonus
        prefix = "+SLI:"
        scale = 1.3
    elseif bonusType == "tensor" then
        color = {0.2, 0.9, 0.3, 1} -- Green for tensor cascade
        prefix = "+TC:"
        scale = 1.2
    elseif bonusType == "dlss" then
        color = {1, 0.5, 1, 1} -- Magenta for DLSS
        prefix = "+DLSS:"
        scale = 1.4
    elseif bonusType == "merge" then
        color = {1, 1, 0.5, 1} -- Yellow for normal merge
        prefix = "+"
        scale = 1.0
    end

    table.insert(Renderer.floatingTexts, {
        text = prefix .. score,
        x = centerX,
        y = centerY - 20,
        vx = 0,
        vy = -50, -- Float upward
        life = 1.5,
        maxLife = 1.5,
        color = color,
        scale = scale
    })
end

function Renderer.addMergeParticles(x, y, color)
    if not Renderer.particlesEnabled then return end

    -- Burst effect on merge
    local drawX, drawY = Renderer.getDrawPos(x, y)
    local centerX = drawX + Constants.TILE_SIZE / 2
    local centerY = drawY + Constants.TILE_SIZE / 2

    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local particle = {
            x = centerX,
            y = centerY,
            vx = math.cos(angle) * 100,
            vy = math.sin(angle) * 100,
            life = 0.6,
            maxLife = 0.6,
            size = 5,
            color = {color[1], color[2], color[3], 1}
        }
        table.insert(Renderer.particles, particle)
    end
end

function Renderer.setSLIConnections(connections)
    Renderer.sliConnections = connections or {}
end

function Renderer.update(dt)
    flux.update(dt)

    -- Update particles
    for i = #Renderer.particles, 1, -1 do
        local p = Renderer.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        
        if p.drag then
            p.vx = p.vx * (1 - p.drag * dt)
            p.vy = p.vy * (1 - p.drag * dt)
        end
        
        p.color[4] = p.life / p.maxLife

        if p.life <= 0 then
            table.remove(Renderer.particles, i)
        end
    end

    -- Update floating texts
    for i = #Renderer.floatingTexts, 1, -1 do
        local ft = Renderer.floatingTexts[i]
        ft.x = ft.x + ft.vx * dt
        ft.y = ft.y + ft.vy * dt
        ft.life = ft.life - dt
        ft.color[4] = ft.life / ft.maxLife

        if ft.life <= 0 then
            table.remove(Renderer.floatingTexts, i)
        end
    end

    -- Update tile glow phases for training effect
    for _, vt in ipairs(Renderer.visualTiles) do
        vt.glowPhase = (vt.glowPhase + dt * 2) % (math.pi * 2)
    end

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

function Renderer.draw(score, state, bestScore, gameState)
    love.graphics.push()

    if Renderer.shake > 0 then
        local dx = math.random() * Renderer.shake - Renderer.shake/2
        local dy = math.random() * Renderer.shake - Renderer.shake/2
        love.graphics.translate(dx, dy)
    end

    -- Background
    love.graphics.clear(Constants.COLORS.BACKGROUND)

    -- HUD Header
    love.graphics.setColor(Constants.COLORS.TEXT)
    love.graphics.setFont(Renderer.fontHuge)
    love.graphics.print("NVIDIA 2048", 20, 20)

    -- Score and stats
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.print("Score: " .. score, 20, 80)
    love.graphics.print("Best: " .. (bestScore or 0), 220, 80)

    -- Heat meter (if gameState provided)
    if gameState and gameState.heatLevel then
        Renderer.drawHeatMeter(420, 80, gameState.heatLevel)
    end

    -- DLSS charges indicator (if gameState provided)
    if gameState and gameState.dlssCharges ~= nil then
        Renderer.drawDLSSCharges(20, 120, gameState.dlssCharges)
    end

    -- DLSS selection mode hint
    if gameState and gameState.selectedTileForDLSS then
        love.graphics.setColor(1, 1, 0, 0.8 + math.sin(love.timer.getTime() * 5) * 0.2)
        love.graphics.setFont(Renderer.fontLarge)
        love.graphics.print("DLSS MODE: Arrow keys to select, SPACE to upgrade, ESC to cancel", 20, 650)
    end

    -- Board Background
    local startX = 20
    local startY = 150
    local totalSize = (Constants.TILE_SIZE + Constants.TILE_GAP) * 4 + Constants.TILE_GAP

    love.graphics.setColor(Constants.COLORS.BOARD)
    love.graphics.rectangle("fill", startX, startY, totalSize, totalSize, 10, 10)

    -- Heat overlay effect
    if gameState and gameState.heatLevel and gameState.heatLevel > 50 then
        local heatAlpha = ((gameState.heatLevel - 50) / 50) * 0.3
        love.graphics.setColor(1, 0.3, 0, heatAlpha)
        love.graphics.rectangle("fill", startX, startY, totalSize, totalSize, 10, 10)
    end

    -- Draw Empty Slots
    for y=1,4 do
        for x=1,4 do
             local dx, dy = Renderer.getDrawPos(x, y)
             love.graphics.setColor(0.2, 0.2, 0.22)
             love.graphics.rectangle("fill", dx, dy, Constants.TILE_SIZE, Constants.TILE_SIZE, 5, 5)

             -- DLSS selection highlight
             if gameState and gameState.selectedTileForDLSS and
                gameState.selectedTileForDLSS.x == x and gameState.selectedTileForDLSS.y == y then
                 -- Animated pulsing yellow border
                 local pulseAlpha = 0.6 + math.sin(love.timer.getTime() * 8) * 0.4
                 love.graphics.setColor(1, 1, 0, pulseAlpha)
                 love.graphics.setLineWidth(5)
                 love.graphics.rectangle("line", dx - 3, dy - 3, Constants.TILE_SIZE + 6, Constants.TILE_SIZE + 6, 5, 5)

                 -- Corner markers for extra visibility
                 love.graphics.setLineWidth(3)
                 local cornerSize = 15
                 -- Top-left
                 love.graphics.line(dx - 3, dy - 3, dx - 3 + cornerSize, dy - 3)
                 love.graphics.line(dx - 3, dy - 3, dx - 3, dy - 3 + cornerSize)
                 -- Top-right
                 love.graphics.line(dx + Constants.TILE_SIZE + 3, dy - 3, dx + Constants.TILE_SIZE + 3 - cornerSize, dy - 3)
                 love.graphics.line(dx + Constants.TILE_SIZE + 3, dy - 3, dx + Constants.TILE_SIZE + 3, dy - 3 + cornerSize)
                 -- Bottom-left
                 love.graphics.line(dx - 3, dy + Constants.TILE_SIZE + 3, dx - 3 + cornerSize, dy + Constants.TILE_SIZE + 3)
                 love.graphics.line(dx - 3, dy + Constants.TILE_SIZE + 3, dx - 3, dy + Constants.TILE_SIZE + 3 - cornerSize)
                 -- Bottom-right
                 love.graphics.line(dx + Constants.TILE_SIZE + 3, dy + Constants.TILE_SIZE + 3, dx + Constants.TILE_SIZE + 3 - cornerSize, dy + Constants.TILE_SIZE + 3)
                 love.graphics.line(dx + Constants.TILE_SIZE + 3, dy + Constants.TILE_SIZE + 3, dx + Constants.TILE_SIZE + 3, dy + Constants.TILE_SIZE + 3 - cornerSize)
             end
        end
    end

    -- Draw SLI bridges (connection lines between tiles)
    Renderer.drawSLIBridges()

    -- Draw Visual Tiles
    for _, vt in ipairs(Renderer.visualTiles) do
         local tier = Constants.TIERS[vt.val]
         local color = tier and tier.color or {1,1,1}

         love.graphics.setColor(color[1], color[2], color[3], vt.opacity)

         -- Draw centered with scale
         local size = Constants.TILE_SIZE * vt.scale
         local offset = (Constants.TILE_SIZE - size) / 2

         love.graphics.rectangle("fill", vt.x + offset, vt.y + offset, size, size, 5, 5)

         -- Training glow border
         if vt.training >= 10 and not vt.overtrained then
             local glowIntensity = 0.5 + math.sin(vt.glowPhase) * 0.3
             love.graphics.setColor(0, 0.7, 1, glowIntensity * vt.opacity)
             love.graphics.setLineWidth(3)
             love.graphics.rectangle("line", vt.x + offset, vt.y + offset, size, size, 5, 5)
         end

         -- Overtrained warning border with thicker, more visible effect
         if vt.overtrained then
             local pulseIntensity = 0.8 + math.sin(vt.glowPhase * 4) * 0.2
             -- Outer red glow
             love.graphics.setColor(1, 0, 0, pulseIntensity * 0.6 * vt.opacity)
             love.graphics.setLineWidth(6)
             love.graphics.rectangle("line", vt.x + offset - 2, vt.y + offset - 2, size + 4, size + 4, 5, 5)
             -- Inner warning border
             love.graphics.setColor(1, 0.2, 0, pulseIntensity * vt.opacity)
             love.graphics.setLineWidth(3)
             love.graphics.rectangle("line", vt.x + offset, vt.y + offset, size, size, 5, 5)
         end

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

         -- LQ indicator
         if vt.isLQ then
             love.graphics.setColor(1, 1, 0, vt.opacity)
             love.graphics.setFont(Renderer.fontTiny)
             love.graphics.print("LQ", vt.x + offset + 5, vt.y + offset + 5)
         end

         -- Training level indicator
         if vt.training >= 10 and vt.training < 20 then
             love.graphics.setColor(0, 1, 1, vt.opacity * 0.8)
             love.graphics.setFont(Renderer.fontTiny)
             love.graphics.print("T:" .. vt.training, vt.x + offset + size - 28, vt.y + offset + 5)
         end

         -- Overtrained warning with countdown - larger and more visible
         if vt.overtrained and vt.overtrainedMoves then
             local movesLeft = 12 - vt.overtrainedMoves  -- Updated to match new deadline
             love.graphics.setColor(1, 1, 1, vt.opacity)
             love.graphics.setFont(Renderer.fontSmall)
             local text = "!" .. movesLeft
             local tw = Renderer.fontSmall:getWidth(text)
             love.graphics.print(text, vt.x + offset + size - tw - 5, vt.y + offset + 5)
         end
    end

    -- Draw particles
    for _, p in ipairs(Renderer.particles) do
        love.graphics.setColor(p.color)
        if p.type == "ring" then
             local progress = 1 - (p.life / p.maxLife)
             local r = p.radius + (p.maxRadius - p.radius) * progress
             love.graphics.setLineWidth(p.width * (1-progress))
             love.graphics.circle("line", p.x, p.y, r)
        elseif p.type == "flash" then
             local progress = 1 - (p.life / p.maxLife)
             local r = p.maxRadius * progress
             love.graphics.circle("fill", p.x, p.y, r)
        else
            love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife))
        end
    end

    -- Draw floating score texts
    for _, ft in ipairs(Renderer.floatingTexts) do
        love.graphics.setColor(ft.color)
        love.graphics.setFont(Renderer.fontLarge)
        local textWidth = Renderer.fontLarge:getWidth(ft.text)
        love.graphics.push()
        love.graphics.translate(ft.x, ft.y)
        love.graphics.scale(ft.scale, ft.scale)
        love.graphics.print(ft.text, -textWidth / 2, 0)
        love.graphics.pop()
    end

    -- Hints and tips
    if gameState and gameState.hasLQTile and gameState.dlssCharges > 0 then
        love.graphics.setColor(1, 1, 0, 0.5 + math.sin(love.timer.getTime() * 3) * 0.3)
        love.graphics.setFont(Renderer.fontSmall)
        love.graphics.print("Press SPACE to upscale LQ tile!", 20, 650)
    end

    if state == "gameover" then
        love.graphics.pop()

         love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0, 0)
        love.graphics.setFont(Renderer.fontHuge)

        local gameOverText = "SYSTEM CRASHED"
        if gameState and gameState.gameOverReason == "overtrained" then
            gameOverText = "NEURAL NETWORK COLLAPSED"
        end

        love.graphics.printf(gameOverText, 0, 250, love.graphics.getWidth(), "center")
        love.graphics.setFont(Renderer.fontLarge)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Click to Reboot", 0, 380, love.graphics.getWidth(), "center")
        return
    else
        love.graphics.pop()
    end
end

function Renderer.drawHeatMeter(x, y, heatLevel)
    local width = 150
    local height = 20

    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)

    -- Heat fill
    local fillWidth = (heatLevel / 100) * width
    local heatColor = {0.2, 0.8, 0.3}

    if heatLevel > 75 then
        heatColor = {1, 0.2, 0.2}
    elseif heatLevel > 50 then
        heatColor = {1, 0.6, 0}
    end

    love.graphics.setColor(heatColor)
    love.graphics.rectangle("fill", x, y, fillWidth, height, 3, 3)

    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 3, 3)

    -- Label
    love.graphics.setColor(Constants.COLORS.TEXT)
    love.graphics.setFont(Renderer.fontSmall)
    love.graphics.print("Heat: " .. math.floor(heatLevel) .. "%", x + width + 10, y + 2)
end

function Renderer.drawDLSSCharges(x, y, charges)
    love.graphics.setColor(Constants.COLORS.TEXT)
    love.graphics.setFont(Renderer.fontSmall)
    love.graphics.print("DLSS: ", x, y)

    local offsetX = x + 50
    for i = 1, 3 do
        local cx = offsetX + (i-1) * 25
        local cy = y + 8

        if i <= charges then
            love.graphics.setColor(0.3, 0.8, 1)
        else
            love.graphics.setColor(0.2, 0.2, 0.25)
        end

        -- Draw lightning bolt shape
        love.graphics.circle("fill", cx, cy, 8)

        -- Draw simple lightning bolt on top
        love.graphics.setColor(1, 1, 0.2)
        love.graphics.polygon("fill",
            cx - 2, cy - 6,  -- top
            cx + 1, cy - 1,  -- middle right
            cx - 1, cy - 1,  -- middle left
            cx + 2, cy + 6,  -- bottom
            cx, cy + 1,      -- middle bottom
            cx - 1, cy + 1   -- middle left bottom
        )
    end
end

function Renderer.drawSLIBridges()
    local time = love.timer.getTime()
    
    for _, conn in ipairs(Renderer.sliConnections) do
        -- Draw connection lines between bridged tiles
        local vt1 = Renderer.findVisualTile(conn.tile1)
        local vt2 = Renderer.findVisualTile(conn.tile2)

        if vt1 and vt2 then
            local x1 = vt1.x + Constants.TILE_SIZE / 2
            local y1 = vt1.y + Constants.TILE_SIZE / 2
            local x2 = vt2.x + Constants.TILE_SIZE / 2
            local y2 = vt2.y + Constants.TILE_SIZE / 2

            -- NVLink Beam Effect
            -- 1. Outer Glow (Pulsing)
            local pulse = 0.5 + math.sin(time * 5) * 0.3
            love.graphics.setColor(0, 1, 0.5, pulse * 0.4)
            love.graphics.setLineWidth(12)
            love.graphics.line(x1, y1, x2, y2)
            
            -- 2. Inner Core (Bright Green/Cyan)
            love.graphics.setColor(0.2, 1, 0.8, 0.9)
            love.graphics.setLineWidth(4)
            love.graphics.line(x1, y1, x2, y2)
            
            -- 3. Data Flow Particles
            local dist = math.sqrt((x2-x1)^2 + (y2-y1)^2)
            local angle = math.atan2(y2-y1, x2-x1)
            local particleCount = math.floor(dist / 20)
            
            love.graphics.setColor(1, 1, 1, 0.8)
            for i = 0, particleCount do
                local offset = (time * 100 + i * (dist/particleCount)) % dist
                local px = x1 + math.cos(angle) * offset
                local py = y1 + math.sin(angle) * offset
                love.graphics.circle("fill", px, py, 2)
            end
            
            -- 4. Connector Nodes at endpoints
            love.graphics.setColor(0, 1, 0.5, 1)
            love.graphics.circle("fill", x1, y1, 6)
            love.graphics.circle("fill", x2, y2, 6)
        end
    end
end

function Renderer.addSLIMergeEffect(x, y)
    if not Renderer.particlesEnabled then return end
    
    -- Massive NVLink Surge Effect
    local drawX, drawY = Renderer.getDrawPos(x, y)
    local centerX = drawX + Constants.TILE_SIZE / 2
    local centerY = drawY + Constants.TILE_SIZE / 2
    
    -- 1. Expanding Shockwave Ring
    local shockwave = {
        x = centerX, y = centerY,
        radius = 10, maxRadius = 300,
        width = 20,
        life = 0.5, maxLife = 0.5,
        color = {0, 1, 0.8, 1},
        type = "ring",
        vx = 0, vy = 0
    }
    table.insert(Renderer.particles, shockwave)
    
    -- 2. Intense Flash
    local flash = {
        x = centerX, y = centerY,
        radius = 0, maxRadius = 150, -- Solid circle flash
        life = 0.2, maxLife = 0.2,
        color = {0.8, 1, 0.9, 0.8},
        type = "flash",
        vx = 0, vy = 0
    }
    table.insert(Renderer.particles, flash)
    
    -- 3. High Velocity Data Debris
    for i = 1, 30 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(100, 400)
        local p = {
            x = centerX,
            y = centerY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 1.0,
            maxLife = 1.0,
            size = math.random(4, 10),
            color = {0, 1, math.random(), 1},
            drag = 2
        }
        table.insert(Renderer.particles, p)
    end
end


function Renderer.drawSplash()
    -- Background with particles (dark overlay)
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw particles in background
    for _, p in ipairs(Renderer.particles) do
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife))
    end
    
    -- Semi-transparent overlay to make text pop
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local cx = love.graphics.getWidth() / 2
    local cy = love.graphics.getHeight() / 2
    
    -- Main Title
    love.graphics.setColor(Constants.COLORS.TEXT)
    love.graphics.setFont(Renderer.fontHuge)
    local title = "NVIDIA 2048"
    love.graphics.printf(title, 0, 80, love.graphics.getWidth(), "center")
    
    -- Subtitle
    love.graphics.setColor(0.3, 0.9, 0.4) -- NVIDIA Greenish
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.printf("Neural Edition", 0, 130, love.graphics.getWidth(), "center")

    -- System Manual / How to Play
    local startY = 200
    local lineHeight = 40
    
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.printf("SYSTEM MANUAL", 0, startY, love.graphics.getWidth(), "center")
    
    love.graphics.setFont(Renderer.fontSmall)
    
    local manualItems = {
        { title = "THERMAL MANAGEMENT", text = "High-end GPUs generate heat. Avoid hitting 100%!", color = {1, 0.4, 0.4} },
        { title = "DLSS UPSCALING", text = "Press SPACE to double any tile's value (Requires Charge)", color = {1, 0.5, 1} },
        { title = "SLI LINK", text = "Align identical GPUs for massive score multipliers", color = {0.3, 0.8, 1} },
        { title = "NEURAL TRAINING", text = "Old tiles get 'Overtrained' and crash. Merge them fast!", color = {0, 1, 1} }
    }
    
    for i, item in ipairs(manualItems) do
        local y = startY + 50 + (i-1) * 60
        
        -- Icon/Bullet
        love.graphics.setColor(item.color)
        love.graphics.circle("fill", cx - 200, y + 10, 5)
        
        -- Title
        love.graphics.print(item.title, cx - 180, y)
        
        -- Text
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(item.text, cx - 180, y + 20)
    end

    -- Click to Start Prompt
    local pulse = 0.5 + math.abs(math.sin(love.timer.getTime() * 3)) * 0.5
    love.graphics.setColor(0.4, 1, 0.4, pulse)
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.printf("CLICK ANYWHERE TO INITIALIZE SYSTEM...", 0, 550, love.graphics.getWidth(), "center")
    
    -- Version / Footer
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.setFont(Renderer.fontSmall)
    love.graphics.printf("v1.0.0 Stable Diffusion", 0, love.graphics.getHeight() - 30, love.graphics.getWidth(), "center")
end



function Renderer.drawVictory()
    -- Golden Victory Overlay
    love.graphics.clear(0.1, 0.1, 0, 1) -- Dark gold/brown background
    
    -- Draw particles in background
    for _, p in ipairs(Renderer.particles) do
        love.graphics.setColor(p.color)
        love.graphics.circle("fill", p.x, p.y, p.size * (p.life / p.maxLife))
    end
    
    local cx = love.graphics.getWidth() / 2
    local cy = love.graphics.getHeight() / 2
    
    -- Animated Golden Ray/Glow effect (Simple radial lines or just pulsing background)
    local time = love.timer.getTime()
    love.graphics.setColor(1, 0.8, 0, 0.1 + math.sin(time) * 0.05)
    love.graphics.circle("fill", cx, cy, 300)
    
    -- Main Victory Text
    love.graphics.setColor(1, 0.9, 0.2) -- Gold
    love.graphics.setFont(Renderer.fontHuge)
    local title = "JENSEN'S KITCHEN"
    love.graphics.printf(title, 0, 150, love.graphics.getWidth(), "center")
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.printf("ACHIEVEMENT UNLOCKED!", 0, 220, love.graphics.getWidth(), "center")
    
    -- Subtext
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(Renderer.fontSmall)
    love.graphics.printf("You have reached the ultimate hardware frontier.", 0, 280, love.graphics.getWidth(), "center")
    
    -- 2048 Tile Display (Symbolic)
    love.graphics.setColor(1, 0.84, 0)
    love.graphics.rectangle("fill", cx - 50, cy - 20, 100, 100, 10, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Renderer.fontHuge)
    love.graphics.print("CEO", cx - 35, cy + 5)
    
    -- Instructions
    local pulse = 0.5 + math.abs(math.sin(time * 3)) * 0.5
    love.graphics.setColor(0, 1, 0.5, pulse)
    love.graphics.setFont(Renderer.fontLarge)
    love.graphics.printf("Press ENTER to Continue (Endless Mode)", 0, 500, love.graphics.getWidth(), "center")
    
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.setFont(Renderer.fontSmall)
    love.graphics.printf("Press Ctrl+R to Restart", 0, 550, love.graphics.getWidth(), "center")
end

return Renderer
