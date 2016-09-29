# sone
Sone is a sound processing library for LÖVE.

[Documentation](http://camchenry.com/sone)

# When to use sone
Sone was made for quickly iterating on a sound effect, then going back and preprocessing the sound later. Use sone if:
* You want to not have to export a new sound effect each time you make a change.
* You can afford to generate effects in real time.
* You just want cool sound effects

# Features
* Filters
  * Lowpass
  * Highpass
  * Bandpass
  * Allpass
  * Notch
  * Lowshelf
  * Highshelf
  * Peak EQ
* Amplification
* Panning
* Fading in
* Fading out

# Example
```lua
sone = require 'sone'
sound = love.sound.newSoundData(...)

-- NOTE: All sone functions will alter the sound data directly.

-- Filter out all sounds above 150Hz.
sone.filter(sound, {
    type = "lowpass",
    frequency = 150,
})

-- Boost sound at 1000Hz
sone.filter(sound, {
    type = "peakeq",
    frequency = 1000,
    gain = 9,
})

-- Boost everything below 150Hz by 6dB
sone.filter(sound, {
    type = "lowshelf",
    frequency = 150,
    gain = 6,
})

-- Amplify sound by 3dB
sone.amplify(sound, 3)

-- Pan sound to the left ear
sone.pan(sound, -1)

-- Fade in sound over 5 seconds
sone.fadeIn(sound, 5)

-- Fade in sound over 5 seconds, and also fade out the last 5 seconds
sone.fadeInOut(sound, 5)
```

# Building documentation
To build the HTML documentation, run:
```bash
cd docs
lua rtfm.lua ../sone.lua > index.html
```
