local user = {}

function user.init()
	print("user script ok.")

	-- fmod:log(1) -- FMOD operation verification log

	local mem = manager.machine.devices[":mainpcb:maincpu"].spaces["program"]

	local bgm_old_ch = 0
	local bgm_next_ch = 0
	local fadein_flag = false
	local cross_fade_time = 0.5
	local stage_bak = 0
	local speed_reduce = false

	local function sound_replace(offset, data, mask)
		local stage = mem:read_u8(0x201a2e)

		if offset == 0x00e01c then return end
		--if data ~= 0x80 and data ~= 0x00 then MES("D:%02X O:%06X M:%04X", data, offset, mask) end
		if data == 0x94 or data == 0x91 then speed_reduce = true end

		if stage_bak ~= stage then
			local stage_bgm = 0x0100 + stage
			if fmod:is_samples(stage_bgm) == 1 or fmod:is_samples(stage_bgm) == 2 then
			--MES("bgm:%04X",stage_bgm)
				bgm_next_ch = fmod:get_channel(stage_bgm)
				if bgm_old_ch ~= bgm_next_ch then
					if fmod:is_playing(bgm_old_ch) then
						fadein_flag = true
						fmod:fade_out(bgm_old_ch, cross_fade_time*1.5)
					end
				end
				bgm_old_ch = bgm_next_ch
				if fmod:play(stage_bgm) == 1 then
					if fadein_flag then
						fmod:fade_in(bgm_next_ch, cross_fade_time, fmod:get_volume(stage_bgm))
						fadein_flag = false
					end
				end
			end
		end
		stage_bak = stage

		if data == 0x83 then fmod:stop(1) fmod:stop(2) end
		if data >= 0x81 and data <= 0x8f then
			if fmod:is_samples(data) == 1 or fmod:is_samples(data) == 2 then
				bgm_next_ch = fmod:get_channel(data)
				if bgm_old_ch ~= bgm_next_ch then
					fadein_flag = true
					fmod:fade_out(bgm_old_ch, cross_fade_time*1.5)
				end
				bgm_old_ch = bgm_next_ch
			end
		end

		xvib:play(data)
		if fmod:play(data) == 1 then
			if fadein_flag then
				fmod:fade_in(bgm_next_ch, cross_fade_time, fmod:get_volume(data))
				fadein_flag = false
			end
			return 0x80
		end
	end
	set_read_handlers(":mainpcb:soundcpu", 0xe000, sound_replace)

	local ports = manager.machine.ioport.ports
	local WHEEL_PORT_TAG = ":mainpcb:ANALOG1"
	local wheel_port = ports[WHEEL_PORT_TAG]
	local function wheel_fix()
		if wheel_port then
			local wheel_value = wheel_port:read()
			--MES("wheel:%02X",wheel_value)
			mem:write_u8(0x20f02c,wheel_value)
		end
	end
	set_frame_handlers(wheel_fix)

	local STARTBUTTON_PORT_TAG = ":mainpcb:SERVICE12_A"
	local GASPEDAL_PORT_TAG = ":mainpcb:ANALOG2"
	local STARTBUTTON_BIT_MASK = 0x10
	local startbuttton_port = ports[STARTBUTTON_PORT_TAG]
	local gaspedal_port = ports[GASPEDAL_PORT_TAG]
	local max_speed = 0x5fff
	local speed = 0
	local stb = 0
	local tbon = false
	local speed_raw = 0

	local function speed_cheat()
		speed_raw = mem:read_u16(0x20F4A0)
		--MES("tick:%04X",tick)
		--speed = mem:read_u16(0x207F60)
		--MES("sp:%d",speed_raw)
		MES("raw:%d sp:%04X",speed_raw, speed)

		if startbuttton_port and gaspedal_port then
			local gpl = gaspedal_port:read()
			stb = ((startbuttton_port:read()&STARTBUTTON_BIT_MASK)>>4)~1
			tbon = false
			if stb == 1 and gpl > 250 then
				--if speed > 20 then speed = max_speed end
				if speed_raw > 405 then
					local cource_out = mem:read_u8(0x201F79)
					if cource_out == 0x00 then
						speed = speed + 0x0018
					else
						speed_reduce = true
					end
					tbon = true
				end
				--if speed_reduce then
				--	if speed > 0x1DB3 then speed = 0x1DB3 end
				--	speed_reduce = false
				--end
				if speed > max_speed then speed = max_speed end
				--mem:write_u8(0x207F60,speed)
				--mem:write_u8(0x20E9B4,0x6F)
				--MES("s:%04X",speed)
				return
			end
		end
	end
	set_frame_handlers(speed_cheat)

	function engine_se_replace(offset, data, mask)
		local se_add = (speed&0xff00)
		--local engine_se = mem:read_u8(0x20E9B4)
		--MES("sp:%d se:%02X",speed, data)
		if stb == 1 and tbon then
			--MES("s:%04X",data)
			if speed_raw < 320 then
				return data - 0x2000
			end
			return data + se_add
		end
	end
	set_read_handlers(":mainpcb:maincpu", 0x20E9B4, engine_se_replace)

	function speed_replace(offset, data, mask)
		if stb == 1 and tbon then
			if speed_reduce then
				speed_reduce = false
			else
				data = speed
			end
			--if data > 0x2f4f then data = 0x2f4f end -- speed limit
		end
		return data
	end
	set_read_handlers(":mainpcb:maincpu", 0x207F60, speed_replace)

	local cpu = manager.machine.devices[":mainpcb:maincpu"]
	function wheel_value(offset, data, mask)
		speed = mem:read_u16(0x207F60)
		local PC = cpu.state["PC"].value
		local R9 = cpu.state["R9"].value
		local R3 = cpu.state["R3"].value
		local R1 = cpu.state["R1"].value
		--MES("Speed:%04X PC:%06X R9:%04X R3:%04X R1:%04X",speed,PC,R9,R3,R1)
		if speed > 0x2f4f then
			if R3 > 0x7fff then cpu.state["R3"].value = R3 & 0x7fff end
		end
	end
	set_read_handlers(":mainpcb:maincpu", 0x072B12, wheel_value)

	local jump_rumble_buf = 0
	function jump_rumble(offset, data, mask)
		if data > 0 then
			local rumble = data&0xff
			rumble = (rumble * 0xff)/1.5/0xffff
			xvib:rumble(0xfff8, rumble, rumble, 200)
			--MES("D:%04X R:%.2f",data, rumble)
		else
			if jump_rumble_buf > 0 then
				xvib:rumble(0xfff8, 0, 0, 100)
			end
		end
		jump_rumble_buf = data
	end
	set_read_handlers(":mainpcb:maincpu", 0x207F54, jump_rumble)

end

return user
