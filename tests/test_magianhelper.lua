-- Run from the addon directory: lua tests/test_magianhelper.lua
local events, sent, messages = {}, {}, {}
local now = 0
os.clock = function() return now end
_addon = {}
local resources = {
    items = {[1] = {en = 'Burtgang'}, [2] = {en = 'Other sword'}},
    weapon_skills = {
        [1] = {id = 1, en = 'Atonement'},
        [2] = {id = 2, en = 'Savage Blade'},
    },
}
package.preload.resources = function() return resources end
local player = {status = 1, vitals = {hp = 100, tp = 1000}}
local target = {id = 12345, valid_target = true, is_npc = true, hpp = 100}
local equipment = {main = 5, main_bag = 8}
local item = {id = 2}
local ranged_item = {id = 3}
local available = {1, 2}
local logged_in = true
local target_index = 7
windower = {
    register_event = function(event, callback) events[event] = callback end,
    add_to_chat = function(_, text) messages[#messages + 1] = text end,
    send_command = function(text) sent[#sent + 1] = text end,
    ffxi = {
        get_info = function() return {logged_in = logged_in} end,
        get_player = function() return player end,
        get_mob_by_target = function(name)
            assert(name == 'me')
            return {target_index = target_index}
        end,
        get_mob_by_index = function(index) assert(index == 7); return target end,
        get_items = function(bag, slot)
            if bag == nil then return {equipment = equipment} end
            if bag == equipment.range_bag and slot == equipment.range then return ranged_item end
            assert(bag == equipment.main_bag and slot == equipment.main)
            return item
        end,
        get_abilities = function() return {weapon_skills = available} end,
    },
}
dofile('MagianHelper.lua')
local function cmd(...) events['addon command'](...) end
local function tick(delta) now = now + (delta or 1); events.prerender() end
local function count(n) assert(#sent == n, 'Expected ' .. n .. ' sends, got ' .. #sent) end
local checks = 0
local function no_send(change, restore)
    local before = #sent
    change(); tick(); count(before); restore()
    checks = checks + 1
end
-- Default off, and start blocked without either kind of selection.
tick(); count(0)
cmd('start'); tick(); count(0)
-- Automatic selection, delayed first check, no duplicated timer after start.
item.id = 1
cmd('start'); tick(0.5); count(0)
cmd('start'); tick(0.5); count(1)
assert(sent[1] == 'input /ws "Atonement" 12345')
tick(0); count(1)
-- Inclusive threshold and invalid inputs leave the previous value intact.
cmd('set', 'hp', '25'); target.hpp = 26; tick(); count(1)
for _, value in ipairs({'0', '101', '-1', '25.5', 'abc', '1e1', ''}) do
    cmd('set', 'hp', value); tick(); count(1)
end
target.hpp = 25; tick(); count(2)
-- Explicit multiword WS overrides main-hand detection and survives bad names.
cmd('set', 'ws', 'savage', 'blade'); tick(); count(3)
assert(sent[3] == 'input /ws "Savage Blade" 12345')
cmd('set', 'ws', 'bogus; quit'); tick(); count(4)
assert(sent[4] == sent[3])
item.id = 2; tick(); count(5)
-- Combat eligibility gates.
no_send(function() player.status = 0 end, function() player.status = 1 end)
no_send(function() player.vitals.tp = 999 end, function() player.vitals.tp = 1000 end)
no_send(function() player.vitals.hp = 0 end, function() player.vitals.hp = 100 end)
no_send(function() target.hpp = 0 end, function() target.hpp = 25 end)
no_send(function() target.valid_target = false end, function() target.valid_target = true end)
no_send(function() target.is_npc = false end, function() target.is_npc = true end)
no_send(function() logged_in = false end, function() logged_in = true end)
no_send(function() target_index = 0 end, function() target_index = 7 end)
no_send(function() available = {1} end, function() available = {1, 2} end)
local old_target = target
no_send(function() target = nil end, function() target = old_target end)
-- Automatic selection tracks changes, including bag 0 (inventory).
cmd('set', 'ws', 'auto'); tick(); count(5)
item.id = 1; equipment.main_bag = 0; tick(); count(6)
assert(sent[6] == sent[1])
no_send(function() equipment.main = 0 end, function() equipment.main = 5 end)
-- Pause, repeated use after resume, and logout.
cmd('pause'); tick(); count(6)
cmd('start'); tick(); count(7); tick(); count(8)
events.logout(); tick(); count(8)
cmd('set', 'ws', '"Savage Blade"'); cmd('start'); tick(); count(9)
assert(sent[9] == sent[3])
-- Ranged fallback, main-hand priority, and manual override priority.
resources.items[3] = {en = 'Death Penalty'}
resources.weapon_skills[3] = {id = 3, en = 'Leaden Salute', targets = 32}
available = {1, 2, 3}
equipment.range = 9; equipment.range_bag = 16
cmd('set', 'ws', 'auto'); item.id = 2; tick(); count(10)
assert(sent[10] == 'input /ws "Leaden Salute" 12345')
item.id = 1; tick(); count(11)
assert(sent[11] == sent[1])
cmd('set', 'ws', 'Savage Blade'); tick(); count(12)
assert(sent[12] == sent[3])
cmd('set', 'ws', 'auto')
-- Ranged weapon is found even with no main-hand weapon equipped.
equipment.main = 0; tick(); count(13)
assert(sent[13] == sent[10])
equipment.main = 5
-- An unavailable main-hand WS does not silently switch to a ranged trial WS.
available = {3}; tick(); count(13); available = {1, 2, 3}
-- Empyrean weapons are deliberately unmapped.
resources.items[4] = {en = 'Hvergelmir'}
item.id = 4; equipment.range = 0; tick(); count(13)
equipment.range = 9
-- Missing bag data and unmapped instruments do not cause a WS attempt.
item.id = 2; resources.items[3].en = 'Gjallarhorn'; tick(); count(13)
resources.items[3].en = 'Death Penalty'
equipment.range_bag = nil; tick(); count(13)
print('Passed command, timing, automatic selection, pause/logout, and ' .. checks .. ' eligibility checks.')
