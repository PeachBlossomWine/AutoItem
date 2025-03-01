_addon.name = 'AutoItem'
_addon.version = '4.1'
_addon.author = 'PBW'
_addon.commands = {'autoitem','ai'}

require('tables')
require('strings')
require('logger')
require('sets')
require('lists')
packets = require('packets')
chat = require('chat')
res = require('resources')

active = true
panacea = false
dot = false
job_registry = T{}
panacea_buffs = S{12,13,134,136,144,145,146,147,149,167}	-- Weight, Slow, Dia, STR Down, Max HP Down, Max MP Down, Attack Down, Accuracy Down, Defense Down, Magic Def. Down
dot_buffs = S{128,129,130,131,132,133} -- Burn, Frost, Choke, Rasp, Shock, Drown
remedy_buffs = S{4,8}	-- Paralysis, Disease
antidote_buffs = S{3} -- Poison
holywater_buffs = S{9}	-- Curse
doom_buffs = S{15}
allbuffs = remedy_buffs:union(panacea_buffs):union(holywater_buffs):union(dot_buffs):union(doom_buffs):union(antidote_buffs)
active_buffs = S{}

local __bags = {}
local getBagType = function(access, equippable)
    return S(res.bags):filter(function(key) return (key.access == access and key.en ~= 'Recycle' and (not key.equippable or key.equippable == equippable)) or key.id == 0 and key end)
end

do -- Setup Bags.
    __bags.usable = T(getBagType('Everywhere', false))
end

local attempt = 0
function use_meds_check()

	if not active_buffs then return end
	local player = windower.ffxi.get_player()

	-- Remedy debuffs
    for buff_id,_ in pairs (active_buffs) do
		if doom_buffs:contains(buff_id) and (os.clock()-attempt) > 1.5 and (player.main_job ~= 'WHM' or (player.main_job == 'WHM' and windower.ffxi.get_spell_recasts()[20] > 0)) then
            if haveBuff(buff_id) and haveMeds(4154) then
				windower.add_to_chat(6,"[AutoItem] DOOMED - Using Holy Water.")
				windower.send_command('input /item "Holy Water" <me>')
				attempt = os.clock()
            else
				active_buffs:remove(buff_id)
				attempt = os.clock()
			end
		elseif active and remedy_buffs:contains(buff_id) and (os.clock()-attempt) > 2.5 then
			if haveBuff(buff_id) and haveMeds(4155) then
				windower.add_to_chat(6,"[AutoItem] Using Remedy.")
				windower.send_command('input /item "Remedy" <me>')
				attempt = os.clock()
			else
				active_buffs:remove(buff_id)
				attempt = os.clock()
			end
		elseif active and antidote_buffs:contains(buff_id) and (os.clock()-attempt) > 2.5 then
			if haveBuff(buff_id) and haveMeds(4148) then
				windower.add_to_chat(6,"[AutoItem] Using Antidote.")
				windower.send_command('input /item "Antidote" <me>')
				attempt = os.clock()
			else
				active_buffs:remove(buff_id)
				attempt = os.clock()
			end
		elseif active and ((panacea and panacea_buffs:contains(buff_id)) or (dot and dot_buffs:contains(buff_id))) and (os.clock()-attempt) > 3.5 then
			if haveBuff(buff_id) and haveMeds(4149) then
				windower.add_to_chat(6,"[AutoItem] Using Panacea.")
				windower.send_command('input /item "Panacea" <me>')
				attempt = os.clock()
			else
				active_buffs:remove(buff_id)
				attempt = os.clock()
			end
		elseif active and holywater_buffs:contains(buff_id) and player.main_job ~= 'WHM' and (os.clock()-attempt) > 3.5 then
            if haveBuff(buff_id) and haveMeds(4154) then
				windower.add_to_chat(6,"[AutoItem] Using Holy Water.")
				windower.send_command('input /item "Holy Water" <me>')
				attempt = os.clock()
            else
				active_buffs:remove(buff_id)
				attempt = os.clock()
			end
		end
	end
	return
end
	
function haveMeds(med_id)
	for bag in T(__bags.usable):it() do
		for item, index in T(windower.ffxi.get_items(bag.id)):it() do
			if type(item) == 'table' and item.id == med_id then
				return true
			end
		end
	end
	
	windower.add_to_chat(3, '[AutoItem] <<NO>> -' .. res.items[med_id].en .. '- Found!')
	return false
end

function haveBuff(buff_id)
	local player = windower.ffxi.get_player()
	if (player and player.buffs) then
		for _,bid in pairs(player.buffs) do
			if buff_id == bid then
				return true
			end
		end
	end
	return false
