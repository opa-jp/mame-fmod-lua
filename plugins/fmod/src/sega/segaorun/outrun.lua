local user = {}

function user.init()
	print("user script ok.")

	local target = manager.machine.render.targets[1]
	local view = target.current_view
	local shifter = view.items["shifter"]

	local mem = manager.machine.devices[":maincpu"].spaces["program"]

	local gear_buf = 0
	local function set_gear_lay()
		local gear = mem:read_u8(0x260074) & 0x10
		local flag = mem:read_u8(0x060808)
		--MES("data:%02X:%02X",gear,flag)
		if flag == 0xff then
			if gear ~= gear_buf then fmod:play(0xf80) end
			if gear == 0x00 then shifter:set_state(1) end
			if gear == 0x10 then shifter:set_state(0) end
		else
			shifter:set_state(3)
		end
		gear_buf = gear
	end
	set_frame_handlers(set_gear_lay)

	local function sound_replace(offset, data)
		if data ~= 0x80 then
			--MES("SOUND: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then data = 0x80 end
		end
		return data
	end
	set_write_handlers(":soundcpu", 0xf800, sound_replace)

end

return user
