local STICK_1P_X = "JOYCODE_1_ZAXIS"
local STICK_1P_Y = "JOYCODE_1_RZAXIS"
local DEADZONE = 15000
local BUTTON_ATK = "P1 Y"
local ROTATE_AND_ATK = nil

local user = {}

function user.init()
	print("user script ok.")

	local input = manager.machine.input
	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	local apu = manager.machine.devices[":soundcpu"].spaces["program"]
	local rom = manager.machine.memory.regions[":snsslot:cart:rom"]
	rom:write_u16(0xd84eb, 0xeaea)
	local mute_channels = {0, 1, 2, 3, 4, 5, 6, 7}

	function sp700_mute()
		for _, ch in ipairs(mute_channels) do
			-- 左音量（VOLL）のアドレス計算
			local register_l = ch * 0x10
			-- 右音量（VOLR）のアドレス計算
			local register_r = (ch * 0x10) + 1

			-- 1. 左音量を 0 に設定
			apu:write_u8(0x00F2, register_l) -- F2Hにレジスタ番号をセット
			apu:write_u8(0x00F3, 0x00)       -- F3Hにデータ（音量0）を書き込み

			-- 2. 右音量を 0 に設定
			apu:write_u8(0x00F2, register_r) -- F2Hにレジスタ番号をセット
			apu:write_u8(0x00F3, 0x00)       -- F3Hにデータ（音量0）を書き込み
		end
	end

	local function get_dir(x, y)
		local angle = math.atan(-y, x) 
		if angle < 0 then angle = angle + (2 * math.pi) end
		local adjusted_angle = angle - (math.pi / 2)
		if adjusted_angle < 0 then adjusted_angle = adjusted_angle + (2 * math.pi) end
		adjusted_angle = (2 * math.pi) - adjusted_angle
		if adjusted_angle >= (2 * math.pi) then adjusted_angle = adjusted_angle - (2 * math.pi) end
		local angle_from_top = adjusted_angle
		if angle_from_top > math.pi then
			angle_from_top = (2 * math.pi) - angle_from_top
		end

		local ratio = angle_from_top / math.pi
		local min_val = 0x0000
		local max_val = 0x1100
		local continuous_val = min_val + (max_val - min_val) * ratio

		return math.floor(continuous_val + 0.5)
	end

	local PORT_TAG = ":ctrl1:joypad:JOYPAD"
	local field = nil
	if manager and manager.machine and manager.machine.ioport then
		local port = manager.machine.ioport.ports[PORT_TAG]
		if port and port.fields then
			field = port.fields[BUTTON_ATK]
		end
	end

	local function valken_rotate()

-- 【パッチ1】BGMデータ転送ルーチンの入り口を「RTS（即時復帰）」に書き換えます
-- これにより、あらゆるBGM（オープニング、ステージ曲など）のデータ展開とAPUへの転送要求が手前で遮断されます。
mem:write_u8(0x1B8510, 0x60) -- 1B:8510 を「RTS」(60) に上書き

