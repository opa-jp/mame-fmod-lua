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
		local visible_state = mem:read_u8(0x060808)
		local visible_state2 = mem:read_u8(0x0608d6)
		--MES("data:%02X:%02X",gear,flag)
		if visible_state == 0xff and visible_state2 == 0x00 then
			if gear ~= gear_buf then fmod:play(0xf80) end
			if gear == 0x00 then shifter:set_state(1) end
			if gear == 0x10 then shifter:set_state(0) end
		else
			shifter:set_state(3)
		end
		gear_buf = gear
	end
	set_frame_handlers(set_gear_lay)

	function user.sound_replace(offset, data)
		if data ~= 0x80 then
			--MES("SOUND: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then data = 0x80 end
			--mem:write_u16(0x2607B4, 0x0000)
		end
		return data
	end
	set_write_handlers(":soundcpu", 0xf800, user.sound_replace)
end

return user
