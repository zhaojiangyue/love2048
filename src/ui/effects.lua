local Constants = require("src.constants")

local Effects = {}

-- ============================================================================
-- PARTICLE SYSTEM
-- ============================================================================

Effects.particles = {}

-- Particle types
Effects.PARTICLE_TYPES = {
    TENSOR_CASCADE = "tensor_cascade",
    DLSS_SHIMMER = "dlss_shimmer",
    MERGE_BURST = "merge_burst",
    HEAT_DISTORTION = "heat_distortion",
    TRAINING_SPARKLE = "training_sparkle"
}

-- Create a particle
function Effects.createParticle(x, y, particleType, data)
    local particle = {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 1.0,
        maxLife = 1.0,
        size = 8,
        color = {1, 1, 1, 1},
        type = particleType,
        phase = 0,
        data = data or {}
    }

    if particleType == Effects.PARTICLE_TYPES.TENSOR_CASCADE then
        -- Green energy pulse particles
        local angle = data.angle or 0
        particle.vx = math.cos(angle) * 150
        particle.vy = math.sin(angle) * 150
        particle.life = 1.0
        particle.maxLife = 1.0
        particle.size = 8
        particle.color = {0.2, 0.9, 0.3, 1}

    elseif particleType == Effects.PARTICLE_TYPES.DLSS_SHIMMER then
        -- Rainbow shimmer particles
        local angle = data.angle or (math.random() * math.pi * 2)
        local dist = data.dist or (math.random() * 40)
        particle.x = x + math.cos(angle) * dist
        particle.y = y + math.sin(angle) * dist
        particle.vx = math.cos(angle) * 50
        particle.vy = math.sin(angle) * 50
        particle.life = 0.8
        particle.maxLife = 0.8
        particle.size = 6
        particle.color = {math.random(), math.random(), math.random(), 1}

    elseif particleType == Effects.PARTICLE_TYPES.MERGE_BURST then
        -- Colored burst particles
        local angle = data.angle or 0
        particle.vx = math.cos(angle) * 100
        particle.vy = math.sin(angle) * 100
        particle.life = 0.6
        particle.maxLife = 0.6
        particle.size = 5
        particle.color = data.color or {1, 1, 1, 1}

    elseif particleType == Effects.PARTICLE_TYPES.HEAT_DISTORTION then
        -- Heat shimmer effect
        particle.vx = (math.random() - 0.5) * 20
        particle.vy = -math.random() * 30 - 20
        particle.life = 1.2
        particle.maxLife = 1.2
        particle.size = 4
        particle.color = {1, 0.3, 0, 0.5}

    elseif particleType == Effects.PARTICLE_TYPES.TRAINING_SPARKLE then
        -- Training glow sparkles
        local angle = math.random() * math.pi * 2
        local dist = math.random() * 30
        particle.x = x + math.cos(angle) * dist
        particle.y = y + math.sin(angle) * dist
        particle.vx = (math.random() - 0.5) * 20
        particle.vy = (math.random() - 0.5) * 20
        particle.life = 0.5
        particle.maxLife = 0.5
        particle.size = 3
        particle.color = {0, 0.7, 1, 1}
    end

    table.insert(Effects.particles, particle)
    return particle
end

-- Update all particles
function Effects.updateParticles(dt)
    for i = #Effects.particles, 1, -1 do
        local p = Effects.particles[i]

        -- Update position
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        -- Update life
        p.life = p.life - dt
        p.phase = p.phase + dt * 5

        -- Fade alpha based on lifetime
        p.color[4] = (p.life / p.maxLife)

        -- Apply gravity to some particle types
        if p.type == Effects.PARTICLE_TYPES.MERGE_BURST or
           p.type == Effects.PARTICLE_TYPES.HEAT_DISTORTION then
            p.vy = p.vy + 50 * dt
        end

        -- Remove dead particles
        if p.life <= 0 then
            table.remove(Effects.particles, i)
        end
    end
end

-- Draw all particles
function Effects.drawParticles()
    for _, p in ipairs(Effects.particles) do
        love.graphics.setColor(p.color)

        local size = p.size * (p.life / p.maxLife)

        if p.type == Effects.PARTICLE_TYPES.TRAINING_SPARKLE then
            -- Sparkle with pulsing
            local pulse = 1 + math.sin(p.phase * 3) * 0.3
            love.graphics.circle("fill", p.x, p.y, size * pulse)
        else
            -- Standard circle
            love.graphics.circle("fill", p.x, p.y, size)
        end
    end
end

-- Clear all particles
function Effects.clearParticles()
    Effects.particles = {}
end

-- ============================================================================
-- PRESET EFFECTS
-- ============================================================================

-- Tensor cascade burst effect
function Effects.tensorCascade(x, y)
    local particleCount = Constants.EFFECTS.TENSOR_CASCADE_PARTICLES or 12

    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2
        Effects.createParticle(x, y, Effects.PARTICLE_TYPES.TENSOR_CASCADE, {
            angle = angle
        })
    end
end

-- DLSS shimmer effect
function Effects.dlssShimmer(x, y)
    local particleCount = Constants.EFFECTS.DLSS_PARTICLES or 20

    for i = 1, particleCount do
        Effects.createParticle(x, y, Effects.PARTICLE_TYPES.DLSS_SHIMMER, {})
    end
end

-- Merge burst effect
function Effects.mergeBurst(x, y, color)
    local particleCount = Constants.EFFECTS.MERGE_PARTICLES or 8
    color = color or {1, 1, 1}

    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2
        Effects.createParticle(x, y, Effects.PARTICLE_TYPES.MERGE_BURST, {
            angle = angle,
            color = {color[1], color[2], color[3], 1}
        })
    end
