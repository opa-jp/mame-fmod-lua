local user = {}

function user.init()
	print("user script ok.")

	--fmod:log(2)

	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	local z80mem = manager.machine.devices[":genesis_snd_z80"].spaces["program"]

	local ma_table = {
		[0x04e80900] = 0x06, [0x043b0c00] = 0x2e, [0x04490e00] = 0x2b, [0x04481400] = 0x2d, [0x04e81600] = 0x2c,
		[0x047a0a00] = 0x07, [0x04e50c00] = 0x2f, [0x04c20f00] = 0x30, [0x04ba1500] = 0x31, [0x04781800] = 0x32,
		[0x04c41800] = 0x33, [0x04341900] = 0x34, [0x04e90a00] = 0x08, [0x040f1b00] = 0x36, [0x04841c00] = 0x35,
		[0x042b1d00] = 0x09, [0x04e50900] = 0x37, [0x04af1800] = 0x3a, [0x04710A00] = 0x129, [0x04760A00] = 0x229,
		[0x40822200] = 0x00,
	}
	local ma = 0
	local mab = 0
	local function replace_music(offset, data, mask)
		if offset == 0xa00104 then
			if mask == 0xff00 then
				ma = data & mask
			elseif mask == 0x00ff then
				ma = ma + (data & mask)
			end
		elseif offset == 0xa00106 then
			if mask == 0xff00 then
				ma = (ma << 16) + (data & mask)
			end
			if mask == 0x00ff then
				local music = ma_table[ma] or 0
				--MES("MUSIC:%02X(%08X)", music, ma)
				if fmod:play(music) == 1 then
					z80mem:write_u32(0x0104, 0x40822200)
				end
				mab = ma
			end
		end
		return data
	end

	local se_table = {
		[0x0f45] = 0x2a, [0x0b46] = 0x22, [0x0b47] = 0x24, [0x0b48] = 0x23, [0x0e4a] = 0x0f,
		[0x0c52] = 0x25, [0x0b4c] = 0x26,
		[0x0C53] = 0xff, [0x0C54] = 0xff, [0x0C55] = 0xff, [0x0C56] = 0xff, [0x0C57] = 0xff,
	}
	local se = 0
	local function replace_se(offset, data, mask)
		if mask == 0xff00 then
			se = (data & mask)
		end
		if mask == 0x00ff and data ~= 0x00 then
			local se = se + (data & mask)
			local sound = se_table[se] or 0x80
			--MES("SE:%02X(%04X)",sound, se)
			xvib:play(sound)
			if fmod:play(sound) == 1 then
				data = 0
			end
			if sound == 0xff then
				data = 0
			end
		end
		return data
	end

	local se2_table = {
		[0x7E84] = 0x0a, [0x7F18] = 0x0b, [0x7FC6] = 0x0c, [0x80B8] = 0x0d, [0x81E0] = 0x0e,
		[0xA160] = 0x38, [0x83B4] = 0x20, [0x877C] = 0x21, 
	}
	local se2 = 0
	local function replace_se2(offset, data, mask)
		local sound = se2_table[data] or 0x80
		if sound ~= 0x80 then
			se2 = 0
			--MES("SE2:%02X(%04X)",sound, se)
			xvib:play(sound)
			if fmod:play(sound) == 1 then
				se2 = 1
				data = 0
			end
		end
		if se2 == 1 and sound == 0x80 then
			data = 0
		end
		return data
	end

	local function set_fadeout(offset, data, mask)
		if data == 0x1010 then
			fmod:fade_out(0,3.0)
		end
	end

	set_write_handlers(":maincpu", 0xa00104, replace_music,2)
	set_write_handlers(":maincpu", 0xa00192, set_fadeout)
	set_write_handlers(":maincpu", 0xa00108, replace_se, 2)
	set_write_handlers(":maincpu", 0xff134a, replace_se2)
end

return user
