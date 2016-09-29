package.path = package.path .. ";../?.lua"
sone = require "sone"

function love.load(arg)
    currentSound = nil

    samples = {
        "assets/drum_and_bass.mp3",
        "assets/people.mp3",
    }

    currentSample = 1

    function generateSounds()
        if currentSound then 
            currentSound:stop()
            currentSound = nil 
        end
        sounds = {
            original = love.sound.newSoundData(samples[currentSample]),
            lowpass = love.sound.newSoundData(samples[currentSample]),
            highpass = love.sound.newSoundData(samples[currentSample]),
            bandpass = love.sound.newSoundData(samples[currentSample]),
            notch = love.sound.newSoundData(samples[currentSample]),
            allpass = love.sound.newSoundData(samples[currentSample]),
            peakeq = love.sound.newSoundData(samples[currentSample]),
            lowshelf = love.sound.newSoundData(samples[currentSample]),
            highshelf = love.sound.newSoundData(samples[currentSample]),
            leftpan = love.sound.newSoundData(samples[currentSample]),
            rightpan = love.sound.newSoundData(samples[currentSample]),
            fadein = love.sound.newSoundData(samples[currentSample]),
            fadeout = love.sound.newSoundData(samples[currentSample]),
            fadeinout = love.sound.newSoundData(samples[currentSample]),
            amplified = love.sound.newSoundData(samples[currentSample]),
        }

        sone.filter(sounds.lowpass, {
            type = "lowpass",
            frequency = 150,
        })

        sone.filter(sounds.highpass, {
            type = "highpass",
            frequency = 1000,
        })

        sone.filter(sounds.bandpass, {
            type = "bandpass",
            frequency = 1000,
            Q = 0.866,
            gain = -3,
        })

        sone.filter(sounds.notch, {
            type = "notch",
            frequency = 1000,
            Q = 0.8,
            gain = 6,
        })

        sone.filter(sounds.allpass, {
            type = "allpass",
            frequency = 0,
        })

        -- Boost sound at 1000Hz
        sone.filter(sounds.peakeq, {
            type = "peakeq",
            frequency = 1000,
            gain = 9,
        })

        -- Boost everything below 150Hz by 6dB
        sone.filter(sounds.lowshelf, {
            type = "lowshelf",
            frequency = 150,
            gain = 6,
        })

        -- Boost everything above 4kHz by 12dB
        sone.filter(sounds.highshelf, {
            type = "highshelf",
            frequency = 4000,
            gain = 12,
        })

        -- Amplify sound by 4.5dB
        sone.amplify(sounds.amplified, 4.5)

        sone.pan(sounds.leftpan, -1)
        sone.pan(sounds.rightpan, 1)

        sone.fadeIn(sounds.fadein, 5)
        sone.fadeOut(sounds.fadeout, 5)

        sone.fadeInOut(sounds.fadeinout, 5)

        soundList = {
            sounds.original,
            sounds.lowpass,
            sounds.highpass,
            sounds.bandpass,
            sounds.amplified,
            sounds.peakeq,
            sounds.highshelf,
            sounds.leftpan,
            sounds.fadeinout,
        }
    end

    generateSounds()

    text = [[
Press TAB to change the sample sound
Press 1 for original, unaltered sound
Press 2 for lowpass
Press 3 for highpass
Press 4 for bandpass
Press 5 for amplified (+4.5dB)
Press 6 for peak EQ
Press 7 for highshelf filter
Press 8 for left pan
Press 9 for fade in and fade out
]]
    love.graphics.setNewFont(love.window.toPixels(24))


    function play(n)
        if currentSound ~= nil then 
            currentSound:stop() 
        end
        currentSound = love.audio.newSource(soundList[n])
        currentSound:play()
    end
end

function love.update(dt)

end

function love.keypressed(key)
    if key == "tab" then
        currentSample = currentSample + 1
        if currentSample > #samples then
            currentSample = 1
        end
        generateSounds()
        return
    end

    key = tonumber(key)
    if key ~= nil and key > 0 and key < 10 then
        play(key)
    end
end

function love.draw()
    love.graphics.printf(text, 20, 20, love.graphics.getWidth(), "left")
end
