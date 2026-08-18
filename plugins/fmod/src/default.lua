local user = {}

function user.init()
	print("user script ok.")

	-- fmod:log(1) -- FMOD operation verification log

	local function sound_replace(offset, data) -- Determine how to process the incoming sound codes here
		MES("D:%02X", data) -- Check if the sound code is being received for now
		-- xvib:play(data) -- Vibration
		-- if fmod:play(data) == 1 then data = 0xff end -- Play sound. Returns 1 on success, so data is set to 0xff (sound stop) to mute the game audio.
		return data
	end

	-- set_write_handlers(":maincpu", 0x140000, sound_replace) -- Address where the sound codes are sent
end

return user
