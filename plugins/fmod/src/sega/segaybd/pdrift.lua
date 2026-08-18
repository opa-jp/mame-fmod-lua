local user = {}

function user.init()
	print("user script ok.")

	--fmod:log(1)

	local vo_conv = {
		[0xc0] = { s = 0xb7 },
		[0xbc] = { s = 0xaf },
		[0xc3] = { s = 0xbd },
		[0xbf] = { s = 0xbe },
		[0xb6] = { s = 0xb5 },
		[0xc1] = { s = 0xae }
	}
	local frame_done_handle = nil
	local is_running = true
	local pending_sound = nil
	local deley_count = 0
	local cpu = manager.machine.devices[":maincpu"]
	local mem = cpu.spaces["program"]
	local addr = 0x082000
	local gear_buf = 0
	local player_vo = { [0xb6]=true, [0xbc]=true, [0xbf]=true, [0xc0]=true, [0xc1]=true, [0xc3]=true }


	function send_delayed(data)
		pending_sound = data
		deley_count = 1
	end

	frame_done_handle = emu.register_frame_done(function()
		if not is_running then return end
		if (deley_count > 0) then deley_count = deley_count - 1 end
		if pending_sound ~= nil then
			local data = (pending_sound << 8) | pending_sound
			pcall(function()
				mem:write_u16(addr, data)
			end)
			--print(string.format("Delayed Play: 0x%02X", pending_sound))
			pending_sound = nil
		end
		if (mem and xvib) then
			local vibrator_switch = mem:read_u8(0xce09d)
			local tilts = mem:read_u8(0xc08bd)
			if vibrator_switch == 0x14 and tilts > 0 then
				local p = tilts / 127
				xvib:rumble(0xFFFC, p/2, 0.25)
			end
		end
		local gear = mem:read_u8(0x100003) & 0xe0
		if gear_buf ~= gear then
			if gear == 0xe0 or gear == 0xc0 then fmod:play(0xf80) end
		end
		gear_buf = gear
	end)

	emu.register_stop(function()
		is_running = false
		if frame_done_handle then
			frame_done_handle:remove()
			frame_done_handle = nil
		end
	end)

	local function sound_replace(offset, data)
		local s = data & 0xFF
		local player = mem:read_u8(0xce311)
		--print(string.format("D:%02X P:%02X", data, player))
		xvib:play(s)
		if player_vo[s] then
			local cv = (player << 8) | s
			print(string.format("vo:%04X", cv))
			if (fmod:play(cv) == 1) then s = 0x80 end
		end
		if player == 0x07 or player == 0x08 then
			if s == 0x89 then
				local cv = (player << 8) | 0xbc
				if (fmod:play(cv) ~= 1) then
					if (fmod:play(0xaf) ~= 1) then send_delayed(0xaf) end
				end
			end
			if s ~= 0x80 and vo_conv[s] then
				s = vo_conv[s].s
			end
		end
		if (s ~= 0x80 and fmod:play(s) == 1) then s = 0x80 end
		s = (s << 8) | s
		return s
	end

	set_write_handler(":maincpu", addr, sound_replace)

end

return user
