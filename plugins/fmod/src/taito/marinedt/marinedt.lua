local MDT_TONE1_FREQ = 22550
local MDT_TONE2_FREQ = 22050

local sfreq = MDT_TONE1_FREQ
local loopReset = 0
local mdtVolume = 0
local mdtToneSet = 0
local marinedt_music = 0
local volLoop = 0

local se_buf = {0, 0, 0, 0, 0}
local marinedt_sound = 0

local function calculate_true_pitch(base_f, note_value)
	local semitone_ratio = 1.059463094
	return math.floor(base_f * (semitone_ratio ^ note_value))
end

local function Sample_Music_Tone_Set(tone)
	if tone == 1 then
		if mdtToneSet ~= 1 then
			fmod:play(0)
		end
		mdtToneSet = 1
	elseif tone == 2 then
		if mdtToneSet ~= 2 then
			fmod:play(6)
		end
		mdtToneSet = 2
	end
end

local function Sample_Music_Play(data, freq, tone)
	if loopReset ~= 0 then
		Sample_Music_Tone_Set(tone)
		fmod:volume(0, mdtVolume)
		fmod:set_frequency(0, freq)
	end
end

local function tone_mute()
	fmod:volume(0, 0.01)
end

local function se_play(se)
	if se_buf[se] == 0 then
		fmod:play(se)
		se_buf[se] = 1
	end
end


local function marinedt_music_w(data)
	local mdtMusicData = data & 0x7F

	if (data & 0x80) ~= 0 then
		mdtVolume = 0.80 
		loopReset = 1
		if mdtMusicData == 0x0C and marinedt_music == 0x09 then
			mdtVolume = 0.80
		end
		
		if data == marinedt_music then
			mdtVolume = 0.80
			if volLoop > 0 then
				loopReset = 0 
			end
			volLoop = volLoop + 1
		else
			if mdtMusicData == marinedt_music or (data == 0xC9 and marinedt_music == 0x29) then
				mdtVolume = 0.80
			end
			volLoop = 0
		end
	else
		mdtVolume = 0.80
	end

	local should_play_02_04 = false

	if mdtMusicData == 0x05 or mdtMusicData == 0x09 or mdtMusicData == 0x0C or mdtMusicData == 0x11 then
		local true_freq = calculate_true_pitch(MDT_TONE1_FREQ, mdtMusicData)
		Sample_Music_Play(0, true_freq, 1)

	elseif mdtMusicData == 0x00 then
		if marinedt_music == 0x80 or marinedt_music == 0x00 then
			--should_play_02_04 = true
		elseif data ~= 0x80 then
			tone_mute() 
			loopReset = 1
			marinedt_music = data
			return
		end
	end

	if data == 0x80 or should_play_02_04 or mdtMusicData == 0x02 or mdtMusicData == 0x04 then
		local true_freq = calculate_true_pitch(MDT_TONE1_FREQ, mdtMusicData + 7)
		Sample_Music_Play(0, true_freq, 1)

	elseif mdtMusicData == 0x20 or mdtMusicData == 0x24 or mdtMusicData == 0x25 or 
	       mdtMusicData == 0x27 or mdtMusicData == 0x29 or mdtMusicData == 0x2A or mdtMusicData == 0x2B then

		local note_shift = mdtMusicData - 0x25
		local true_freq = calculate_true_pitch(MDT_TONE1_FREQ, note_shift)
		Sample_Music_Play(0, true_freq, 1)

	elseif mdtMusicData == 0x48 or mdtMusicData == 0x49 then
		local note_shift = (mdtMusicData - 0x45)
		local true_freq = calculate_true_pitch(MDT_TONE1_FREQ, note_shift)
		Sample_Music_Play(0, true_freq, 1)

	elseif mdtMusicData == 0x42 or mdtMusicData == 0x44 or mdtMusicData == 0x45 then
		mdtVolume = 1.00
		local scale = mdtMusicData - 0x42
		local true_freq = calculate_true_pitch(MDT_TONE2_FREQ, scale)
		Sample_Music_Play(0, math.floor(true_freq / 4), 2)


	elseif mdtMusicData == 0x1F then
		tone_mute() 
	end

	marinedt_music = data
end


local function marinedt_sound_w(data)
	local dots_hit   = data & 0x02
	local collision  = data & 0x04
	local ink        = data & 0x08
	local foam       = data & 0x10
	local jet_sound  = data & 0x20

	if dots_hit ~= 0 then se_play(1) else se_buf[1] = 0 end
	if collision ~= 0 then se_play(2) else se_buf[2] = 0 end
	if ink ~= 0 then se_play(3) else se_buf[3] = 0 end
	if foam ~= 0 then se_play(4) else se_buf[4] = 0 end
	if jet_sound ~= 0 then se_play(5) else se_buf[5] = 0 end

	marinedt_sound = data
end


local last_music_val = -1
local last_sound_val = -1

local user = {}

function user.init()
	print("user script ok.")

	function set_write_handler_io(cpu, addr, cb, range)
		if not user then return end
	        local mem = manager.machine.devices[cpu].spaces["io"]
		if mem then
			range = range or 1
			local add_range = (mem.data_width / 8) * range - 1
			mem_write_handler = mem:install_write_tap(
				addr,
				addr + add_range,
				"writes",
				cb
			)
			return true
		end
		return nil
	end

	function sound_replace(offset, data)
		if offset == 0x05 then
			current_music = data
			if current_music ~= last_music_val then
				marinedt_music_w(current_music)
				last_music_val = current_music
			end
		elseif offset == 0x06 then
			current_sound = data
			if current_sound ~= last_sound_val then
				marinedt_sound_w(current_sound)
				last_sound_val = current_sound
			end
		end
	end

        set_write_handler_io(":maincpu", 0x05, sound_replace, 2)
end

return user
