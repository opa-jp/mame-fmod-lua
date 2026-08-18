local user = {}

user.XVIB_LIST = {
    [0x1102] = { l=0.4, r=0.0, time=500 },
    [0x1109] = { l=0.0, r=0.5, time=1200 }
}

function user.init()
	print("user script ok.")

	fmod:log(2)

	fmod_config.add_tag_option("test")

	load_samples(fmod_config.get_tag())

	local d0 = 0
	local d1 = 0
	local d2 = 0
	local d3 = 0

	local function play(data)
		--print(string.format("sound:%02X", data))
		if (data < 0xffff) then
			if (fmod:is_samples(data) == 1) then
				fmod:play(data)
				return 0x80
			elseif (fmod:is_samples(data) == 2) then
				local channel = fmod:get_channel(data)
				if (channel == 8 or channel == 18 or channel == 28 or channel == 38) then
					if (fmod:is_playing(channel) == 0) then
						fmod:play(data)
					end
				elseif (channel == 10 or channel == 20 or channel == 30) then
					fmod:play(data)
				elseif (channel == 19 or channel == 29 or channel == 39) then
					if (fmod:is_playing(channel) == 0) then
						fmod:play(data)
					end
					return (data&0xff)
				else
					fmod:stop(fmod:get_channel(data))
					fmod:play(data)
				end
				return 0x80
			else
				if ((data&0xff00) == 0x1100) then
					print(string.format("se1:%04X", data))
				elseif ((data&0xff00) == 0x1200) then
					print(string.format("se2:%04X", data))
				elseif ((data&0xff00) == 0x1300) then
					print(string.format("voice:%04X", data))
				elseif ((data&0xff00) == 0x0000) then
					print(string.format("music:%02X", data))
				end
			end
		end
		return (data&0xff)
	end

	local function sound_replace(offset, data)
		--print(string.format("D:%02X", data))
		if (data == 0xff) then
			print("init")
			d0 = 0
			d1 = 0
			d2 = 0
		end

		if (data == 0xae) then
			d0 = data
			d1 = 0
			d2 = 0
		elseif (d1 == 0) then
			d1 = data
		elseif (d2 == 0) then
			d2 = data
			if (d1 == 0x10) then
				--print(string.format("music:%02X", data))
				data = play(data)
				data = 0x80
			elseif (d1 == 0x11) then
				local se = (d1 << 8) + d2
				--print(string.format("se1:%04X", se))
				--play_vib(se)
				data = play(se)
				-- data = 0x80
			elseif (d1 == 0x12) then
				local se = (d1 << 8) + d2
				--print(string.format("se2:%04X", se))
				--play_vib(se)
				data = play(se)
				-- data = 0x80
			elseif (d1 == 0x13) then
				local vo = (d1 << 8) + d2
				--print(string.format("voice:%02X", vo))
				data = play(vo)
				--data = 0x80
			end
		end
		return data
	end

	set_write_handler(":maincpu", 0x009c0000, sound_replace)

end

return user