end

-- Heat distortion effect (spawn continuously)
function Effects.heatDistortion(x, y, intensity)
    -- Spawn rate based on intensity (0-1)
    if math.random() < intensity * 0.1 then
        Effects.createParticle(x, y, Effects.PARTICLE_TYPES.HEAT_DISTORTION, {})
    end
end

-- Training sparkle effect
function Effects.trainingSparkle(x, y)
    if math.random() < 0.3 then
        Effects.createParticle(x, y, Effects.PARTICLE_TYPES.TRAINING_SPARKLE, {})
    end
end

-- ============================================================================
-- SCREEN EFFECTS
-- ============================================================================

Effects.screenShake = 0
Effects.heatOverlayAlpha = 0

-- Add screen shake
function Effects.addScreenShake(amount)
    Effects.screenShake = math.min(Effects.screenShake + amount, 20)
end

-- Update screen shake
function Effects.updateScreenShake(dt)
    if Effects.screenShake > 0 then
        Effects.screenShake = Effects.screenShake - 60 * dt
        if Effects.screenShake < 0 then
            Effects.screenShake = 0
        end
    end
end

-- Get screen shake offset
function Effects.getScreenShakeOffset()
    if Effects.screenShake > 0 then
        local dx = (math.random() - 0.5) * Effects.screenShake
        local dy = (math.random() - 0.5) * Effects.screenShake
        return dx, dy
    end
    return 0, 0
end

-- Update heat overlay based on heat level
function Effects.updateHeatOverlay(heatLevel, dt)
    local targetAlpha = 0

    if heatLevel >= 90 then
        targetAlpha = 0.3
    elseif heatLevel >= 75 then
        targetAlpha = 0.2
    elseif heatLevel >= 50 then
        targetAlpha = 0.1
    end

    -- Smooth transition
    if Effects.heatOverlayAlpha < targetAlpha then
        Effects.heatOverlayAlpha = math.min(Effects.heatOverlayAlpha + dt * 0.5, targetAlpha)
    elseif Effects.heatOverlayAlpha > targetAlpha then
        Effects.heatOverlayAlpha = math.max(Effects.heatOverlayAlpha - dt * 0.5, targetAlpha)
    end
end

-- Draw heat overlay
function Effects.drawHeatOverlay(x, y, width, height)
    if Effects.heatOverlayAlpha > 0 then
        -- Pulsing heat effect
        local pulse = math.sin(love.timer.getTime() * 2) * 0.1
        local alpha = Effects.heatOverlayAlpha + pulse

        love.graphics.setColor(1, 0.3, 0, alpha)
        love.graphics.rectangle("fill", x, y, width, height, 10, 10)

        -- Add heat shimmer particles at edges
        if math.random() < 0.5 then
            local edgeX = x + math.random() * width
            local edgeY = y + math.random() * height
            Effects.heatDistortion(edgeX, edgeY, alpha * 2)
        end
    end
end

-- ============================================================================
-- ANIMATIONS & TWEENS
-- ============================================================================

Effects.animations = {}

-- Create a simple animation
function Effects.createAnimation(duration, fromValue, toValue, onUpdate, onComplete)
    local anim = {
        time = 0,
        duration = duration,
        from = fromValue,
        to = toValue,
        onUpdate = onUpdate,
        onComplete = onComplete,
        finished = false
    }

    table.insert(Effects.animations, anim)
    return anim
end

-- Update all animations
function Effects.updateAnimations(dt)
    for i = #Effects.animations, 1, -1 do
        local anim = Effects.animations[i]

        if not anim.finished then
            anim.time = anim.time + dt

            local progress = math.min(anim.time / anim.duration, 1)
            local value = anim.from + (anim.to - anim.from) * progress

            if anim.onUpdate then
                anim.onUpdate(value, progress)
            end

            if progress >= 1 then
                anim.finished = true
                if anim.onComplete then
                    anim.onComplete()
                end
                table.remove(Effects.animations, i)
            end
        end
    end
end

-- ============================================================================
-- TILE EFFECTS
-- ============================================================================

-- Draw glow effect around a rectangle
function Effects.drawGlow(x, y, width, height, color, intensity, phase)
    phase = phase or 0
    local glowIntensity = intensity * (0.5 + math.sin(phase) * 0.3)

    love.graphics.setColor(color[1], color[2], color[3], glowIntensity)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
end

-- Draw pulsing border
function Effects.drawPulsingBorder(x, y, width, height, color, speed, phase)
    phase = phase or 0
    local pulseIntensity = 0.7 + math.sin(phase * speed) * 0.3

    love.graphics.setColor(color[1], color[2], color[3], pulseIntensity)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", x, y, width, height, 5, 5)
end

-- Draw connection line between two points
function Effects.drawConnection(x1, y1, x2, y2, color, alpha, thickness)
    thickness = thickness or 4

    -- Outer glow
    love.graphics.setColor(color[1], color[2], color[3], alpha * 0.5)
    love.graphics.setLineWidth(thickness + 2)
    love.graphics.line(x1, y1, x2, y2)

    -- Inner bright line
    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.setLineWidth(thickness)
    love.graphics.line(x1, y1, x2, y2)
end

-- ============================================================================
-- UPDATE & DRAW
-- ============================================================================

-- Main update function
function Effects.update(dt)
    Effects.updateParticles(dt)
    Effects.updateScreenShake(dt)
    Effects.updateAnimations(dt)
end

-- Main draw function
function Effects.draw()
    Effects.drawParticles()
end

-- Reset all effects
function Effects.reset()
    Effects.clearParticles()
    Effects.screenShake = 0
    Effects.heatOverlayAlpha = 0
    Effects.animations = {}
end

return Effects
