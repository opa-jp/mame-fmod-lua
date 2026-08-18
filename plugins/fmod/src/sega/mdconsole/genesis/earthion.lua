local user = {}

function user.init()
	print("user script ok.")

	fmod:log(2)
	xvib:log(2)
	load_samples()

	local function sound_replace(offset, data, mask)
		--print(string.format("O:%02X D:%02X M:%04X", offset, data, mask))
		if data > 0xC000 then
			local s = data & 0xFF
			--print(string.format("S:%02X", s))
			if offset == 0xFF579C then -- muic
				--data = 0;
			elseif offset == 0xFF579A then -- se1
				--data = 0;
				xvib:play(s)
			elseif offset == 0xFF579C then -- se2
				--data = 0;
				xvib:play(s)
			elseif offset == 0xFF5798 then -- se3
				--data = 0;
				xvib:play(s)
			elseif offset == 0xFF5796 then -- vo/pcm
				--data = 0;
				xvib:play(s)
			end
		end
		return data
	end

	set_write_handler(":maincpu", 0xff5794, sound_replace, 6)

end

return user