-- 【パッチ2】念のため、先ほど解析したBGMトリガーの入り口（1B:8091）も「NOP NOP NOP」で消去します
-- これにより、BGM再生ルーチンへのジャンプ自体が完全にスルーされます。
mem:write_u8(0x1B8091, 0xEA) -- NOP
mem:write_u8(0x1B8092, 0xEA) -- NOP
mem:write_u8(0x1B8093, 0xEA) -- NOP
mem:write_u16(0x1b84e8, 0xeaea)
		
		--sp700_mute()
		if not input or not mem then return end

		local tx = input:code_from_token(STICK_1P_X)
		local ty = input:code_from_token(STICK_1P_Y)
		local x = tx and input:code_value(tx) or 0
		local y = ty and input:code_value(ty) or 0

		if math.abs(x) > DEADZONE or math.abs(y) > DEADZONE then
			local xp = 0x0000
			if x < 0 then xp = 0x4000 end
			mem:write_u16(0x8014d8, xp)
			mem:write_u16(0x801500, 0x0000)
			mem:write_u16(0x8014fa, get_dir(x, y))
			if ROTATE_AND_ATK and field then
				field:set_value(1)
			end
		end
	end

	local cpu2spc = 0
	function user.sound_replace(offset, data) -- ここで送られてくるサウンドコードをどう処理するか決める
		--if offset == 0x7E00C2 then MES("O:%04X D:%02X", offset, data) return 0 end
		--if offset == 0x7E011C then MES("O:%04X D:%02X", offset, data) return 0 end
		if offset == 0x1b2140 then cpu2spc = data return end
		--if offset >= 0x1b2140 and offset <= 0x1b2143 then MES("O:%04X D:%02X", offset, data) return end
		if offset >= 0x7fff00 and offset <= 0x7fff8f then MES("O:%04X D:%02X", offset, data) return 0 end
		--if offset >= 0x7fff08 and offset <= 0x7fff0f then MES("O:%04X D:%02X", offset, data) return 0xff end
		if data == 0 then return end
		if data == 1 then return end
		if data == 0xe0 then return end
		if data == 0xff then return end
		if offset == 0x7fff80 then return 0 end
		if offset == 0x420C then return end
		if offset == 0x2104 then return end
		if offset == 0x2118 then return end
		if offset == 0x2119 then return end
		if offset == 0x2122 then return end
		if offset == 0x1f66 then return end
		if offset == 0x1f67 then return end
		if offset > 0x1f00 and offset < 0x1fff then return end
		if offset > 0x1900 and offset < 0x1aff then return end
		--if offset > 0x2100 and offset < 0x21ff then return end
		--if offset == 0x2117 then return 0 end
		--if offset == 0x2115 then return 0x80 end
		--if offset > 0x4000 then return end
		if offset == 0x1b2140 then return end
		if offset == 0x1b2141 then return end
		if offset == 0x1b2142 then return end
		if offset == 0x1b2143 then return end
		if offset >  0x814000 and offset < 0x814fff then return end
		if offset == 0x812100 then return end
		if offset == 0x81211f then return end
		if offset == 0x812120 then return end
		if offset == 0x812126 then return end
		if offset == 0x812128 then return end
		if offset > 0x810000 then return end
		--if offset >  0x7ec000 and offset < 0x7ecfff then return end
		--if offset >= 0x7e0000 and offset <= 0x7e8fff then return end
		if offset >= 0x7ffe00 and offset <= 0x7fffff then return end

	--	MES("O:%04X D:%02X", offset, data)
		-- xvib:play(data) -- 振動
		-- if (fmod:play(data) == 1) then data = 0xff end -- サウンド再生。　成功時には1が返るので、dataに0xff(サウンド停止)を入れてゲーム側のサウンドを止める
		return data
	end

	local com0 = 0
	local dat0 = 0
	local dat1 = 0
	local dat2 = 0
	local dat3 = 0
	local pos0 = 0
	local pos_count = 0
	function spc700_com(offset, data)
		--MES("O:%04X D:%02X", offset, data)
		if offset == 0x1b2140 then
			if pos0 > 0 then
				count = 0
			end
			pos0 = 0
			pos_count = 0
			com0 = data
			if data == 0x00 then return end
			if data == 0x80 then return end
			if data == 0xc0 then return end
			if data == 0x40 then return end
			MES("O:%04X D:%02X", offset, data)
			--if data == 0x01 then return 0x00 end
		end
		if offset == 0x1b2141 then
			pos0 = 1
			pos_count = pos_count +1
		end
		if offset == 0x1b2142 then
			pos0 = 2
			pos_count = pos_count +1
			--MES("O:%04X D:%02X", com0, data)
		end
		if offset == 0x1b2143 then
			pos0 = 3
			pos_count = pos_count +1
		end
		--data = 0x3a
		return data
	end
	function spc700_se(offset, data)
		MES("O:%04X D:%02X", offset, data)
		data = 0
		return data
	end
	local re = 0
	function spc700_mutes(offset, data)
		--MES("O:%04X D:%02X", offset, data)
		if offset == 0xf2 then
			re = data
		end
		if offset == 0xf3 then
--			if re == 0x00 or re == 0x01 then return 0 end
--			if re == 0x10 or re == 0x11 then return 0 end
			if re == 0x20 or re == 0x21 then return 0 end
			if re == 0x30 or re == 0x31 then return 0 end
			if re == 0x40 or re == 0x41 then return 0 end
			if re == 0x50 or re == 0x51 then return 0 end
			if re == 0x60 or re == 0x61 then return 0 end
			if re == 0x70 or re == 0x71 then return 0 end
		end
		return data
	end

