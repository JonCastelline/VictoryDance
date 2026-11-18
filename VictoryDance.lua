require('pack')

_addon.name     = 'VictoryDance'
_addon.author   = 'Jon'
_addon.version  = '1.0.0'
_addon.commands = {'victorydance', 'vd'}

local enabled = true
local emote = '/dance1 motion'
local last_dance_time = 0
local COOLDOWN = 4.0 -- seconds between flourishes
local FLOURISH_DELAY = 2.0 -- wait 2.0 seconds for combat disengage & sheathe animation

local last_target_id = nil

local function do_flourish()
    if not enabled then return end

    local now = os.clock()
    if (now - last_dance_time) < COOLDOWN then return end
    last_dance_time = now

    coroutine.schedule(function()
        windower.chat.input(emote)
    end, FLOURISH_DELAY)
end

-- Continuously track current target (even before engaging, so 1-shots are captured)
local function update_target()
    local target = windower.ffxi.get_mob_by_target('t')
    if target and target.id and target.id > 0 and target.is_npc then
        last_target_id = target.id
    end
end

windower.register_event('target change', update_target)
windower.register_event('prerender', update_target)

-- 1. Raw Packet 0x029 (Action Message): avoids Battlemod blocking 'action message' event
-- Defeat message IDs: 6 (actor defeats target), 20 (target falls to the ground)
local DEFEAT_MESSAGES = {
    [6]   = true,
    [20]  = true,
    [113] = true,
    [406] = true,
    [605] = true,
    [646] = true,
}

windower.register_event('incoming chunk', function(id, data)
    if id == 0x29 then
        local actor_id = data:unpack('I', 0x05)
        local target_id = data:unpack('I', 0x09)
        local message_id = data:unpack('H', 0x19) % 32768

        if DEFEAT_MESSAGES[message_id] then
            local player = windower.ffxi.get_player()
            -- Trigger if you defeated it, or the monster you were targeting was defeated
            if (player and actor_id == player.id) or (target_id == last_target_id) then
                do_flourish()
                last_target_id = nil
            end
        end
    end
end)

-- 2. Fallback: Player disengages when target dies (melee 1-shots)
windower.register_event('status change', function(new_status, old_status)
    if old_status == 1 and new_status == 0 then
        if last_target_id then
            local mob = windower.ffxi.get_mob_by_id(last_target_id)
            if not mob or mob.hpp == 0 or mob.status == 2 or mob.status == 3 then
                do_flourish()
            end
        else
            do_flourish()
        end
        last_target_id = nil
    end
end)

-- 3. Fallback: Battle log defeat text
windower.register_event('incoming text', function(original)
    local text = original:lower()
    if text:find("defeats ") or text:find("defeat the ") or text:find("falls to the ground") then
        local player = windower.ffxi.get_player()
        if player and (text:find(player.name:lower()) or text:find("you defeat")) then
            do_flourish()
            last_target_id = nil
        end
    end
end)

-- Command handling
windower.register_event('addon command', function(cmd, ...)
    cmd = cmd and cmd:lower() or 'help'
    local args = {...}

    if cmd == 'on' then
        enabled = true
        windower.add_to_chat(207, '[VictoryDance] Enabled.')
    elseif cmd == 'off' then
        enabled = false
        windower.add_to_chat(207, '[VictoryDance] Disabled.')
    elseif cmd == 'test' then
        windower.add_to_chat(207, '[VictoryDance] Testing flourish: ' .. emote)
        windower.chat.input(emote)

    -- [DEMO FEATURE: Uncomment below to demonstrate git diff / commit on GitHub]
    -- elseif cmd == 'motion' or cmd == 'emote' then
    --     local new_emote = table.concat(args, ' ')
    --     if new_emote and #new_emote > 0 then
    --         if new_emote:sub(1, 1) ~= '/' then
    --             new_emote = '/' .. new_emote
    --         end
    --         emote = new_emote
    --         windower.add_to_chat(207, '[VictoryDance] Emote set to: ' .. emote)
    --     else
    --         windower.add_to_chat(207, '[VictoryDance] Current emote: ' .. emote)
    --     end

    else
        windower.add_to_chat(207, '[VictoryDance] Commands: //vd on | //vd off | //vd test')
        -- windower.add_to_chat(207, '[VictoryDance] Custom emote command: //vd motion <emote>')
    end
end)
