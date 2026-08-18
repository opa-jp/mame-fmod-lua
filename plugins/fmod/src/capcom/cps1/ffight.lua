local user = {}

function user.init()
	print("user script ok.")

	--fmod:log(1) -- FMOD側の動作確認ログ

	fmod:set_channel_samples(20, 3) -- 20チャンネルは3音まで同時にならせるようにする

	function play(data)
		local ch = fmod:get_channel(data)
		local cm = fmod:get_maxaudible(ch)
		print(string.format("sound:%02X ch:%d aud:%d", data, ch, cm))
		if (fmod:is_samples(data) == 2) then
			local channel = fmod:get_channel(data)
			if (channel == 0) then
				if (fmod:is_playing(channel) == 1) then
					fmod:stop_all()
					local ret = fmod:play(data)
					return ret
				else
					return fmod:play(data)
				end
			elseif channel % 10 == 9 then
				return fmod:play(data)
			else
				fmod:stop(channel)
				return fmod:play(data)
			end
		end
	end

	local sc_table = {
		[0xff] = "skip",
		[0xf0] = function() fmod:fade_out(0, 0.25) fmod:stop(19) end,
--		[0xf7] = function() fmod:fade_out(0, 1.0) end,
	}

	local function sound_replace(offset, data)
		local scom = sc_table[data]
		if scom == "skip" then
			return
		elseif type(scom) == "function" then
			scom()
			return
		end
		-- print(string.format("D:%02X", data))
		local ch = fmod:get_channel(data)
		local cm = fmod:get_maxaudible(ch)
		print(string.format("sound:%02X ch:%d aud:%d", data, ch, cm))

		if (fmod:play(data) == 1) then data = 0xff end
		return data
	end

	set_write_handler(":maincpu", 0x800180, sound_replace)

end

return user
