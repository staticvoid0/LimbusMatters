-- LimbusMatters spinning splash animation for Windower 4
-- Place this file in your addon directory, and the 72 PNGs in data/splash_frames/
local images = require('images')
local _Animationator = {}

local screen = windower.get_windower_settings()
local center_x = screen.ui_x_res / 2
local center_y = screen.ui_y_res / 2

local FRAME_COUNT = 72
local ROTATIONS = 4
local SPLASH_DURATION = 10.0
local HOLD_DURATION = 4.0
local FRAME_SIZE = 512

local start_x = center_x - 140
local start_y = center_y - 40
local vortex_x = center_x - 600
local vortex_y = center_y - 30

-- Original title begins at (48,192) within the unrotated 512x512 PNG.
-- Keep that title aligned with the original splash start coordinates.
local image_start_x = start_x - 48
local image_start_y = start_y - 192
local frame_dir = windower.addon_path .. 'data/splash_frames/'

local splash = images.new({
    pos = {x = image_start_x, y = image_start_y},
    size = {width = FRAME_SIZE, height = FRAME_SIZE},
    texture = {path = frame_dir .. 'frame_00.png', fit = false},
    color = {alpha = 255, red = 255, green = 255, blue = 255},
    draggable = false,
    visible = false,
})
splash:hide()

local splash_active = false
local splash_start = 0
local splash_event = nil
local last_frame = -1

local function stop_splash()
    splash_active = false
    splash:hide()
    if splash_event then
        windower.unregister_event(splash_event)
        splash_event = nil
    end
end

function _Animationator.animate_splash()
    if not splash_active then return end

    local elapsed = os.clock() - splash_start
    if elapsed < HOLD_DURATION then return end

    local t = math.min((elapsed - HOLD_DURATION) /
        (SPLASH_DURATION - HOLD_DURATION), 1)

    if t >= 1 then
        stop_splash()
        return
    end

    local ease = t * t * t
    local scale = math.exp(-4 * ease)

    -- 4 full spins, with 72 distinct frames (5-degree increments).
    local phase = (t * ROTATIONS) % 1
    local frame = math.floor(phase * FRAME_COUNT) % FRAME_COUNT
    if frame ~= last_frame then
        splash:path(frame_dir .. string.format('frame_%02d.png', frame))
        last_frame = frame
    end

    -- Translate the center of the entire graphic toward the vortex.
    local dx = (vortex_x - start_x) * ease
    local dy = (vortex_y - start_y) * ease
    local spiral = math.sin(t * math.pi * 5) * 22 * (1 - t)

    -- Scale about the image center, not its top-left corner.
    local size = FRAME_SIZE * scale
    local x = image_start_x + dx + (FRAME_SIZE - size) / 2
    local y = image_start_y + dy + spiral + (FRAME_SIZE - size) / 2

    splash:pos(x, y)
    splash:size(size, size)
    splash:alpha(math.floor(255 * (1 - t * t)))
end

function _Animationator.start_splash()
    stop_splash()

    splash_active = true
    splash_start = os.clock()
    last_frame = -1

    splash:path(frame_dir .. 'frame_00.png')
    last_frame = 0
    splash:pos(image_start_x, image_start_y)
    splash:size(FRAME_SIZE, FRAME_SIZE)
    splash:alpha(255)
    splash:show()

    windower.play_sound(windower.addon_path .. 'data/load.wav')
    splash_event = windower.register_event('prerender', _Animationator.animate_splash)
end

return _Animationator
