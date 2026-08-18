local user = {}

function user.init()
	print("user script ok.")

--	fmod:log(2)
--	xvib:log(1)
	load_samples()

	fmod:set_channel_samples(20, 3)

	local function stop(channel)
		fmod:stop(channel)
	end

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

	function user.sound_replace(offset, data)
		local sc = data&0xff
		if not (sc == 0x80 or sc == 0xfe) then
			--print(string.format("D:%02X", sc))
			xvib:play(data&0xff)
			data = play(data)
		end
		return data
	end

	set_write_handler(":maincpu", 0x140000, user.sound_replace)

end

return user