end

local last_render = 0
local delay = 0.5
windower.register_event('prerender', function()

  if (os.clock()-last_render) > delay then
    use_meds_check()
    last_render = os.clock()

  end

end)

function handle_lose_buff(buff_id)
	if buff_id and allbuffs:contains(buff_id) then
		active_buffs:remove(buff_id)
		if panacea and active and (panacea_buffs:contains(buff_id) or dot_buffs:contains(buff_id)) then
			windower.add_to_chat(13,'[AutoItem] Debuff removed: ' .. res.buffs[buff_id].en .. ' - '..'['..buff_id..']')
		elseif active and (remedy_buffs:contains(buff_id) or holywater_buffs:contains(buff_id)) then
			windower.add_to_chat(13,'[AutoItem] Debuff removed: ' .. res.buffs[buff_id].en .. ' - '..'['..buff_id..']')
		end
	end
end	

function handle_incoming_chunk(id, data)
    if id == 0x028 then	-- Casting
        local action_message = packets.parse('incoming', data)
		if action_message["Category"] == 4 then
			isCasting = false
		elseif action_message["Category"] == 8 then
			isCasting = true
		end
	elseif id == 0x063 then -- Player buffs for Aura detection : Credit: elii, bp4
		local parsed = packets.parse('incoming', data)
		for i=1, 32 do
			local buff = tonumber(parsed[string.format('Buffs %s', i)]) or 0
			local our_time = tonumber(parsed[string.format('Time %s', i)]) or 0
			
			if buff > 0 and buff ~= 255 and allbuffs:contains(buff) then
				if buff == 15 or math.ceil(1009810800 + (our_time / 60) + 0x100000000 / 60 * 10) - os.time() > 5 then
					if not (active_buffs:contains(buff)) then
						if doom_buffs:contains(buff) then
							windower.add_to_chat(1, string.format("%s", ("[AutoItem] Debuff detected: %s - [%s]"):format(res.buffs[buff].en, buff):color(39)))
						elseif active and (panacea and panacea_buffs:contains(buff)) or (dot and dot_buffs:contains(buff)) then
							windower.add_to_chat(1, string.format("%s", ("[AutoItem] Debuff detected: %s - [%s]"):format(res.buffs[buff].en, buff):color(39)))
						elseif active and (remedy_buffs:contains(buff) or holywater_buffs:contains(buff) or antidote_buffs:contains(buff)) then
							windower.add_to_chat(1, string.format("%s", ("[AutoItem] Debuff detected: %s - [%s]"):format(res.buffs[buff].en, buff):color(39)))
						end
						active_buffs:add(buff)
					end
				end
			end
		end
	end
end
	
function handle_addon(...)
    local args = {...}
    if args[1] ~= nil then
        local comm = args[1]:lower()
        if comm == 'on' then
            active = true
			windower.add_to_chat(262,"[AutoItem] ON")
        elseif comm == 'off' then
			active = false
            windower.add_to_chat(262,"[AutoItem] OFF")
		elseif comm == 'pana' then
			if args[2] and args[2]:lower() == 'on' then
				panacea = true
				windower.add_to_chat(262,"[AutoItem] Panacea ON")
			elseif args[2] and args[2]:lower() == 'off' then
				panacea = false
				windower.add_to_chat(262,"[AutoItem] Panacea OFF")
			else
				windower.add_to_chat(262,"[AutoItem] No parameter specified.")
			end
		elseif comm == 'dot' then
			if args[2] and args[2]:lower() == 'on' then
				dot = true
				windower.add_to_chat(262,"[AutoItem] DoT ON")
			elseif args[2] and args[2]:lower() == 'off' then
				dot = false
				windower.add_to_chat(262,"[AutoItem] DoT OFF")
			else
				windower.add_to_chat(262,"[AutoItem] No parameter specified.")
			end
		elseif comm == 'show' then
			for k,v in pairs(active_buffs) do
				windower.add_to_chat(13,'Active Buffs: '..k)
			end
	    end
    end
end

windower.register_event('load', function()
	windower.add_to_chat(262,'[AutoItem] Welcome to AutoItem!')
end)

function handle_zone_change(new_id, old_id)
	if panacea then
		windower.add_to_chat(262,'[AutoItem] Disabling Auto-Panacea.')
		panacea = false
	end
end

windower.register_event('addon command',handle_addon)
windower.register_event('lose buff', handle_lose_buff)
windower.register_event('incoming chunk', handle_incoming_chunk)
windower.register_event('zone change', handle_zone_change)