local current_srcn = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 }

-- ★【要調整】BGMとして使われている音色番号（楽器ID）のブラックリスト
-- ここに登録した音色番号がセットされている間だけ、そのチャンネルをミュートします。
-- 効果音の音色番号（足音、爆発音、打撃音など）はここに入れないようにします。
	local bgm_srcn_list = {
		[0x00] = true,
		[0x01] = true,
		[0x02] = true, -- brass
		[0x03] = true, -- brass2
		[0x04] = true, -- synth
		[0x05] = true, -- rythem
		[0x06] = true, -- rythem 2
		[0x07] = true, -- synth2
		[0x08] = true, -- tom
--		[0x09] = true, -- se/burner
--		[0x0a] = true, -- se
		[0x0b] = true,
--		[0x0c] = true, -- se/pause
		[0x0d] = true,
--		[0x0e] = true, -- se/bomb
--		[0x0f] = true, -- se/bomb2
--		[0x10] = true, -- se/shot
--		[0x11] = true, -- se/tap
--		[0x12] = true, -- se/boost
		[0x13] = true, -- bass
		[0x14] = true, -- piano
		[0x15] = true, -- synth
	}

	local cch = 0
	function spc700(offset, data)
		if offset == 0xf2 then
		--MES("o:%02X d:%02X c:%02X", offset, data, cpu2spc)
			re = data
		end

		if offset == 0xf3 then
			if re == 0x4C then
				if data == 0x01 then return end
				if data ~= 0 then
					--MES("C:%02X D:%02X", cpu2spc, data)
				end
				return
			end
			-- 1. ゲームが音色番号 (SRCN) を変更した瞬間をキャッチして記憶する
			-- レジスタ 0x04, 0x14, 0x24, ... 0x74 が SRCN
			if (re & 0x0F) == 0x04 and re <= 0x74 then
				local ch = re >> 4
				current_srcn[ch] = data
				MES("ch:%D type:%02X", ch, data)
				return data
			end

			-- 2. 音量レジスタ（VOLL / VOLR）への書き込み時の処理
			if (re & 0x0E) == 0x00 and re <= 0x71 then
				local ch = re >> 4
				cch = ch
				-- そのチャンネルの現在の音色が「BGM用」だった場合のみ、音量を 0 にする
				MES("C:%d D:%02X", ch, current_srcn[ch])
				maincpu:write_u8(0x1b2140, 0xbe)
				if bgm_srcn_list[current_srcn[ch]] then
					--return 0
					return
				end
				--MES("C:%d D:%02X", ch, current_srcn[ch])
			end
		end
		return data
	end

	local raw_cmd = 0
	local bgm_requested = false
	function spc700_com(offset, data)
		--MES("O:%04X D:%02X", offset, data)
		--maincpu:write_u8(0x1b84f9, 0x60)
		if offset == 0x1b2140 then
			raw_cmd = data & 0x7F
			if raw_cmd == 0x00 or raw_cmd == 0x40 then return end
			com0 = raw_cmd
			--MES("C:%02X D:%02X", raw_cmd, data)
			--if data == 0x01 then return 0x00 end
			--if raw_cmd == 0x07 then return 0x01 end
			local sync_bit = data & 0x80
			--if raw_cmd == 0x01 then return sync_bit | 0x3B end
			--if raw_cmd == 0x01 then return 0x01 end
			local pc = manager.machine.devices[":maincpu"].state["PC"].value
			if pc == 0x1B8454 then return end

			if pc == 0x1B84F9 then
				MES("CMD:%02X", raw_cmd)
				bgm_requested = false
				if raw_cmd < 0x20 then
					--MES("1 C:%02X D:%02X", raw_cmd, rom:read_u16(0xd84e8))
					bgm_requested = true
					return sync_bit | 0x00
				end

				-- 2. ゲームポーズ:0x3B
				if raw_cmd == 0x3B then
					return data
				end

				-- 3. ゲームポーズ解除:0x3A
				if raw_cmd == 0x3A then
					return data
				end
			end

		end
		if offset == 0x1B2141 then
			pos0 = 1
			pos_count = pos_count +1
			--if com0 == 0x00 or com0 == 0x01 or com0 == 0x40 then return end
			--MES("1 C:%02X D:%02X", com0, data)
			--maincpu:write_u16(0x1b84e8, 0xeaea)
		end
		
		if offset == 0x1b2142 then
			--MES("2 C:%02X D:%02X", raw_cmd, data)
			pos0 = 2
			pos_count = pos_count +1
			if bgm_requested then return 0 end
			--if com0 == 0x05 or com0 == 0x40 or com0 == 0x3E then return end
			--if data == 0x65 then return 0x00 end
			--if data > 0 then return 0x10 end
			--if data == 0x65 then MES("3 C:%02X D:%02X", com0, data) maincpu:write_u8(0x1b2140, 0x81)  end
			local pc = manager.machine.devices[":maincpu"].state["PC"].value
			--if pc == 0x1B8235 then return 0xff end
			--if pc == 0x1B81EC then return 0xff end
			if pc == 0x1B8235 then return end
			if pc == 0x1B81EC then return end
			if pc == 0x1B8260 then return end
			--if pc == 0x1B8279 then return end
			--MES("2 C:%02X P:%02X D:%02X", com0, pc, data)
			--if pc == 0x1B8279 and data&0x10 == 0 then return 0x00 end

		end
		if offset == 0x1b2143 then
			--MES("3 C:%02X D:%02X", raw_cmd, data)
			pos0 = 3
			pos_count = pos_count +1
			if bgm_requested then return 0 end
			--MES("3 C:%02X D:%02X", com0, data)
			if com0 == 0x00 or com0 == 0x40 then return end
			--if data == 0x02 then return end
			--if data > 0 then return 0x08 end
			--if data == 0x02 then MES("3 C:%02X D:%02X", com0, data) maincpu:write_u8(0x1b2140, 0x3E)  end
			local pc = manager.machine.devices[":maincpu"].state["PC"].value
			--if pc == 0x1B81EC then return 0xff end
			--MES("2 C:%02X P:%02X", com0, pc)
		end
		--data = 0x3a
		return data
	end

	function cmp(offset, data)
		MES("OFFSET:%04X DATA:%02X", offset, data)
	end


	set_frame_handlers(valken_rotate)
	--set_write_handlers(":maincpu", 0x7e0000, user.sound_replace, 0x0fffff)
	--set_write_handlers(":maincpu", 0x1b2141, spc700_se)
	set_write_handlers(":maincpu", 0x1b2140, spc700_com, 4)
	--set_write_handlers(":soundcpu", 0x00f0, spc700, 4)
	--set_write_handlers(":maincpu", 0x1b84e8, cmp)


