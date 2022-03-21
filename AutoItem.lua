
_addon.name = 'AutoItem'
_addon.version = '3.6'
_addon.author = 'Kate'
_addon.commands = {'autoitem','ai'}

require('tables')
require('strings')
require('logger')
require('sets')
packets = require('packets')
config = require('config')
chat = require('chat')
res = require('resources')


active = true
SJRestrict = false
gaol_zones = S{279,298}
job_registry = T{}
defaults = {
    remedy_buffs = S{},
    panacea_buffs = S{},
}
settings = config.load(defaults)

allbuffs = {}
n=0
for k,v in pairs(settings.remedy_buffs) do table.insert(allbuffs,k) end
for k,v in pairs(settings.panacea_buffs) do table.insert(allbuffs,k) end
table.insert(allbuffs,"curse")

windower.register_event('gain buff', function(id)
	zone_info = windower.ffxi.get_info()
	local name = res.buffs[id].english

	-- Remedy debuffs
    for key,val in pairs(allbuffs) do
		if val:lower() == name:lower() then
            if settings.remedy_buffs:contains(name:lower()) and active then
				windower.add_to_chat(6,'[AutoItem] Gained remedy buff: ' .. name:lower() .. ' - ' .. id)

				while haveBuff(name:lower()) do
					if haveMeds('remedy') then
						windower.add_to_chat(6,"[AutoItem] Using Remedy.")
						windower.send_command('input /item "Remedy" <me>')
					end
					coroutine.sleep(4.1)
				end
            elseif settings.panacea_buffs:contains(name:lower()) and active and SJRestrict == true and gaol_zones:contains(zone_info.zone) then
				windower.add_to_chat(6,'[AutoItem] Gained panacea buff: ' .. name:lower() .. ' - ' .. id)

				while haveBuff(name:lower()) do
					if haveMeds('panacea') then
						windower.add_to_chat(6,"[AutoItem] Using Panacea.")
						windower.send_command('input /item "Panacea" <me>')
					end
					coroutine.sleep(4.1)
				end
            elseif name:lower() == 'curse' and active and SJRestrict == true and gaol_zones:contains(zone_info.zone) and id == 20 then
                windower.add_to_chat(6,'[AutoItem] Gained sacrifice buff: ' .. name:lower() .. ' - ' .. id)
                        
                while haveBuff("curse") do
                    windower.add_to_chat(6,"[AutoItem] Sending WHM to Sacrifice: " .. find_job_charname('WHM'))
                    windower.send_command('send '..find_job_charname('WHM')..' sacrifice '..windower.ffxi.get_player()["name"])
                    coroutine.sleep(1.3)
                end	

            end
        end
    end
end)

function haveMeds(medication)
	if medication:lower() == 'remedy' then
		check_item_id = 4155
	elseif medication:lower() == 'panacea' then
		check_item_id = 4149
	end
	
	local items = windower.ffxi.get_items()
	for index, item in pairs(items.inventory) do
		if type(item) == 'table' and item.id == check_item_id then
			return true
		end
	end
	windower.add_to_chat(6, '[AutoItem] <<NO>> -' .. medication .. '- Found!')
	return false
end

function haveBuff(...)
	local args = S{...}:map(string.lower)
	local player = windower.ffxi.get_player()
	if (player ~= nil) and (player.buffs ~= nil) then
		for _,bid in pairs(player.buffs) do
			local buff = res.buffs[bid]
			if args:contains(buff.en:lower()) then
				return true
			end
		end
	end
	return false
end

windower.register_event('addon command', function(...)
    local args = {...}
    if args[1] ~= nil then
        local comm = args[1]:lower()
        if comm == 'on' then
            active = true
			windower.add_to_chat(262,"[AutoItem] ON")
        elseif comm == 'off' then
			active = false
            windower.add_to_chat(262,"[AutoItem] OFF")
		elseif comm == 'dd' then
			if defensedown then
				defensedown = false
				windower.add_to_chat(262,"[AutoItem] Defense Down INACTIVE!")
			else
				defensedown = true
				windower.add_to_chat(262,"[AutoItem] Defense Down Activated!")
			end
        end
    end
end)

windower.register_event('load', function()

	windower.add_to_chat(262,'[AutoItem] Welcome to AutoItem!')

	zone_info = windower.ffxi.get_info()
	if gaol_zones:contains(zone_info.zone) then
		local current_buffs = windower.ffxi.get_player()["buffs"]
		coroutine.sleep(5)
		for key,val in pairs(current_buffs) do
			if val == 157 then -- SJ Restriction
				SJRestrict = true
				windower.add_to_chat(262,'[AutoItem] Loaded in Sheol: Gaol')
			end
		end
	end 
end)

windower.register_event('zone change', function(new_id, old_id)
	zone_info = windower.ffxi.get_info()
	coroutine.sleep(10)
	if gaol_zones:contains(zone_info.zone) then
		local current_buffs = windower.ffxi.get_player()["buffs"]

		for key,val in pairs(current_buffs) do
			if val == 157 then -- SJ Restriction
				SJRestrict = true
				windower.add_to_chat(262,'[AutoItem] Entered/zoned in Sheol: Gaol')
			end
		end
	end 
	
	if gaol_zones:contains(old_id) and not gaol_zones:contains(new_id) then
		windower.add_to_chat(262,'[AutoItem] Exiting Sheol: Gaol zones.')
		SJRestrict = false
	end
end)

windower.register_event('incoming chunk', function(id, data)
    if id == 0x028 then	-- Casting
        local action_message = packets.parse('incoming', data)
		if action_message["Category"] == 4 then
			isCasting = false
		elseif action_message["Category"] == 8 then
			isCasting = true
		end
	elseif id == 0x0DF then -- Char update
        local packet = packets.parse('incoming', data)
		if packet then
			local playerId = packet['ID']
			local job = packet['Main job']
			
			if playerId and playerId > 0 then
				set_registry(packet['ID'], packet['Main job'])
			end
		end
	elseif id == 0x0DD then -- Party member update
        local packet = packets.parse('incoming', data)
		if packet then
			local playerId = packet['ID']
			local job = packet['Main job']
			
			if playerId and playerId > 0 then
				set_registry(packet['ID'], packet['Main job'])
			end
		end
	elseif id == 0x0C8 then -- Alliance update
        local packet = packets.parse('incoming', data)
		if packet then
			local playerId = packet['ID']
			local job = packet['Main job']
			
			if playerId and playerId > 0 then
				set_registry(packet['ID'], packet['Main job'])
			end
		end
	end
end)

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