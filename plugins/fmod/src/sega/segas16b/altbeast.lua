local user = {}

function user.init()
	print("user script ok.")
	--fmod:log(2) -- FMOD operation verification log

	local function sound_replace(offset, data)
		if data >= 0x28 and data <= 0x3F then
			local min_val = 0x28
			local max_val = 0x4D
			local vol = (data - min_val) / (max_val - min_val)
			fmod:volume(0,vol)
			return data
		elseif data ~= 0x80 then
			MES("SOUND: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then return 0x80 end
		end
	end
	set_write_handlers(":soundcpu", 0xf818, sound_replace)

	local function voice_replace(offset, data)
		if data ~= 0x00 then
			MES("VOICE: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then return 0x00 end
		elseif data == 0x00 then fmod:stop(20) end
	end
	set_write_handlers(":soundcpu", 0xf808, voice_replace)

	--set_write_handlers(":maincpu", 0xfe0004, sound_replace)
end

return user
