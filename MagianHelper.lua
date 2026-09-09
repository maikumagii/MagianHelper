_addon.name = 'MagianHelper'
_addon.author = 'maikumagii'
_addon.version = '1.4.0'
_addon.commands = {'mh', 'magianhelper'}

local res = require('resources')

local state = 'off'
local hp_threshold = 100
local selected_ws = nil
local last_check = os.clock()
local last_attempt = 'none'
local am3_enabled = false
local am3_save_seconds = 15
local am3_expires_at = nil
local AM3_BUFF_ID = 272
local auto_engage = false
local auto_face = false
local last_combat_check = os.clock()

-- Add exact English item names and weaponskill names here as needed.
-- Matching by name covers upgrade stages that retain the same item name.
-- Shields and instruments have no associated WS and are intentionally omitted.
local mythic_defaults = {
    -- Mythic (20)
    ['Conqueror'] = "King's Justice",
    ['Glanzfaust'] = "Ascetic's Fury",
    ['Yagrush'] = 'Mystic Boon',
    ['Laevateinn'] = 'Vidohunir',
    ['Murgleis'] = 'Death Blossom',
    ['Vajra'] = 'Mandalic Stab',
    ['Burtgang'] = 'Atonement',
    ['Liberator'] = 'Insurgency',
    ['Aymur'] = 'Primal Rend',
    ['Carnwenhan'] = 'Mordant Rime',
    ['Gastraphetes'] = 'Trueflight',
    ['Kogarasumaru'] = 'Tachi: Rana',
    ['Nagi'] = 'Blade: Kamu',
    ['Ryunohige'] = 'Drakesbane',
    ['Nirvana'] = 'Garland of Bliss',
    ['Tizona'] = 'Expiacion',
    ['Death Penalty'] = 'Leaden Salute',
    ['Kenkonken'] = 'Stringing Pummel',
    ['Terpsichore'] = 'Pyrrhic Kleos',
    ['Tupsimati'] = 'Omniscience',
}

local weapon_defaults = {
    -- Relic (14)
    ['Spharai'] = 'Final Heaven',
    ['Mandau'] = 'Mercy Stroke',
    ['Excalibur'] = 'Knights of Round',
    ['Ragnarok'] = 'Scourge',
    ['Guttler'] = 'Onslaught',
    ['Bravura'] = 'Metatron Torment',
    ['Apocalypse'] = 'Catastrophe',
    ['Gungnir'] = 'Geirskogul',
    ['Kikoku'] = 'Blade: Metsu',
    ['Amanomurakumo'] = 'Tachi: Kaiten',
    ['Mjollnir'] = 'Randgrith',
    ['Claustrum'] = 'Gate of Tartarus',
    ['Yoichinoyumi'] = 'Namas Arrow',
    ['Annihilator'] = 'Coronach',


}
for weapon, ws in pairs(mythic_defaults) do
    weapon_defaults[weapon] = ws
end

local function message(text)
    windower.add_to_chat(207, 'MagianHelper: ' .. text)
end

local function normalize(text)
    return text:match('^%s*(.-)%s*$'):gsub('%s+', ' ')
end

local function find_ws(name)
    name = name:lower()
    for _, ws in pairs(res.weapon_skills) do
        if ws.en and ws.en:lower() == name then
            return ws
        end
    end
end

local function equipped_ws(defaults)
    local items = windower.ffxi.get_items()
    local equipment = items and items.equipment
    if not equipment then return nil end
    -- Preserve main-hand priority when both slots contain mapped weapons.
    -- Never consider the sub slot: offhand weapons do not select the trial WS.
    for _, slot in ipairs({'main', 'range'}) do
        local index, bag = equipment[slot], equipment[slot .. '_bag']
        if index and index ~= 0 and bag ~= nil then
            local item = windower.ffxi.get_items(bag, index)
            local resource = item and res.items[item.id]
            local name = resource and defaults[resource.en]
            if name then return find_ws(name) end
        end
    end
end

local function effective_ws()
    return selected_ws or equipped_ws(weapon_defaults)
end

local function am3_status(player)
    for _, id in pairs(player and player.buffs or {}) do
        if id == AM3_BUFF_ID then
            return true, am3_expires_at and math.max(0, am3_expires_at - os.time())
        end
    end
    return false
end

local function am3_settings()
    return ('AM3: %s; save window: %ss'):format(am3_enabled and 'on' or 'off', tostring(am3_save_seconds))
end

local function combat_settings()
    return ('Auto-engage: %s; auto-face: %s'):format(
        auto_engage and 'on' or 'off', auto_face and 'on' or 'off')
end

