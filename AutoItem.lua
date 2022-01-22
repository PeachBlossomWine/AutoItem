
_addon.name = 'AutoItem'
_addon.version = '3.0'
_addon.author = 'Kate'
_addon.commands = {'autoitem','ai'}

require('tables')
require('strings')
require('logger')
require('sets')
config = require('config')
chat = require('chat')
res = require('resources')

defaults = {

	buffs = S{"paralysis","STR Down","curse","max hp down","plague","defense down"},

}

settings = config.load(defaults)
active = true
defensedown = false

gaol_zones = S{279,298}
SJRestrict = false

-- item_remedy = {
	-- [1] = {id=4155,japanese="万能薬",english="Remedy"},
-- }

-- item_panacea = {
	-- [1] = {id=4149,japanese="パナケイア",english="Panacea"},
-- }


windower.register_event('gain buff', function(id)
	zone_info = windower.ffxi.get_info()
	local name = res.buffs[id].english

    for key,val in pairs(settings.buffs) do
		if key:lower() == name:lower() then
			-- Remedy debuffs
            if name:lower() == 'paralysis' and active then
				windower.add_to_chat(6,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)

				while haveBuff(name:lower()) do
					if haveMeds('remedy') then
						windower.add_to_chat(6,"[AutoItem] Using Remedy.")
						windower.send_command('input /item "Remedy" '..windower.ffxi.get_player()["name"])
					end
					coroutine.sleep(3.8)
				end
			-- MAX HP DOWN
			elseif name:lower() == 'max hp down' and active and SJRestrict == true and gaol_zones:contains(zone_info.zone) then
				windower.add_to_chat(6,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)

				while haveBuff("max hp down") do
					if haveMeds('panacea') then
						windower.add_to_chat(6,"[AutoItem] Using Panacea.")
						windower.send_command('input /item "Panacea" '..windower.ffxi.get_player()["name"])
					end
					coroutine.sleep(3.8)
				end				
			-- STAT DOWN
			elseif name:lower() == 'str down' and active and SJRestrict == true and gaol_zones:contains(zone_info.zone) then
				windower.add_to_chat(6,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)

				while haveBuff("str down") do
					if haveMeds('panacea') then
						windower.add_to_chat(6,"[AutoItem] Using Panacea.")
						windower.send_command('input /item "Panacea" '..windower.ffxi.get_player()["name"])
					end
					coroutine.sleep(3.8)
				end
			-- Plague
			elseif name:lower() == 'plague' and active and SJRestrict == true and gaol_zones:contains(zone_info.zone) then
				windower.add_to_chat(6,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)

				while haveBuff("plague") do
					if haveMeds('remedy') then
						windower.add_to_chat(6,"[AutoItem] Using Remedy.")
						windower.send_command('input /item "Remedy" '..windower.ffxi.get_player()["name"])
					end
					coroutine.sleep(3.8)
				end
			-- ST20 Curse
			elseif name:lower() == 'curse' and active and SJRestrict == true and gaol_zones:contains(zone_info.zone) and id == 20 then
				windower.add_to_chat(6,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)
				
				while haveBuff("curse") do
					windower.add_to_chat(6,"[AutoItem] Sending WHM to Sacrifice: " .. settings.whmplayer)
					windower.send_command('send '.. settings.whmplayer .. ' sacrifice ' ..windower.ffxi.get_player()["name"])
					coroutine.sleep(1.3)
				end	
			-- Defense Down
			elseif name:lower() == 'defense down' and active and defensedown and SJRestrict == true and gaol_zones:contains(zone_info.zone) then
				windower.add_to_chat(6,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)

				while haveBuff("defense down") do
					if haveMeds('panacea') then
						windower.add_to_chat(6,"[AutoItem] Using Panacea.")
						windower.send_command('input /item "Panacea" '..windower.ffxi.get_player()["name"])
					end
					coroutine.sleep(3.8)
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