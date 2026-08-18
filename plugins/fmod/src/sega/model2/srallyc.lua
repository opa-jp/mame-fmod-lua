local user = {}

function user.init()
	print("user script ok.")

	--fmod:log(2)

	local function play_vo(data)
		if (fmod:play(data) == 1) then
			return 0x80
		end
		return data & 0xff
	end

	local function play(data)
		if (data < 0x100) then
			fmod:fade_out(0,0.5)
			if (fmod:play(data) == 1) then
				return 0x80
			end
		end
		return data
	end

	local d1, d2, last_music = 0, 0, 0

	function user.sound_replace(offset, data)
		if data == 0xff then
			print("init")
			d1, d2 = 0, 0
			return data
		end

		if data == 0xae then
			d1, d2 = 0, 0
			return data
		end

		if d1 == 0 then
			d1 = data
			return data
		end

		d2 = data
		--if (d1 >= 0x73 and d <= 0x7f) then d = 0 return data end
		--print(string.format("port:%02X comm:%02X", d1, d2))
		if d1 == 0x10 then -- BGM
			if d2 == 0x00 then
				print("music:stop")
				fmod:fade_out(0, (last_music == 0x03 and 3.5 or 0.5))
			else
				print(string.format("music:%02X", d2))
				data = play(d2)
				if d2 == 0x03 and last_music == 0x0d then fmod:fade_out(1, 1.6) fmod:fade_in(0, 0.8) end
				if d2 == 0x06 and last_music == 0x0f then fmod:fade_out(1, 2.4) fmod:fade_in(0, 1.2) end
				if d2 == 0x06 and last_music == 0x07 then fmod:fade_out(1, 2.4) fmod:fade_in(0, 1.2) end
				last_music = d2
			end
		elseif d1 == 0x21 then
			if xvib:play(d2&0xff) == 0 then
				-- print(string.format("se1:%02X", d2))
				if d2 > 0x2c and d2 < 0x46 then xvib:rumble(0xFF21, 0.0, (d2 - 0x20)/100, 150) end
			end
		elseif d1 == 0x20 then
			print(string.format("vo:%02X", d2, d1))
			local vo = 0x2000 + d2
			data = play_vo(vo)
		elseif d1 == 0x73 then
			-- print(string.format("se:%02X", d2))
			if d2 == 0x22 then xvib:rumble(0xFF72, 0.0, 0.3, 600)
			elseif d2 == 0x21 then xvib:rumble(0xFF72, 0.0, 0.3, 1000)
			elseif d2 == 0x20 then xvib:rumble(0xFF72, 0.0, 0.3, 500) end
		end

		d1 = 0
		return data
	end

	set_write_handler(":maincpu", 0x01c80000, user.sound_replace)

end

return user
