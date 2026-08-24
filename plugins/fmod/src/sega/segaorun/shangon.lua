local user = {}

function user.init()
	print("user script ok.")

	local function sound_replace(offset, data)
		if data ~= 0x80 then
			--MES("SOUND: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then data = 0x80 end
		end
		return data
	end
	set_write_handlers(":soundcpu", 0xf800, sound_replace)

	local function add_vibration_effect(offset, data)
		if data > 0x00 and data < 0x48 then
		MES("D:%02X",data)
			local m = data / 0x47
			xvib:rumble_raw(0xfffe, 0, m/2, 100)
		end
	end
	set_write_handlers(":soundcpu", 0xfd41, add_vibration_effect)
end

return user
