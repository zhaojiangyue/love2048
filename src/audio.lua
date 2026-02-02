local Audio = {}

Audio.bgm = nil
-- Volume Configuration (adjust these values!)
Audio.bgmVolume = 0.5   -- Background music volume (0.0 to 1.0)
Audio.sfxVolume = 0.7  -- Sound effects volume (0.0 to 1.0)
Audio.isMuted = false

-- SFX Configuration: Add/change sound effects here!
-- Files should be placed in assets/sfx/ folder
Audio.sfxConfig = {
    sli_appear = "assets/sfx/sli_appear.mp3",    -- When SLI bridge forms
    sli_merge = "assets/sfx/sli_merge.mp3",      -- When SLI tiles merge
    heat_max = "assets/sfx/heat_max.mp3",        -- When heat reaches 100%
    downgrade = "assets/sfx/downgrade.mp3",      -- When tile is downgraded
    game_over = "assets/sfx/game_over.mp3",      -- Game over
    dlss_upgrade = "assets/sfx/dlss_upgrade.mp3", -- When DLSS upgrades a tile
}

Audio.sfx = {}

function Audio.load()
    -- Attempt to load background music from game directory
    local bgmFile = nil
    if love.filesystem.getInfo("assets/bgm.mp3") then
        bgmFile = "assets/bgm.mp3"
    elseif love.filesystem.getInfo("assets/bgm.ogg") then
        bgmFile = "assets/bgm.ogg"
    elseif love.filesystem.getInfo("bgm.mp3") then
        bgmFile = "bgm.mp3"
    elseif love.filesystem.getInfo("bgm.ogg") then
        bgmFile = "bgm.ogg"
    elseif love.filesystem.getInfo("bgm.wav") then
        bgmFile = "bgm.wav"
    end

    -- Stop ALL currently playing audio
    love.audio.stop()

    if bgmFile then
        local success, err = pcall(function()
            Audio.bgm = love.audio.newSource(bgmFile, "stream")
            Audio.bgm:setLooping(true)
            Audio.bgm:setVolume(Audio.bgmVolume)
            print("Audio: Loaded BGM " .. bgmFile)
        end)
        
        if not success then
            print("Audio: Failed to load BGM: " .. tostring(err))
        end
    else
        print("Audio: No BGM found.")
    end
    
    -- Load SFX
    for name, path in pairs(Audio.sfxConfig) do
        if love.filesystem.getInfo(path) then
            local success, result = pcall(function()
                return love.audio.newSource(path, "static")
            end)
            if success then
                Audio.sfx[name] = result
                Audio.sfx[name]:setVolume(Audio.sfxVolume)
                print("Audio: Loaded SFX " .. name .. " from " .. path)
            else
                print("Audio: Failed to load SFX " .. name .. ": " .. tostring(result))
            end
        else
            print("Audio: SFX file not found: " .. path .. " (you can add it later)")
        end
    end
end

function Audio.playBGM()
    if Audio.bgm and not Audio.isMuted then
        Audio.bgm:play()
    end
end

function Audio.stopBGM()
    if Audio.bgm then
        Audio.bgm:stop()
    end
end

function Audio.pauseBGM()
    if Audio.bgm then
        Audio.bgm:pause()
    end
end

-- Play a sound effect by name (see sfxConfig above)
function Audio.playSFX(name)
    if Audio.isMuted then return end
    
    local sound = Audio.sfx[name]
    if sound then
        -- Clone the source so we can play multiple instances
        sound:stop()
        sound:play()
    end
end

function Audio.setBGMVolume(vol)
    Audio.bgmVolume = math.max(0, math.min(1, vol))
    if Audio.bgm then
        Audio.bgm:setVolume(Audio.bgmVolume)
    end
end

function Audio.setSFXVolume(vol)
    Audio.sfxVolume = math.max(0, math.min(1, vol))
    for _, sound in pairs(Audio.sfx) do
        sound:setVolume(Audio.sfxVolume)
    end
end

function Audio.toggleMute()
    Audio.isMuted = not Audio.isMuted
    if Audio.bgm then
        if Audio.isMuted then
            Audio.bgm:pause()
        else
            Audio.bgm:play()
        end
    end
    print("Audio: Mute " .. (Audio.isMuted and "ON" or "OFF"))
    return Audio.isMuted
end

return Audio
