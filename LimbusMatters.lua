--[[ 
Copyright © 2026, Staticvoid
All rights reserved.
Redistribution and use in source and binary forms, without
modification, is permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of LimbusMatters.
      names of its author may be used to endorse or promote products
      derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Staticvoid BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

--[[
    Display data progress in the two Limbii. Completed climb tracking and Code status that resets weekly. Chest open order tracking. Tracks 5k chests and keeps an accessible history of Alabaster / Murky Matter drops each week.
]]

_addon.name = 'LimbusMatters'
_addon.author = 'Staticvoid'
_addon.version = '1.0'
_addon.commands = {'LimbusMatters','lm'}


local _Animationator = require('splash')
local config = require('config')
local texts = require('texts')
local images = require('images')
local packets = require('packets')
require('logger')
local check_settings = windower.get_windower_settings()
local check_icon = images.new({
    texture = {
        path = windower.addon_path .. 'data/checkmark.png',
    },
    pos = {
        x = check_settings.ui_x_res / 150,
        y = check_settings.ui_y_res / 18,
    },
    size = {height = 25, width = 25},
    draggable = false,
    visible = true,
})
check_icon:pos(check_settings.ui_x_res / 150, check_settings.ui_y_res / 18)
check_icon:size(17, 17)
check_icon:fit(false)
local player_info = windower.ffxi.get_info().logged_in and windower.ffxi.get_player().name
local defaults = {
    toggle_sound = true,
    temenos_climbs = 0,
    apollyon_climbs = 0,
    climb_week = 0,
    temenos_message_id = 7281,
    apollyon_message_id = 7289,
    temenos_code_obtained = false,
    apollyon_code_obtained = false,
    temenos_last_5k = '',
    apollyon_last_5k = '',
    matter_history = {},
    limbus_chest_order = {
        temenos = {
            N4 = 4,
            W4 = 3,
            E4 = 2,
            C3 = 1,
        },
        apollyon = {
            NW5 = 4,
            SW4 = 3,
            NE5 = 2,
            SE4 = 1,
        },
    },
}
local settings
if player_info then settings = config.load('data/settings_'..player_info..'.xml', defaults) else settings = config.load(defaults) end
if not settings.temenos_last_5k or settings.temenos_last_5k == '' then
    settings.temenos_last_5k = 'C'
end
if not settings.apollyon_last_5k or settings.apollyon_last_5k == '' then
    settings.apollyon_last_5k = 'SE'
end
config.save(settings)

local function get_climb_message_id(area)
    if area == 'Temenos' then
        return tonumber(settings.temenos_message_id) or 7281
    elseif area == 'Apollyon' then
        return tonumber(settings.apollyon_message_id) or 7289
    end
    return nil
end
--Chest detection window to dynamically update Message ID after an update.
local chest_check_until = 0
local MESSAGE_ID_RANGE = 5

local chest_npcs = {
    Temenos = {
        [16929362] = 'N4',
        [16929363] = 'W4',
        [16929364] = 'E4',
        [16929365] = 'C3',
    },
    Apollyon = {
        [16933563] = 'NW5',
        [16933564] = 'SW4',
        [16933565] = 'NE5',
        [16933566] = 'SE4',
    },
}
local RACE_SHARDS = {
    [1] = 10006, [2] = 10006,  -- Hume M&F:     Hope
    [3] = 10007, [4] = 10007,  -- Elvaan M&F:   Trust
    [5] = 10008, [6] = 10008,  -- Tarutaru M&F: Bravery
    [7] = 10009,               -- Mithra F:     Justice
    [8] = 10010                -- Galka M:      Mercy
}
local floor_lookup = {
    Temenos = {
        [11]=9956, [12]=9957, [13]=9958, [14]=9959,
        [21]=9963, [22]=9964, [23]=9965, [24]=9966,
        [31]=9970, [32]=9971, [33]=9972, [34]=9973,
        [41]=9977, [42]=9978, [43]=9979,
    },

    Apollyon = {
        [11]=9981, [12]=9982, [13]=9983, [14]=9984, [15]=9985,
        [21]=9986, [22]=9987, [23]=9988, [24]=9989,
        [31]=9990, [32]=9991, [33]=9992, [34]=9993, [35]=9994,
        [41]=9995, [42]=9996, [43]=9997, [44]=9998,
    },
}
local limbus_data = {
    Temenos = {
        {name = 'N-1', id = 9956},
        {name = 'N-2', id = 9957},
        {name = 'N-3', id = 9958},
        {name = 'N-4', id = 9959},

        {name = 'W-1', id = 9963},
        {name = 'W-2', id = 9964},
        {name = 'W-3', id = 9965},
        {name = 'W-4', id = 9966},

        {name = 'E-1', id = 9970},
        {name = 'E-2', id = 9971},
        {name = 'E-3', id = 9972},
        {name = 'E-4', id = 9973},

        {name = 'C-1', id = 9977},
        {name = 'C-2', id = 9978},
        {name = 'C-3', id = 9979},
        {name = 'Code', id = 10044},
    },

    Apollyon = {
        {name = 'NW1', id = 9981},
        {name = 'NW2', id = 9982},
        {name = 'NW3', id = 9983},
        {name = 'NW4', id = 9984},
        {name = 'NW5', id = 9985},

        {name = 'SW1', id = 9986},
        {name = 'SW2', id = 9987},
        {name = 'SW3', id = 9988},
        {name = 'SW4', id = 9989},

        {name = 'NE1', id = 9990},
        {name = 'NE2', id = 9991},
        {name = 'NE3', id = 9992},
        {name = 'NE4', id = 9993},
        {name = 'NE5', id = 9994},

        {name = 'SE1', id = 9995},
        {name = 'SE2', id = 9996},
        {name = 'SE3', id = 9997},
        {name = 'SE4', id = 9998},
        {name = 'Code', id = 10045},
    },
}

local toggle_sound = settings.toggle_sound
local check_sound = windower.addon_path .. 'data/check.wav'
local reset_check = false
local current_area = nil
local current_floor = nil
local last_interacted_chest = nil
local last_interacted_area = nil
local climbs = {
    Temenos = tonumber(settings.temenos_climbs) or 0,
    Apollyon = tonumber(settings.apollyon_climbs) or 0,
}

local function add_table_entry(zone, entry)
    local t = settings.limbus_chest_order[zone]
    if not t or not t[entry] then
        return false
    end
    -- Already the most recently opened chest
    if t[entry] == 1 then
        return false
    end
    local chests = {}
    for name, rank in pairs(t) do
        chests[#chests + 1] = {
            name = name,
            rank = rank,
        }
    end
    table.sort(chests, function(a, b)

        if a.name == entry then
            return true
        elseif b.name == entry then
            return false
        elseif a.rank ~= b.rank then
            return a.rank < b.rank
        else
            return a.name < b.name
        end
    end)
    for i, chest in ipairs(chests) do
        t[chest.name] = i
    end
    config.save(settings)
    return true
end

local function sync_chest_data(chestdata)
    settings.limbus_chest_order = chestdata
    config.save(settings)
    log('Chest tracking updated.')
end

local display_settings = {
    pos = {
        x = 500,
        y = 350,
    },
    text = {
        font = 'Consolas',
        size = 10,
        alpha = 255,
        red = 200,
        green = 200,
        blue = 200,
        stroke = {
            alpha = 255,
            red = 0,
            green = 0,
            blue = 0,
            width = 2,
            padding = 1
        }
    },
    bg = {
        visible = true,
        alpha = 80,
        red = 235,
        green = 0,
        blue = 200,
    },
    flags = {
        draggable = true,
    },
    padding = 3,
}

local display = texts.new('', display_settings)
display:hide()

local GREEN = '\\cs(0,255,0)'
local GRAY  = '\\cs(110,110,110)'
local AZURE = '\\cs(40,75,235)'
local MINT = '\\cs(0,223,255)'
local RESET = '\\cr'

local function get_player_shard_id()
    local player = windower.ffxi.get_mob_by_target('me')
    return player and RACE_SHARDS[player.race]
end

-- Present in one of the Limbii
local function get_area(zone)
    if zone == 37 then
        return 'Temenos'
    elseif zone == 38 then
        return 'Apollyon'
    end

    return nil
end

local function get_next_chest(area)

    if not area then
        return nil
    end

    local order = settings.limbus_chest_order[area:lower()]

    if not order then
        return nil
    end

    local next_chest
    local highest_rank = 0

    for name, rank in pairs(order) do
        rank = tonumber(rank)

        if rank and rank > highest_rank then
            highest_rank = rank
            next_chest = name
        end
    end

    return next_chest
end

local function get_temp_items()
    local owned = {}
    local items = windower.ffxi.get_items(3)

    if not items then
        return owned
    end

    for _, item in pairs(items) do
        if type(item) == 'table' and item.id then
            owned[item.id] = true
        end
    end

    return owned
end

local function build_display(area)

    if not area or not limbus_data[area] then
        return ''
    end

    local lines = {'   ' .. area:upper() .. ' DATA','  Climbs: ' .. (climbs[area] or 0) .. '/5'}
    local column_names = area == 'Temenos' and {'N', 'W', 'E', 'C'} or {'NW', 'SW', 'NE', 'SE'}
    local COLUMN_WIDTH, COLUMN_GAP = 3, ' '
    local owned = get_temp_items()
    local code_id = area == 'Temenos' and 10044 or 10045
    local columns = {}

    for _, name in ipairs(column_names) do
        columns[name] = {}
    end

    for _, floor in ipairs(limbus_data[area]) do

        local column = area == 'Temenos' and floor.name:match('^([NWEC])') or floor.name:match('^(%a%a)')

        if column and columns[column] then
            table.insert(columns[column], floor)
        end
    end

    local max_rows = 0

    for _, name in ipairs(column_names) do
        max_rows = math.max(max_rows, #columns[name])
    end

    local last_5k_column = settings[area:lower() .. '_last_5k']
    local gold_indicators = {}

    for _, name in ipairs(column_names) do
        gold_indicators[#gold_indicators + 1] = name == last_5k_column and ' ▼ ' or '   '
    end

    lines[#lines + 1] = '\\cs(255,215,0)' .. table.concat(gold_indicators, COLUMN_GAP) .. RESET

    for row = 1, max_rows do

        local parts = {}

        for _, name in ipairs(column_names) do

            local floor = columns[name][row]
            local is_code_slot = (area == 'Temenos' and name == 'C' and row == 4) or (area == 'Apollyon' and name == 'SE' and row == 5)

            if is_code_slot then

                local code_obtained = (area == 'Temenos' and settings.temenos_code_obtained == true) or (area == 'Apollyon' and settings.apollyon_code_obtained == true)
                local code_text = ''

                if owned[code_id] then
                    code_text = GREEN .. 'Code' .. RESET
                elseif not code_obtained then
                    code_text = GRAY .. 'Code' .. RESET
                end

                if code_text == '' then
                    code_text = string.rep(' ', math.max(COLUMN_WIDTH, 4))
                end

                parts[#parts + 1] = code_text

            elseif floor then

                local has_data = owned[floor.id] == true
                local color = GRAY

                if has_data then
                    color = GREEN
                end

                if current_floor == floor.id then
                    color = has_data and MINT or AZURE
                end

                local padded_name = string.format('%-' .. COLUMN_WIDTH .. 's', floor.name)

                parts[#parts + 1] = color .. padded_name .. RESET

            else
                parts[#parts + 1] = string.rep(' ', COLUMN_WIDTH)
            end
        end

        lines[#lines + 1] = table.concat(parts, COLUMN_GAP)
    end

    local next_chest = get_next_chest(area)
    local next_column = next_chest and (area == 'Temenos' and next_chest:match('^([NWEC])') or next_chest:match('^(%a%a)'))
    local silver_indicators = {}

    for _, name in ipairs(column_names) do
        silver_indicators[#silver_indicators + 1] = name == next_column and ' ▲ ' or '   '
    end

    lines[#lines + 1] = '\\cs(192,192,192)' .. table.concat(silver_indicators, COLUMN_GAP) .. RESET

    return table.concat(lines, '\n  ')
end

local function update_display()
    if not current_area then
        display:hide()
        return
    end

    display:text(build_display(current_area))
    display:show()
end

local function record_last_5k(area, chest)
    if not area or not chest then return end

    local column = area == 'Temenos' and chest:match('^([NWEC])') or chest:match('^(%a%a)')
    if not column then return end

    settings[area:lower() .. '_last_5k'] = column
    config.save(settings)
    update_display()
end


local info = windower.ffxi.get_info()
if info then
    current_area = get_area(info.zone)
end
if current_area then
    update_display()
end

local JST_OFFSET = 9 * 60 * 60
local WEEK_SECONDS = 7 * 24 * 60 * 60

local function get_climb_week()
    local now = os.time()
    local jst_now = now + JST_OFFSET
    local monday_offset = 4 * 24 * 60 * 60
    local week_start = math.floor((jst_now - monday_offset) / WEEK_SECONDS) * WEEK_SECONDS + monday_offset
    return week_start - JST_OFFSET
end

local MATTER_IDS = {
    Temenos = 9999,
    Apollyon = 10000,
}
-- Recycle
local function get_item_count(area, shard)
    local item_id
    if shard then item_id = shard else item_id = MATTER_IDS[area] end -- if we have a second argument we want to count shards otherwise count matters

        if not item_id then
            return 0
        end

        local total = 0

        for bag = 0, 16 do

            if bag ~= 3 then

                local items = windower.ffxi.get_items(bag)

                if items then
                    for index, item in pairs(items) do

                        if type(item) == 'table'
                            and item.id == item_id then

                            total = total + (tonumber(item.count) or 0)
                        end
                    end
                end
            end
        end

    return total
end

local function record_matter(area, count)

    if not MATTER_IDS[area] then
        return
    end

    count = tonumber(count) or 1

    if count <= 0 then
        return
    end

    local week = os.date('!%Y-%m-%d', get_climb_week() + 9 * 3600)

    settings.matter_history = settings.matter_history or {}

    local history = settings.matter_history

    if not history[week] then
        history[week] = {
            temenos = 0,
            apollyon = 0,
        }
    end

    local key = area:lower()

    history[week][key] =
        (tonumber(history[week][key]) or 0) + count

    config.save(settings)

    windower.add_to_chat(207,
        (area == 'Temenos' and 'Alabaster' or 'Murky') ..
        ' Matter weekly total: ' ..
        history[week][key] .. ' \nTotal held: ' .. get_item_count(area)
    )
end

local function show_matter_history()

    local history = settings.matter_history or {}
    local weeks = {}

    for week in pairs(history) do
        weeks[#weeks + 1] = week
    end

    if #weeks == 0 then
        windower.add_to_chat(207, 'No Matter history recorded yet.')
        return
    end

    table.sort(weeks)

    windower.add_to_chat(207, ' \n            Matters\n------------------------------------')
    windower.add_to_chat(207, 'Week            Temenos   Apollyon')
    windower.add_to_chat(207, '------------------------------------')

    for _, week in ipairs(weeks) do

        local entry = history[week]

        windower.add_to_chat(207,
            string.format(
                '%-14s  %-11d %d',
                tostring(week),
                tonumber(entry.temenos) or 0,
                tonumber(entry.apollyon) or 0
            )
        )
    end
    local alabaster = get_item_count('Temenos')
    local murky = get_item_count('Apollyon')

    windower.add_to_chat(207,
        string.format(
            ' \nTotal:\n-----------\n Alabaster: %d \n Murky: %d',
            alabaster,
            murky
        )
    )
end

local function show_matter_count()

    local alabaster = get_item_count('Temenos')
    local murky = get_item_count('Apollyon')

    windower.add_to_chat(207,
        string.format(
            '  Matters\n-----------\n Alabaster: %d \n Murky: %d',
            alabaster,
            murky
        )
    )
end


local function check_weekly_reset()

    local current_week = get_climb_week()

    if tonumber(settings.climb_week) ~= current_week then

        -- Reset weekly climb counts
        climbs.Temenos = 0
        climbs.Apollyon = 0

        settings.temenos_climbs = 0
        settings.apollyon_climbs = 0

        -- Reset weekly Code acquisition
        settings.temenos_code_obtained = false
        settings.apollyon_code_obtained = false

        settings.climb_week = current_week

        config.save(settings)

        return true
    end

    return false
end

local function sync_code_progress()

    local owned = get_temp_items()
    local changed = false

    if owned[10044] and not settings.temenos_code_obtained then
        settings.temenos_code_obtained = true
        changed = true
    end

    if owned[10045] and not settings.apollyon_code_obtained then
        settings.apollyon_code_obtained = true
        changed = true
    end

    if changed then
        config.save(settings)
    end
end

local function begin_chest_check()

    chest_check_until = os.time() + 5

    local area, chest = current_area, last_interacted_chest

    if not area then return end
    local shard_id = get_player_shard_id()
    local matter_before, shards_before = get_item_count(area), get_item_count(nil,shard_id)

    coroutine.schedule(function()

        if current_area ~= area then return end

        local matter_after, shards_after = get_item_count(area), get_item_count(nil,shard_id)

        if matter_before and matter_after and matter_after > matter_before then
            record_matter(area, matter_after - matter_before)
        end

        if shards_before and shards_after and shards_after - shards_before >= 2 and chest then
            record_last_5k(area, chest)
        end

    end, 5)
end

windower.register_event('add item', function(bag, index, id, count)

    if not current_area or bag ~= 3 then -- If not in one of the Limbii AND dealing with Temp. Item skip processing
        return
    end
    
    local is_floor_data = id >= 9956 and id <= 9998
    local is_code = id == 10044 or id == 10045

    if not is_floor_data and not is_code then
        return
    end

    -- Record Code acquisition for this week
    if is_code then

        if id == 10044 then
            settings.temenos_code_obtained = true

        elseif id == 10045 then
            settings.apollyon_code_obtained = true
        end

        config.save(settings)

        update_display()
        return
    end

    update_display()

    if reset_check and current_floor then
        reset_check = false

        if toggle_sound then
            windower.play_sound(check_sound)
        end

        check_icon:show()

        windower.add_to_chat(207, 'Data received.')
    end
end)

windower.register_event('remove item', function(bag, index, id, count)

    if not current_area or bag ~= 3 then -- If not in one of the Limbii AND dealing with Temp. Item skip processing
        return
    end

    if (id >= 9956 and id <= 9998) or id == 10044 or id == 10045 then
        update_display()
    end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    if not current_area or blocked then
        return
    end

    if id == 0x05C then
        local packet = packets.parse('outgoing', modified or data)
        local floor_code = packet and packet["_unknown1"]
        if floor_code then
            if floor_code == 1 then
                current_floor = nil
            else
                current_floor = floor_lookup[current_area][floor_code]
            end
            update_display()
        end
        reset_check = true
        check_icon:hide()
    end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    if id ~= 0x01A or not current_area or blocked then
        return
    end
    local p = packets.parse('outgoing', modified or data)
    if not p then
        return
    end
    local target = tonumber(p['Target'])
    if target then
        local chest = chest_npcs[current_area] and chest_npcs[current_area][target]
        if chest then
            last_interacted_chest = chest
            last_interacted_area = current_area
            begin_chest_check()
        end
    end
end)

windower.register_event('outgoing chunk', function(id, data, modified, injected, blocked)
    if id ~= 0x05B or not current_area or blocked then
        return
    end
    local p = packets.parse('outgoing', modified or data)
    if not p or p['Automated Message'] ~= true then
        return
    end
    local target = tonumber(p['Target'])
    local tower = chest_npcs[current_area] and chest_npcs[current_area][target]
    if not tower then
        return
    end
    local zone = current_area:lower()
    if add_table_entry(zone, tower) then
        update_display()
        windower.add_to_chat(207, 'Limbus chest order updated: ' .. tower)
    end
end)

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)

    if id ~= 0x02A or not current_area or blocked then
        return
    end

    local packet = packets.parse('incoming', modified or data)

    if not packet then
        return
    end

    local msg_id = tonumber(packet['Message ID'])
    local remaining = tonumber(packet['Param 1'])
    local window_active = os.time() <= chest_check_until

    if not msg_id or not remaining then return end

    if remaining == 5000 and window_active and last_interacted_chest and last_interacted_area == current_area then
        record_last_5k(current_area, last_interacted_chest)
        return
    end

    -- Server reports 0-4 remaining climbs
    if remaining < 0 or remaining > 4 or remaining ~= math.floor(remaining) then
        return
    end

    local expected_id = get_climb_message_id(current_area)

    if not expected_id then
        return
    end

    local setting_key = current_area == 'Temenos' and 'temenos_message_id' or 'apollyon_message_id'
    local new_climbs = 5 - remaining

    -- If its our known MSG ID process them shitz.
    if msg_id == expected_id then
        check_weekly_reset()
        climbs[current_area] = new_climbs
        settings[current_area == 'Temenos' and 'temenos_climbs' or 'apollyon_climbs'] = new_climbs
        settings.climb_week = get_climb_week()
        config.save(settings)
        update_display()
        windower.add_to_chat(207,current_area .. ' climbs: ' ..new_climbs .. '/5')
        return
    end

    -- If the MSG ID has been changed after monthly update.
    if not window_active then
        return
    end

    if math.abs(msg_id - expected_id) > MESSAGE_ID_RANGE then
        return
    end

    check_weekly_reset()

    -- If it passes our checks and we have the new MSG ID update the MSG ID and save it to xml.
    windower.add_to_chat(207,'LimbusMatters: ' .. current_area ..' Message ID changed: ' ..expected_id .. ' -> ' .. msg_id)

    settings[setting_key] = msg_id
    climbs[current_area] = new_climbs
    settings[current_area == 'Temenos' and 'temenos_climbs' or 'apollyon_climbs'] = new_climbs
    settings.climb_week = get_climb_week()

    config.save(settings)
    update_display()

    windower.add_to_chat(207,current_area .. ' climbs: ' ..new_climbs .. '/5')
end)

-- Sleep outside of Limbii.
local time_change_event = nil
local status_change_event = nil

local function register_limbus_events()

    if not time_change_event then
        time_change_event = windower.register_event('time change', function()
            if check_weekly_reset() then
                update_display()
            end
        end)
    end

    if not status_change_event then
        status_change_event = windower.register_event('status change', function(new, old)
            if new == 1 then
                check_icon:pos(
                    check_settings.ui_x_res / 150,
                    check_settings.ui_y_res / 10.35
                )
            else
                check_icon:pos(
                    check_settings.ui_x_res / 150,
                    check_settings.ui_y_res / 18
                )
            end
        end)
    end
end

local function unregister_limbus_events()
    if time_change_event then
        windower.unregister_event(time_change_event)
        time_change_event = nil
    end
    if status_change_event then
        windower.unregister_event(status_change_event)
        status_change_event = nil
    end
end

windower.register_event('zone change', function(new_id, old_id)
    current_area = get_area(new_id)
    current_floor = nil
    if current_area then
        register_limbus_events()
        reset_check = true
        check_icon:hide()
        update_display()
    else
        unregister_limbus_events()
        reset_check = false
        check_icon:hide()
        display:hide()
    end
end)

windower.register_event('login', function()
    player_info = windower.ffxi.get_player()
    if not player_info then
        return
    end
    settings = config.load(
        ('data/settings_%s.xml'):format(player_info.name),
        defaults
    )
    if not settings.temenos_last_5k or settings.temenos_last_5k == '' then
        settings.temenos_last_5k = 'C'
    end
    if not settings.apollyon_last_5k or settings.apollyon_last_5k == '' then
        settings.apollyon_last_5k = 'SE'
    end
    config.save(settings)
    local info = windower.ffxi.get_info()
    current_area = info and get_area(info.zone) or nil
    if current_area then
        register_limbus_events()
    else
        unregister_limbus_events()
    end
end)

windower.register_event('load', function()
    _Animationator.start_splash()
    local info = windower.ffxi.get_info()
    current_area = info and get_area(info.zone) or nil
    if current_area then
        register_limbus_events()
        check_weekly_reset()
        sync_code_progress()
        update_display()
    else
        unregister_limbus_events()
    end
    coroutine.schedule(function()
        if player_info then 
            show_matter_history()
        end
    end,6)
end)

windower.register_event('ipc message', function(msg)
    local args = msg:split(' ')
    local cmd = args[1]
    args:remove(1)
    if cmd == 'sync_limbus_chests' then
        local chestdata = args[1]
        if chestdata then
            local success, chest_table = pcall(function()
                return loadstring('return '..chestdata)()
            end)
            if success and type(chest_table) == 'table' then
                sync_chest_data(chest_table)
                coroutine.schedule(update_display, 1)
            end
        end
    end
end)

windower.register_event('addon command', function(...)
local args = {...}
local cmd = args[1]:lower()
    if cmd and cmd:contains('sync') then
        local chestdata = T(settings.limbus_chest_order):tovstring()
        chestdata = chestdata:gsub('%s+', '')
        windower.send_ipc_message('sync_limbus_chests '..chestdata)
        log('Chest tracking replicated across all other characters to match this character for both Limbii.')
    elseif cmd == 'r' then 
        windower.send_command('lua r LimbusMatters')
    elseif cmd:contains('matter') or cmd == 'history' then
        show_matter_history()
    end
end)