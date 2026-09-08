_addon.name = 'MagianHelper'
_addon.author = 'mcgee'
_addon.version = '1.2.0'
_addon.commands = {'mh', 'magianhelper'}

local res = require('resources')

local state = 'off'
local hp_threshold = 100
local selected_ws = nil
local last_check = os.clock()

-- Add exact English item names and weaponskill names here as needed.
-- Matching by name covers upgrade stages that retain the same item name.
-- Shields and instruments have no associated WS and are intentionally omitted.
local weapon_defaults = {
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

local function effective_ws()
    if selected_ws then
        return selected_ws
    end
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
            local name = resource and weapon_defaults[resource.en]
            if name then return find_ws(name) end
        end
    end
end

local function help()
    message('//mh set ws <weaponskill name> | //mh set hp <1-100> | //mh start | //mh pause | //mh info')
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
        if not ws then
            message('Set a weaponskill first with //mh set ws <name>, or equip a mapped weapon.')
            return
        end
        if state == 'on' then
            message('Already running.')
            return
        end
        state = 'on'
        last_check = os.clock()
        message('Started: ' .. ws.en .. ' at or below ' .. hp_threshold .. '% HP.')
    elseif command == 'pause' and #args == 1 then
        state = 'off'
        message('Paused.')
    elseif command == 'info' and #args == 1 then
        local ws = effective_ws()
        message('WS: ' .. (ws and ws.en or 'not set')
            .. (selected_ws and ' (manual)' or ' (automatic)')
            .. '; HP: ' .. hp_threshold .. '%.')
    else
        help()
    end
end)

windower.register_event('prerender', function()
    if state ~= 'on' then return end
    local now = os.clock()
    if now - last_check < 1 then return end
    last_check = now

    local info = windower.ffxi.get_info()
    if not info or not info.logged_in then return end
    local player = windower.ffxi.get_player()
    if not player or player.status ~= 1 or not player.vitals
        or (player.vitals.hp or 0) <= 0 or (player.vitals.tp or 0) < 1000 then
        return
    end
    -- Resolve the engaged player's target, not a party member's battle target.
    local me = windower.ffxi.get_mob_by_target('me')
    if not me or not me.target_index or me.target_index == 0 then return end
    local target = windower.ffxi.get_mob_by_index(me.target_index)
    if not target or not target.valid_target or not target.is_npc
        or not target.hpp or target.hpp <= 0 or target.hpp > hp_threshold then
        return
    end
    local ws = effective_ws()
    if not ws then return end
    local abilities = windower.ffxi.get_abilities()
    for _, id in pairs(abilities and abilities.weapon_skills or {}) do
        if id == ws.id then
            -- An explicit ID keeps the command aimed at the enemy just checked.
            windower.send_command(('input /ws "%s" %d'):format(ws.en, target.id))
            return
        end
    end
end)

windower.register_event('logout', function()
    state = 'off'
end)

windower.register_event('load', function()
    message('Loaded and paused. HP threshold: 100%. Use //mh for commands.')
end)
