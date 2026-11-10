local texts = require('texts')
local _Animationator = {}
local screen = windower.get_windower_settings()
local center_x = screen.ui_x_res / 2
local center_y = screen.ui_y_res / 2

local splash_title = texts.new({
    pos = {x = center_x - 140, y = center_y - 40},
    text = {
        font = 'Consolas', size = 42, alpha = 255,
        red = 255, green = 0, blue = 255,
        stroke = {width = 3, padding = 1, alpha = 255, red = 0, green = 0, blue = 0},
    },
    bg = {visible = false},
    flags = {bold = true, draggable = false},
})

local splash_author = texts.new({
    pos = {x = center_x - 95, y = center_y + 20},
    text = {
        font = 'Consolas', size = 17, alpha = 255,
        red = 255, green = 255, blue = 255,
        stroke = {width = 2, padding = 2, alpha = 255, red = 0, green = 0, blue = 0},
    },
    bg = {visible = false},
    flags = {draggable = false},
})

splash_title:text('LimbusMatters™')
splash_author:text('by Staticvoid')
splash_title:hide()
splash_author:hide()

local splash_active = false
local splash_start = 0
local splash_event = nil
local SPLASH_DURATION = 6.0
local HOLD_DURATION = 3.0

local start_x = center_x - 140
local start_y = center_y - 40
local vortex_x = center_x - 600
local vortex_y = center_y - 30

function _Animationator.animate_splash()
    if not splash_active then return end

    local elapsed = os.clock() - splash_start
    if elapsed < HOLD_DURATION then return end

    local t = math.min((elapsed - HOLD_DURATION) /
        (SPLASH_DURATION - HOLD_DURATION), 1)

    local ease = t * t * t
    local scale = math.exp(-4 * ease)

    -- Four complete 360-degree spins
    local rotations = 4
    local angle = t * 360 * rotations

    -- Original movement toward vortex
    local spiral = math.sin(t * math.pi * 5) * 22 * (1 - t)
    local x = start_x + (vortex_x - start_x) * ease
    local y = start_y + (vortex_y - start_y) * ease + spiral

    local alpha = math.floor(255 * (1 - t * t))

    splash_title:pos(x, y)
    splash_author:pos(x + 45 * scale, y + 60 * scale)

    splash_title:size(math.max(2, math.floor(42 * scale)))
    splash_author:size(math.max(2, math.floor(17 * scale)))

    splash_title:alpha(alpha)
    splash_author:alpha(alpha)

    -- angle is ready for a rotation-capable renderer.
    -- Windower texts objects do not support rotation.

    if t >= 1 then
        splash_active = false
        splash_title:hide()
        splash_author:hide()

        if splash_event then
            windower.unregister_event(splash_event)
            splash_event = nil
        end
    end
end

function _Animationator.start_splash()
    if splash_event then
        windower.unregister_event(splash_event)
        splash_event = nil
    end

    splash_active = true
    splash_start = os.clock()
    splash_title:pos(start_x, start_y)
    splash_author:pos(start_x + 45, start_y + 60)
    splash_title:size(42)
    splash_author:size(17)
    splash_title:alpha(255)
    splash_author:alpha(255)
    splash_title:show()
    splash_author:show()
    windower.play_sound(windower.addon_path .. 'data/load.wav')
    splash_event = windower.register_event('prerender', _Animationator.animate_splash)
end
return _Animationator