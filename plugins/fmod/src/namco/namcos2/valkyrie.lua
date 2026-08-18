local user = {}

function user.init()
	print("user script ok.")

	-- fmod:log(1) -- FMOD側の動作確認ログ

	local NARRATION = false
	local WINDOW_VOICE = false
	local function apply_params()
		NARRATION = fmod_config.settings.narration
		WINDOW_VOICE = fmod_config.settings.message_voice
	end

	fmod_config.register_user_menu("Valkyrie", {
		{
			key = "narration",
			label = "Narration Voice",
			type = "bool",
			default = true
		},
		{
			key = "message_voice",
			label = "Message Window Voice",
			type = "bool",
			default = false
		},
	}, apply_params)
	apply_params()

	local cpu = manager.machine.devices[":maincpu"]
	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	local dpram = manager.machine.devices[":audiocpu"].spaces["program"]

	local is_music_sample = false

	local m_id = 0
	local function message_id(offset, data)
		m_id = data&0xff
		local w = mem:read_u16(0x104402)
		if w == 0x42e4 then
			--MES("text id:%02X",mid)
			apply_params()
			if WINDOW_VOICE then fmod:play(m_id + 0xf800) end
		end
	end
	set_write_handlers(":maincpu", 0x10446c, message_id)

	local start_time = 0
	local is_message_window = false
	local function message_window(offset, data)
		--MES("d:%02X",data)
		if data == 0x42e4 or data == 0x44be then start_time = emu.time() is_message_window = true end
		if data == 0x0000 and is_message_window then
			fmod:stop(2)
			local end_time = emu.time()
			local elapsed = end_time - start_time
			MES("#id:%02X len:%.1fsec", m_id, elapsed)
			is_message_window = false
		end
	end
	set_write_handlers(":maincpu", 0x104402, message_window)

	function voice_play(sc, vo)
		apply_params()
		if NARRATION then fmod:play(vo + 0xff00) end
		return fmod:play(sc)
	end

	local mute_flg = false
	local function dpram_w(offset, data, mask)
		if offset == 0x460400 or offset == 0x460200 then
			MES("# O:%03X D:%04X", offset&0xfff, data)
			local stage = mem:read_u16(0x100704)
			if (data & 0xff00) == 0x4000 then
				local sc = data & 0xff
				if sc == 0x62 then fmod:stop(0) end
				if sc == 0x24 then sc = sc + 0x100 end
				xvib:play(sc)
				--MES("SC:%02X ST:%02X", sc, stage)
				if sc == 0x0c then
					local flg = mem:read_u8(0x104672)
					if stage == 1 and flg == 0x00 then stage = 0 end
					if stage == 8 and fmod:play(sc) > 0 then mute_flg = true return 0x00 end
					if stage == 4 then mem:write_u16(0x460412, 0x0000) end

					if voice_play(sc,stage) > 0 then
						MES("#demo O:%03X D:%04X S:%02X", offset&0xfff, data, stage)
						mute_flg = true
						return 0x00
					end
				elseif sc == 0x64 then
					if voice_play(sc,stage) > 0 then mute_flg = true return 0x00 end
				end
				if fmod:play(sc) == 1 then
					if sc ~= 0x46 and  sc ~= 0x34 and sc ~= 0x64 then fmod:stop(2) end
					mute_flg = true
--					is_music_sample = true
					return 0x0000
				end
			elseif (data & 0xff00) == 0x8200 then
				if fmod:is_playing(0) > 0 or fmod:is_playing(1) > 0 then
					if (data & 0xff) == 0x00 then
						fmod:play(0x10)
						mute_flg = true
						return 0x0000
					else
						--fmod:play((data & 0xff) + 0xfe00)
						mute_flg = true
						return 0x0000
					end
				end
			end
			return data
		end
		if offset == 0x460402 or offset == 0x460202 then
			MES("O:%03X D:%04X", offset&0xfff, data)
			if data == 0x0000 then
				fmod:stop(0)
				mute_flg = false
			elseif data == 0x0040 or data == 0x0082 then
				if mute_flg then
					mute_flg = false
					return 0x0000
				end
			end
			return data
		end
		if data > 0x0000 and data < 0xffff then
			MES("O:%03X D:%04X", offset&0xfff, data)
			if (data & 0xff00) == 0x4000 then
				local sc = data
				xvib:play(sc)
				if fmod:play(sc) == 1 then
					mute_flg = true
					return 0x0000
				end
				return data
			elseif data == 0x0040 then
				if mute_flg then
					mute_flg = false
					return 0x0000
				end
			end
		end
		return data
	end
	set_write_handlers(":maincpu", 0x460000, dpram_w, 0xfff)

end

return user
