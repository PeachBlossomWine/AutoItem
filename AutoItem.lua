_addon.name = 'AutoItem'
_addon.version = '4.1'
_addon.author = 'PBW'
_addon.commands = {'autoitem','ai'}

require('tables')
require('strings')
require('logger')
require('sets')
require 'lists'
packets = require('packets')
chat = require('chat')
res = require('resources')

active = true
job_registry = T{}
panacea_buffs = S{136,144,149,167}
remedy_buffs = S{4}
allbuffs = remedy_buffs:union(panacea_buffs)
active_buffs = S{}

local __bags = {}
local getBagType = function(access, equippable)
    return S(res.bags):filter(function(key) return (key.access == access and key.equippable == equippable and key.en ~= 'Recycle') or key.id == 0 and key end)
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
		if remedy_buffs:contains(buff_id) and active and player.main_job ~= 'WHM' and (os.time()-attempt) > 4 then
			if haveMeds(4155) and haveBuff(buff_id) then
				windower.add_to_chat(6,"[AutoItem] Using Remedy.")
				windower.send_command('input /item "Remedy" <me>')
				attempt = os.time()
			else
				attempt = os.time()
			end
		elseif panacea_buffs:contains(buff_id) and active and (os.time()-attempt) > 4 then
			if haveMeds(4149) and haveBuff(buff_id) then
				windower.add_to_chat(6,"[AutoItem] Using Panacea.")
				windower.send_command('input /item "Panacea" <me>')
				attempt = os.time()
			else
				attempt = os.time()
			end
		elseif buff_id == 9 and active and player.main_job ~= 'WHM' and (os.time()-attempt) > 4 then
            if haveMeds(4154) and haveBuff(buff_id) then
				windower.add_to_chat(6,"[AutoItem] Using Holy Water.")
				windower.send_command('input /item "Holy Water" <me>')
				attempt = os.time()
            else
				attempt = os.time()
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

-- Credit to partyhints
function set_registry(id, job_id)
    if not id then return false end
    job_registry[id] = job_registry[id] or 'NON'
    job_id = job_id or 0
    if res.jobs[job_id].ens == 'NON' and job_registry[id] and not S{'NON', 'UNK'}:contains(job_registry[id]) then 
        return false
    end
    job_registry[id] = res.jobs[job_id].ens
    return true
end

-- Credit to partyhints
function get_registry(id)
    if job_registry[id] then
        return job_registry[id]
    else
        return 'UNK'
    end
end

-- Find which char has which job
function find_job_charname(job)

	local player = windower.ffxi.get_player()
	for k, v in pairs(windower.ffxi.get_party()) do
		if type(v) == 'table' then
			if v.name ~= player.name then
				ptymember = windower.ffxi.get_mob_by_name(v.name)
				if v.mob ~= nil and ptymember.valid_target then
                    if get_registry(ptymember.id) == job then
                        return v.name
					end
				end
			end
		end
	end
	return 'NoJobFound'
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
	if buff_id and (remedy_buffs:contains(buff_id) or panacea_buffs:contains(buff_id)) then
		active_buffs:remove(buff_id)
		windower.add_to_chat(13,'[AutoItem] Debuff removed: ' .. res.buffs[buff_id].en .. ' - '..'['..buff_id..']')
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
	elseif (id == 0x0DD or id == 0x0DF or id == 0x0C8) then	--Party member update
        local parsed = packets.parse('incoming', data)
		if parsed then
			local playerId = parsed['ID']
			local indexx = parsed['Index']
			local job = parsed['Main job']
			
			if playerId and playerId > 0 then
				set_registry(parsed['ID'], parsed['Main job'])
			end
		end
	elseif id == 0x063 then -- Player buffs for Aura detection : Credit: elii, bp4
		local parsed = packets.parse('incoming', data)
		for i=1, 32 do
			local buff = tonumber(parsed[string.format('Buffs %s', i)]) or 0
			local time = tonumber(parsed[string.format('Time %s', i)]) or 0
			
			if buff > 0 and buff ~= 255 and (panacea_buffs:contains(buff) or remedy_buffs:contains(buff)) then
				if not (math.ceil(1009810800 + (time / 60) + 0x100000000 / 60 * 9) - os.time() == 5) then
					if not (active_buffs:contains(buff)) then
						windower.add_to_chat(1, string.format("%s", ("[AutoItem] Debuff detected: %s - [%s]"):format(res.buffs[buff].en, buff):color(39)))
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
	    end
    end
end

windower.register_event('load', function()
	windower.add_to_chat(262,'[AutoItem] Welcome to AutoItem!')
end)

windower.register_event('addon command',handle_addon)
windower.register_event('lose buff', handle_lose_buff)
windower.register_event('incoming chunk', handle_incoming_chunk)