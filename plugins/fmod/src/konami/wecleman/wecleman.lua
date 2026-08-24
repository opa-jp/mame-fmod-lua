local user = {}

function user.init()
	print("user script ok.")

	local function play(data)
		sc = data&0xff
		--print(string.format("data:%02X flg:%d ch:%d pl:%d", sc, fmod:is_samples(sc), fmod:get_channel(sc), fmod:is_playing(fmod:get_channel(sc))))
		local channel = fmod:get_channel(sc)
		if (channel == 0) then
			if (fmod:play(sc) == 1) then return 0x0000 end
		else
			if (fmod:play(sc) == 1) then return 0x8080 end
		end

		return data
	end

	local function sound_replace(offset, data)
		sc = data&0xff
		--if data ~= 0x80 then
			MES("SOUND: %02X", sc)
			xvib:play(data&0xff)
		if fmod:play(sc) > 0 then return 0 end
		--end
		--return data
	end

	set_write_handlers(":maincpu", 0x140000, sound_replace)
end

return user