local function check_combat()
    if state ~= 'on' then return nil, 'Paused.' end
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return nil, 'Not logged in.' end
    local player = windower.ffxi.get_player()
    if not player or not player.vitals then return nil, 'Player data unavailable.' end
    if (player.vitals.hp or 0) <= 0 then return nil, 'Player is KO.' end
    if player.status ~= 0 and player.status ~= 1 then return nil, 'Player is not idle or engaged.' end
    local target = windower.ffxi.get_mob_by_target('t')
    -- Trusts are NPCs too; spawn type 16 identifies monsters.
    if not target or not target.valid_target or not target.is_npc or target.spawn_type ~= 16 then
        return nil, 'Waiting for a monster as the current target (Cancel clears a friendly target).'
    end
    if not target.hpp or target.hpp <= 0 then return nil, 'Target is dead or HP is unknown.' end
    return target, player.status == 1 and 'Engaged; auto-engage waits.' or 'Idle; ready to attempt engage.', player
end

local function update_combat()
    if not auto_engage and not auto_face then return end
    local target, _, player = check_combat()
    if not target then return end
    if auto_engage and player.status == 0 then
        -- Keep the game's current selection so controller Cancel remains authoritative.
        -- Explicit "on" cannot toggle an engagement off if status changes meanwhile.
        windower.send_command('input /attack on <t>')
    elseif auto_face and player.status == 1 then
        local me = windower.ffxi.get_mob_by_target('me')
        if not me or not me.x or not me.y or not target.x or not target.y then return end
        local dx, dy = target.x - me.x, target.y - me.y
        if dx == 0 and dy == 0 then return end
        windower.ffxi.turn(-math.atan2(dy, dx))
    end
end

-- Use the same live checks for firing and for //mh debug diagnostics.
local function check_ws()
    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return nil, 'Not logged in.' end
    local player = windower.ffxi.get_player()
    local target = windower.ffxi.get_mob_by_target('t')
    local context = ('TP: %s; target: %s; target HP: %s%%. '):format(
        player and player.vitals and player.vitals.tp or 'unknown',
        target and target.name or 'none', target and target.hpp or 'unknown')
    local function blocked(reason) return nil, context .. reason end
    if state ~= 'on' then return blocked('Paused.') end
    if not player or not player.vitals then return blocked('Player data unavailable.') end
    if player.status ~= 1 then return blocked('Not engaged.') end
    if (player.vitals.hp or 0) <= 0 then return blocked('Player is KO.') end
    if not target or not target.valid_target or not target.is_npc then
        return blocked('No valid enemy target.')
    end
    if not target.hpp or target.hpp <= 0 then return blocked('Target is dead or HP is unknown.') end
    local ws = effective_ws()
    local renewing_am3 = false
    local mythic_ws = am3_enabled and equipped_ws(mythic_defaults)
    if mythic_ws then
        local active, remaining = am3_status(player)
        if active and (not remaining or remaining <= am3_save_seconds) then
            -- Buff presence is authoritative, even after its reported timer reaches zero.
            return blocked(remaining and ('Saving TP for AM3; holding until buff wears (%.0fs left).'):format(remaining)
                or 'Holding TP for AM3; waiting for buff duration update.')
        elseif not active then
            if (player.vitals.tp or 0) < 3000 then
                return blocked('Saving for AM3: waiting for 3,000 TP regardless of target HP.')
            end
            ws = mythic_ws
            renewing_am3 = true
        end
    end
    if not renewing_am3 then
        if target.hpp > hp_threshold then return blocked('Target HP is above threshold.') end
        if (player.vitals.tp or 0) < 1000 then return blocked('Waiting for 1,000 TP.') end
    end
    if not ws then return blocked('No weaponskill selected.') end
    local abilities = windower.ffxi.get_abilities()
    for _, id in pairs(abilities and abilities.weapon_skills or {}) do
        if id == ws.id then
            return ws, context .. (renewing_am3 and 'Ready to apply AM3 at 3,000 TP.' or 'Ready to attempt WS.'), target
        end
    end
    return blocked(ws.en .. ' is not in the available weaponskill list.')
end

local function help()
    message('//mh set ws <weaponskill name> | //mh set hp <1-100> | //mh start | //mh pause | //mh info | //mh debug')
    message('//mh set am3 [on/off] | //mh set am3 <seconds>. ' .. am3_settings() .. '.')
    message('//mh set engage [on/off] | //mh set face [on/off]. Omit on/off to toggle. ' .. combat_settings() .. '.')
    message('Use //mh set ws auto to clear your override. State: ' .. state
        .. '; HP: ' .. hp_threshold .. '%; WS: '
        .. (selected_ws and selected_ws.en or 'automatic (Mythic/Relic; main then ranged)') .. '.')
end

