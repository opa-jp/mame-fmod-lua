local user = {}

function user.init()
	print("user script ok.")
	--fmod:log(2) -- FMOD operation verification log

	local function play_wait(s)
		fmod:play(s)
	end

	local function sound_replace(offset, data)
		if data == 0xffff then return data end
		local sc = data & 0xff
		MES("D:%02X", sc) -- Check if the sound code is being received for now
		xvib:play(sc)
		if sc == 0x00 or (sc >= 0x03 and sc <= 0x12) or sc == 0x14 or sc == 0x16 or sc == 0x17 or sc == 0x1b then
			if fmod:is_playing(0) == 1 then
				fmod:fade_out(0, 250)
				if fmod:is_samples(sc) > 0 then
					set_frames_wait_once(play_wait, 15, sc)
					return 0xffff
				end
			else
				if fmod:play(sc) == 1 then return 0xffff end
			end
		else
			if fmod:play(sc) == 1 then return 0xffff end
		end
		return data
	end

	set_write_handler(":maincpu", 0x800180, sound_replace)
end

return user
