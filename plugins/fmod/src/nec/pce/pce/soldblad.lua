local user = {}

function user.init()
	print("user script ok.")

--	fmod:log(1)

	local sound_flg = false
	local sound_buf = 0
	function user.sound_replace(offset, data)
		if data == 0x00 or data == 0x89 then sound_flg = false sound_buf = 0 end
		if data ~= 0xa1 and data ~= 0x0d and data ~= 0x04 and data ~= 0x03 and data ~= 0x02 then
			print(string.format("D:%02X", data))
		end
		xvib:play(data)

		if sound_flg then
			sound_flg = false
			if sound_buf ~= data then
				if (fmod:play(data) == 1) then
					sound_buf = data
					data = 0x00
				end
			else
				if fmod:is_samples(data) > 0 then
					data = 0x00
				end
			end
		else
			if (fmod:play(data) == 1) then
				sound_buf = data
				data = 0x00
			end
		end
		if data == 0x93 then sound_flg = true end

		return data
	end

	set_write_handlers(":maincpu", 0x1f00e2, user.sound_replace)
end

return user
