local Audio = {}

Audio.bgm = nil
Audio.baseVolume = 0.5
Audio.isMuted = false

function Audio.load()
    -- Attempt to load background music from game directory
    -- Check common formats (Prioritize assets folder)
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

    if bgmFile then
        local success, err = pcall(function()
            Audio.bgm = love.audio.newSource(bgmFile, "stream")
            Audio.bgm:setLooping(true)
            Audio.bgm:setVolume(Audio.baseVolume)
            print("Audio: Reviewing track " .. bgmFile)
        end)
        
        if not success then
            print("Audio: Failed to load BGM: " .. tostring(err))
        end
    else
        print("Audio: No 'bgm.mp3/ogg/wav' found in game directory.")
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

function Audio.setVolume(vol)
    Audio.baseVolume = math.max(0, math.min(1, vol))
    if Audio.bgm then
        Audio.bgm:setVolume(Audio.baseVolume)
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