windower.register_event('addon command', function(...)
    local args = {...}
    local command = (args[1] or ''):lower()
    if command == 'set' then
        local setting = (args[2] or ''):lower()
        local value = normalize(table.concat(args, ' ', 3))
        -- Windower normally removes quotes; also accept them when preserved.
        if value:sub(1, 1) == '"' and value:sub(-1) == '"' then
            value = normalize(value:sub(2, -2))
        end
        if setting == 'ws' then
            if value:lower() == 'auto' then
                selected_ws = nil
                message('Automatic weaponskill selection enabled.')
            else
                local ws = find_ws(value)
                if not ws then
                    message('Unknown weaponskill. Use its full English name.')
                    return
                end
                selected_ws = ws
                message('Weaponskill set to ' .. ws.en .. '.')
            end
        elseif setting == 'am3' then
            local toggle = value:lower()
            if toggle == '' then
                am3_enabled = not am3_enabled
            elseif toggle == 'on' or toggle == 'off' then
                am3_enabled = toggle == 'on'
            else
                local seconds = tonumber(value)
                if not value:match('^%d+$') or not seconds or seconds == math.huge then
                    message('AM3 must be on, off, or a non-negative integer number of seconds.')
                    return
                end
                am3_save_seconds = seconds
            end
            message(am3_settings() .. '.')
        elseif setting == 'engage' or setting == 'face' then
            local toggle = value:lower()
            if toggle ~= '' and toggle ~= 'on' and toggle ~= 'off' then
                message('Use //mh set ' .. setting .. ' [on/off]; omit on/off to toggle.')
                return
            end
            if setting == 'engage' then
                if toggle == '' then auto_engage = not auto_engage
                else auto_engage = toggle == 'on' end
                message('Auto-engage: ' .. (auto_engage and 'on' or 'off') .. '.')
            else
                if toggle == '' then auto_face = not auto_face
                else auto_face = toggle == 'on' end
                message('Auto-face: ' .. (auto_face and 'on' or 'off') .. '.')
            end
        elseif setting == 'hp' then
            local hp = tonumber(value)
            if not value:match('^%d+$') or not hp or hp < 1 or hp > 100 then
                message('HP must be an integer between 1 and 100.')
                return
            end
            hp_threshold = hp
            message('HP threshold set to ' .. hp .. '%.')
        else
            help()
        end
    elseif command == 'start' and #args == 1 then
        local ws = effective_ws()
        if not ws and not auto_engage and not auto_face then
            message('Set a weaponskill first with //mh set ws <name>, or equip a mapped weapon.')
            return
        end
        if state == 'on' then
            message('Already running.')
            return
        end
        state = 'on'
        last_check = os.clock()
        last_combat_check = last_check
        message('Started.')
    elseif command == 'pause' and #args == 1 then
        state = 'off'
        message('Paused.')
    elseif command == 'info' and #args == 1 then
        local ws = effective_ws()
        message('WS: ' .. (ws and ws.en or 'not set')
            .. (selected_ws and ' (manual)' or ' (automatic)')
            .. '; HP: ' .. hp_threshold .. '%; ' .. am3_settings() .. '; ' .. combat_settings() .. '; state: ' .. state .. '.')
    elseif command == 'debug' and #args == 1 then
        local _, report = check_ws()
        message(report)
        local active, remaining = am3_status(windower.ffxi.get_player())
        message(am3_settings() .. '; buff: ' .. (active and (remaining and ('%.0fs left'):format(remaining) or 'duration unknown') or 'absent')
            .. '; Mythic WS: ' .. ((equipped_ws(mythic_defaults) or {}).en or 'none') .. '.')
        message('Last WS command sent: ' .. last_attempt)
        local _, combat_report = check_combat()
        message(combat_settings() .. '. ' .. combat_report)
    else
        help()
    end
end)

windower.register_event('prerender', function()
    if state ~= 'on' then return end
    local now = os.clock()
    if now - last_combat_check >= 1 then
        last_combat_check = now
        update_combat()
    end
    if now - last_check < 0.5 then return end
    last_check = now

    local ws, _, target = check_ws()
    if not ws then return end
    -- Use the same current target checked above, through FFXI's normal target token.
    windower.send_command(('input /ws "%s" <t>'):format(ws.en))
    last_attempt = ('%s on %s at %d%% HP (threshold %d%%).'):format(
        ws.en, target.name or 'target', target.hpp, hp_threshold)

end)

-- Windower's incoming 0x063/0x09 contains 32 buff IDs and expiration times.
-- See Windower/Lua addons/libs/packets/fields.lua. Times are 60Hz ticks
-- since the game's epoch, wrapping at 2^32; resolve the wrap against now.
local function unsigned_le(data, offset, size)
    local value = 0
    for i = size - 1, 0, -1 do
        value = value * 256 + data:byte(offset + i)
    end
    return value
end

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
    if id ~= 0x063 or injected or blocked or #data < 200 or data:byte(5) ~= 0x09 then return end
    am3_expires_at = nil
    for slot = 0, 31 do
        if unsigned_le(data, 9 + slot * 2, 2) == AM3_BUFF_ID then
            local ticks = unsigned_le(data, 73 + slot * 4, 4)
            local now = os.time()
            local current_ticks = ((now - 1009810800) * 60) % 4294967296
            local delta = (ticks - current_ticks + 2147483648) % 4294967296 - 2147483648
            am3_expires_at = now + delta / 60
            return
        end
    end
end)

windower.register_event('lose buff', function(id)
    if id == AM3_BUFF_ID then am3_expires_at = nil end
end)

windower.register_event('zone change', function()
    am3_expires_at = nil
end)

windower.register_event('logout', function()
    state = 'off'
    am3_expires_at = nil
end)
