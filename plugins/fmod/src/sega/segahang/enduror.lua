local user = {}

function user.init()
	print("user script ok.")

	local function sound_replace(offset, data)
		if data ~= 0x80 then
			--MES("SOUND: %02X(%04X)", data, offset)
			xvib:play(data)
			if fmod:play(data) > 0 then return 0x80 end
		end
	end
	set_write_handlers(":soundcpu", 0xf800, sound_replace)

	local function add_vibration_effect(offset, data)
		if data > 0x00 and data < 0x100 then
			local m = data / 0xff
			xvib:rumble_raw(0xfffe, m/2, 0)
		end
		if data == 0xffff then
			xvib:rumble_raw(0xfffe, 0.7, 0, 300)
		end
	end
	set_write_handlers(":maincpu", 0x408a4, add_vibration_effect)
end

return user
