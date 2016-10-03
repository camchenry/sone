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
        }

        sounds.lowpass = sone.filter(sone.copy(sounds.original), {
            type = "lowpass",
            frequency = 150,
        })

        sounds.highpass = sone.filter(sone.copy(sounds.original), {
            type = "highpass",
            frequency = 1000,
        })

        sounds.bandpass = sone.filter(sone.copy(sounds.original), {
            type = "bandpass",
            frequency = 1000,
            Q = 0.866,
            gain = -3,
        })

        sounds.notch = sone.filter(sone.copy(sounds.original), {
            type = "notch",
            frequency = 1000,
            Q = 0.8,
            gain = 6,
        })

        sounds.allpass = sone.filter(sone.copy(sounds.original), {
            type = "allpass",
            frequency = 0,
        })

        -- Boost sound at 1000Hz
        sounds.peakeq = sone.filter(sone.copy(sounds.original), {
            type = "peakeq",
            frequency = 1000,
            gain = 9,
        })

        -- Boost everything below 150Hz by 6dB
        sounds.lowshelf = sone.filter(sone.copy(sounds.original), {
            type = "lowshelf",
            frequency = 150,
            gain = 6,
        })

        -- Boost everything above 4kHz by 12dB
        sounds.highshelf = sone.filter(sone.copy(sounds.original), {
            type = "highshelf",
            frequency = 4000,
            gain = 12,
        })

        -- Amplify sound by 4.5dB
        sounds.amplified = sone.amplify(sone.copy(sounds.original), 4.5)

        sounds.leftpan = sone.pan(sone.copy(sounds.original), -1)
        sounds.rightpan = sone.pan(sone.copy(sounds.original), 1)

        sounds.fadein = sone.fadeIn(sone.copy(sounds.original), 5)
        sounds.fadeout = sone.fadeOut(sone.copy(sounds.original), 5)

        sounds.fadeinout = sone.fadeInOut(sone.copy(sounds.original), 5)

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
