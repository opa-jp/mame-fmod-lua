local user = {}

function user.init()
	print("user script ok.")
	--fmod:log(2) -- FMOD operation verification log

	local function map_value(current_val, max_vol, min_val, max_val)
		if current_val < min_val then current_val = min_val end
		if current_val > max_val then current_val = max_val end
		local ratio = (current_val - min_val) / (max_val - min_val)
		return ratio * max_vol
	end

	local function sound_replace(offset, data)
		if data ~= 0x80 then
			if data >= 0x4f and data <= 0x70 then
				local vol = map_value(data, 1.5, 0x4f, 0x70)
				fmod:volume(0,vol)
				return data
			end
			if data ~= 0x40 and data ~= 0x70 then
				MES("SOUND: %02X(%04X)", data, offset)
			end
			xvib:play(data)
			if fmod:play(data) > 0 then return 0x80 end
		end
	end
	set_write_handlers(":soundcpu", 0xf800, sound_replace,2)

	local function voice_replace(offset, data)
		if data ~= 0x00 then
			MES("SOUND SUB: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then return 0x00 end
		end
	end
	set_write_handlers(":soundcpu", 0xf808, voice_replace)
end

return user