function spc700_com2(offset, data)
    if offset == 0x1b2140 then
        local raw_cmd = data & 0x7F
        local pc = manager.machine.devices[":maincpu"].state["PC"].value
	    --if raw_cmd == 0x00 then return end

	    MES("C:%02X P:%02X", raw_cmd, pc)
        -- 1B:84F9 の無限ループに突入してしまった場合
        if pc == 0x1B84F9 and raw_cmd == 0x0a then
            -- APUのポートはいじらず、メインCPUをループの次の命令（1B:84FB）へ強制的に進める
            manager.machine.devices[":maincpu"].state["PC"].value = 0x1B84FB
            -- データは加工せずそのままAPUへ通す（同期が壊れない）
            return data
        end
    end
end
--	set_write_handlers(":maincpu", 0x1b2140, spc700_com2, 4)


--local maincpu = manager.machine.devices[":maincpu"]
--local mem = maincpu.spaces["program"]

	function spc700_cmp(offset)
		MES("read")
		return 0x60
	end
--	set_read_handlers(":maincpu", 0x1b2140, spc700_cmp)


mem:install_read_tap(0x002140, 0x002140, "apu_port_read_tap", function(offset, data, mem_mask)
    local maincpu = manager.machine.devices[":maincpu"]
    local pc = maincpu.state["PC"].value
MES("read")
    -- CPUが 1B:84E8 (cmp $2140) を実行してAPUの応答を待っている瞬間
    if pc == 0x1B84E8 then
        -- ここで「data」の値をいじることで、APUが返してきた応答を
        -- CPU側に対して「偽装」してフリーズを突破させることが可能です
    end

    -- 通常時はAPUから返ってきた値をそのままCPUに渡す
    return data
end)
	
end

return user
