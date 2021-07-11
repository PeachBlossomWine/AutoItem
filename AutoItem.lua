
_addon.name = 'AutoItem'
_addon.version = '2.6'
_addon.author = 'Kate'
_addon.command = 'autoitem'

require('tables')
require('strings')
require('logger')
require('sets')
config = require('config')
chat = require('chat')
res = require('resources')

defaults = {

	buffs = S{"paralysis","STR Down","curse"}
}

settings = config.load(defaults)
active = true

gaol_zones = S{279,298}
SJRestrict = false

item_remedy = {
	[1] = {id=4155,japanese="万能薬",english="Remedy"},
}

item_panacea = {
	[1] = {id=4149,japanese="パナケイア",english="Panacea"},
}


windower.register_event('gain buff', function(id)
	
	item_array = {}
    bags = {0}
    get_items = windower.ffxi.get_items
	
    for _,item in ipairs(get_items(0)) do
		if item.id > 0 then
			item_array[item.id] = item
			item_array[item.id].bag = 0
		end
	end

    local name = res.buffs[id].english
    for key,val in pairs(settings.buffs) do

        if key:lower() == name:lower() then
			-- Paralyzed
            if name:lower() == 'paralysis' and active then
				windower.add_to_chat(123,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)
				local StillPara = true
				
				while StillPara do
					CurBuffs = windower.ffxi.get_player()["buffs"]
					
					StillPara = false
					
					for key,val in pairs(CurBuffs) do
						if val == 4 then
							StillPara = true
						end
					end
					
					if StillPara == true then
						for index,stats in pairs(item_remedy) do
							para_remedy = item_array[stats.id]
						end
						
						if para_remedy then
							windower.add_to_chat(6,"[AutoItem] Using Remedy.")
							windower.send_command('input /item "Remedy" '..windower.ffxi.get_player()["name"])
						else
							windower.add_to_chat(123,"[AutoItem] No REMEDIES!")
							StillPara = false
						end
					end
					coroutine.sleep(3.8)
				end
			-- Panacea
			elseif name:lower() == 'str down' and active and SJRestrict == true then
				windower.add_to_chat(123,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)
				local StillDebuffed = true
				
				while StillDebuffed do
					CurBuffs = windower.ffxi.get_player()["buffs"]
					
					StillDebuffed = false
					
					for key,val in pairs(CurBuffs) do
						if val == 136 then
							StillDebuffed = true
						end
					end
					
					if StillDebuffed == true then
												
						for index,stats in pairs(item_panacea) do
							panaceas = item_array[stats.id]
						end
						if panaceas then        				
							windower.add_to_chat(6,"[AutoItem] Using Panacea.")
							windower.send_command('input /item "Panacea" '..windower.ffxi.get_player()["name"])
						else
							windower.add_to_chat(123,"[AutoItem] No PANACEA!")
							StillDebuffed = false
						end
						
					end
					coroutine.sleep(3.8)
				end
			elseif name:lower() == 'curse' and active then
				windower.add_to_chat(123,'[AutoItem] Gained buff: ' .. name:lower() .. '- ' .. key)
				local StillST20 = true
				
				while StillST20 do
					CurBuffs = windower.ffxi.get_player()["buffs"]
					
					StillST20 = false
					
					for key,val in pairs(CurBuffs) do
						if val == 20 then
							StillST20 = true
						end
					end
					
					if StillST20 == true then
						windower.add_to_chat(6,"[AutoItem] Sending WHM to Sacrifice: " .. settings.whmplayer)
						windower.send_command('send '.. settings.whmplayer .. ' sacrifice ' ..windower.ffxi.get_player()["name"])
					end
					coroutine.sleep(1.2)
				end
			
            end -- elseif
			
        end
    end -- for loops
end)

windower.register_event('addon command', function(...)
    local args = {...}
    if args[1] ~= nil then
        local comm = args[1]:lower()
        if comm == 'on' then
            active = true
			windower.add_to_chat(122,"AutoItem ON")
        elseif comm == 'off' then
			active = false
            windower.add_to_chat(122,"AutoItem OFF")
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