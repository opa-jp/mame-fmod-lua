local user = {}

function user.init()
	print("user script ok.")

	function user.sound_replace(offset, data)
		if data ~= 0x80 then
			--MES("SOUND: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then data = 0x80 end
		end
		return data
	end

	set_write_handlers(":soundcpu", 0xf800, user.sound_replace)
end

return user
