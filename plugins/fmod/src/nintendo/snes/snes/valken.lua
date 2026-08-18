local STICK_1P_X = "JOYCODE_1_ZAXIS"
local STICK_1P_Y = "JOYCODE_1_RZAXIS"
local BUTTON_ATK = "P1 Y"
local DEADZONE = 18000
local ROTATE_AND_ATK = true
local TEXT_SE = false
local TEXT_VOICE = false
local VOICE_BGM_LESS = true
local VOICE_BGM_LESS_VOLUME = 0.6
local AS_VOICE = true
local SAMPLES_SE = false
local AUTO_NEXT_MESSAGE = false

local user = {}

function user.init()
	print("user script ok.")
	--fmod:log(1)

	local input = manager.machine.input
	local cpu = manager.machine.devices[":maincpu"]
	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	local apu = manager.machine.devices[":soundcpu"].spaces["program"]
	local rom = manager.machine.memory.regions[":snsslot:cart:rom"]
	rom:write_u16(0xd84eb, 0xeaea)

	local is_patch = nil
	local function check_pc()
		if is_patch then
			if cpu.state["PC"].value == 0x1b84eb then
				cpu.state["PC"].value = 0x1b84ed
				is_patch = nil
			end
		end
	end

	local function apply_params()
		ROTATE_AND_ATK = fmod_config.settings.rotate_and_atk
		DEADZONE = fmod_config.settings.stick_deadzone
		TEXT_SE = fmod_config.settings.text_sound
		TEXT_VOICE = fmod_config.settings.text_voice
		AS_VOICE = fmod_config.settings.text_voice2
		VOICE_BGM_LESS =  fmod_config.settings.voice2bgm_vol_ctrl
		SAMPLES_SE =  fmod_config.settings.se_samples
		AUTO_NEXT_MESSAGE = fmod_config.settings.auto_next_message
	end

	fmod_config.register_user_menu("Valken Settings", {
		{
			key = "stick_deadzone",
			label = "Stick Deadzone",
			type = "number",
			min = 1000,
			max = 36000,
			step = 1000,
			default = DEADZONE
		},
		{
			key = "rotate_and_atk",
			label = "Rotate and Attack",
			type = "bool",
			default = ROTATE_AND_ATK
		},
		{
			key = "text_sound",
			label = "Text Sound",
			type = "bool",
			default = false
		},
		{
			key = "text_voice",
			label = "Voice",
			type = "bool",
			default = true
		},
		{
			key = "voice2bgm_vol_ctrl",
			label = "Voice Volume Control",
			type = "bool",
			default = true
		},
		{
			key = "text_voice2",
			label = "Voice AS",
			type = "bool",
			default = true
		},
		{
			key = "se_samples",
			label = "SE Samples",
			type = "bool",
			default = false
		},
		{
			key = "auto_next_message",
			label = "Auto Next Meggage",
			type = "bool",
			default = false
		}
	}, apply_params)
	apply_params()

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
		local max_val = 0x1180
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

	local is_atk_pushed = 0
	local function valken_rotate()
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
			if ROTATE_AND_ATK == true and field then
				is_atk_pushed = 1
				field:set_value(is_atk_pushed)
			end
		else
			if is_atk_pushed == 1 and field then
				is_atk_pushed = 0
				field:set_value(is_atk_pushed)
			end
		end

		apply_params()
		--check_pc()
	end
	set_frame_handlers(valken_rotate)

	function wait_se(se)
		if not fmod then return end
		if se > 0x1000 then
			fmod:play(se)
		end
	end

	local ma_table = {
		[0x01] = 0x00, [0x07] = 0x01, [0x0a] = 0x02, [0x08] = 0x03, [0x09] = 0x04,
		[0x0c] = 0x05, [0x0d] = 0x06, 
		[0x0e] = 0x07, [0x0f] = 0x08, [0x10] = 0x09,
		[0x12] = 0x0a, [0x13] = 0x0d, [0x04] = 0x0c, [0x05] = 0x0b, [0x06] = 0x0e,
	}
	local cmd = 0
	local sound = 0
	local sound_volume = 1.0
	local text_se_mute = 0
	local is_text_skip = 0
	function spc700_comm(offset, data)
		if offset == 0x1b2140 then
			cmd = data & 0x7F
			if cmd == 0x00 or cmd == 0x40 then return end
			local pc = manager.machine.devices[":maincpu"].state["PC"].value
			if pc == 0x1B8454 then return end

			if pc == 0x1B84F9 then
				--if type(MES) == "function" then MES("CMD:%02X DATA:%02X", cmd, data) end
				if cmd < 0x20 then
					sound = ma_table[cmd] or 0x80
					if fmod:play(sound) == 1 then
						sound_volume = fmod:get_volume(sound)
						is_patch = true
						if cmd == 0x0a then
							deley_count = 2
							pending_data = 0xbb
						end
						if cmd == 0x06 then
							if fmod:is_playing(1) == 1 then
								fmod:fade_in(0, 3.0)
								fmod:fade_out(1, 4.0)
							end
						end
						if sound == 0x00 then
							fmod:play(0xff00)
							--set_frames_wait_once(wait_se, 1820, 0xff00)
						end
						if sound == 0x01 then
							fmod:stop(1)
						end
						return 0xbb
					end
				end

				if cmd == 0x3B then
					if sound == 0x0c then return end
					fmod:menu_pause(1)
					fmod:menu_pause(0)
					fmod:play(cmd)
					fmod:fade_out(7, 0.5)
				end

				if cmd == 0x3A then
					fmod:menu_pause(0)
					fmod:fade_in(0, 1.0)
				end

				if cmd == 0x3E then
					fmod:play(cmd)
				end

				return data
			end
		end

		if offset == 0x1B2141 then
			local se_stop = 0x75
			local pc = cpu.state["PC"].value
			local se = data & 0x7f
			if pc ~= 0x1B850E then return end
			if data == 0xFF then return end
			--if se == 0x20 and text_se_mute == 1 then return 0xff end
			if TEXT_SE == false and se == 0x20 then return 0xff end
			--MES("se:%02X", se)
			if is_text_skip == 1 and se == 0x10 then fmod:stop(6) end
			xvib:play(se)
			if SAMPLES_SE == true then
				if se == 0x17 then
					local stage = mem:read_u8(0x19d0)
					--MES("se:%02X stage:%02X", se + 0xe100, stage)
					if stage == 0x00 then
						if fmod:play(se + 0xe100) == 1 then
							return se_stop
						end
					end
				end
				if se == 0x66 then
					local pose = mem:read_u8(0x14ca)
					--MES("se:%02X pose:%02X", se + 0xe100, pose)
					if pose == 0x07 then
						if fmod:play(se + 0xe100) == 1 then
							return se_stop
						end
					end
				end
				if se == 0x75 then
					local stage = mem:read_u8(0x19d0)
					local pose = mem:read_u8(0x14ca)
					--MES("se:%02X stage:%02X pose:%02X", se + 0xe000, stage, pose)
					if stage == 0x09 or stage == 0x10 then return end
					if pose == 0x07 or pose == 0xcd then
						if pose == 0xcd then fmod:play(0xe031) end
						if fmod:play(se + 0xe100) == 1 then
							return se_stop
						end
					else
						if pose == 0x5f then if fmod:play(0xe078) == 1 then return end end
						local d_ch = fmod:get_channel(0xe02d)
						if fmod:is_playing(d_ch) ~= 0 then fmod:stop(d_ch) end
						return
					end
				end
				if fmod:play(se + 0xe000) == 1 then
					return se_stop
				else
					MES("se:%02X", se + 0xe000)
				end
			end
		end
		return data
	end
	set_write_handlers(":maincpu", 0x1b2140, spc700_comm, 2)

	local pose_buf = 0
	local function as_pose(offset, data)
		if not fmod then return end
		if sound == 0 then return end
		if data ~= pose_buf then
			--MES("pose:%02X",data)
			fmod:play(data + 0xe000)
		end
		pose_buf = data
	end
	set_write_handlers(":maincpu", 0x14cf, as_pose)

	local srcn = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0, [5]=0, [6]=0, [7]=0 }
	local data_f2 = 0
	function spc700(offset, data)
		if offset == 0xf2 then
			data_f2 = data
		end

		if offset == 0xf3 then
			local ch = data_f2 >> 4
			if (data_f2 & 0x0F) == 0x04 and data_f2 <= 0x74 then
				srcn[ch] = data
				return data
			end
			if (data_f2 & 0x0E) == 0x00 and data_f2 <= 0x71 then
				if sound == 0x01 then
					if ch == 3 and srcn[ch] == 0x0e then return 0 end
					if ch == 5 and srcn[ch] == 0x09 then return 0 end
				end
				if sound == 0x02 then
					if ch == 4 or ch == 5 and srcn[ch] == 0x09 then return 0 end
				end
			end
		end
		return data
	end
	set_write_handlers(":soundcpu", 0x00f0, spc700, 4)

	function wait_voice(voice)
		if not fmod then return end
		if voice > 0x1000 then
			fmod:play(voice)
		end
	end

	local demo_text = {
		queue = {},
		stack = {},
		current = nil,
		buf = 0,
		count = 0,
		d_reg = 0,
	}
	function valken_text(offset)
		if TEXT_VOICE == false then return end
		local a_reg = cpu.state["A"].value
		if a_reg == 0x0000 then
			local dump_bytes = 0
			for i = 0, 4 do
				local val = mem:read_u8(0x7E0000 + 0x2030 + i)
				dump_bytes = (dump_bytes * 0x100) + val
			end
			if dump_bytes ~= demo_text.buf then
				local d_reg = cpu.state["D"].value
				local flag = 0
				if demo_text.d_reg ~= d_reg then demo_text.count = 0 flag = 1 end
				if d_reg == 0x1f56 then
					if dump_bytes == 0xF5FF803000 then demo_text.count = demo_text.count + 1 flag = 1 end
				end
				if flag == 1 then
					local voice = 0
					local wait = 0
					local stage = mem:read_u8(0x19d0)
					if demo_text.count == 1 then voice = 0xf011 end
					if demo_text.count == 2 then voice = 0xf021 end
					if demo_text.count == 3 then voice = 0xf012 end
					if demo_text.count == 4 then voice = 0xf031 end
					if d_reg == 0x1F57 and dump_bytes == 0xF5FF006000 then voice = 0xf110 wait = 200 end -- opening demo
					if d_reg == 0x1F57 and dump_bytes == 0xFFFF480000 then voice = 0xf111 wait = 260 end -- ending demo 1
					if d_reg == 0x1F57 and dump_bytes == 0xFFFF48000F then voice = 0xf112 wait = 260 end -- ending demo 2
					if d_reg == 0x1F4B and stage == 0x00 then voice = 0x1010 wait = 100 end -- stage1 begin
					if d_reg == 0x1F4B and stage == 0x01 then voice = 0x2010 wait = 100 end -- stage2 begin
					if d_reg == 0x1F4B and stage == 0x02 then voice = 0x3010 wait = 100 end -- stage3 begin
					if d_reg == 0x1F4B and stage == 0x05 then voice = 0x4010 wait = 100 end -- stage4 begin
					if d_reg == 0x1F4B and stage == 0x07 then voice = 0x5010 wait = 100 end -- stage5 begin
					if d_reg == 0x1F4B and stage == 0x09 then voice = 0x6010 wait = 100 end -- stage6 begin
					if d_reg == 0x1F4B and stage == 0x0c then voice = 0x7010 wait = 100 end -- stage7 begin

					if voice > 0 then
						if wait > 0 then
							set_frames_wait_once(wait_voice, wait, voice)
						else
							fmod:play(voice)
						end
					end

					--MES("D:%04X C:%d S:%02X B:%06X", d_reg, demo_text.count, stage, dump_bytes)
				end
				demo_text.d_reg = d_reg
			end
			demo_text.buf = dump_bytes
		end
	end
	set_read_handlers(":maincpu", 0x80b6c7, valken_text, 1)

	local CHAR_ID_MAP = {
		[0x4ec] = 0x1, -- Jake
		[0x1e2] = 0x1, -- Jake
--		[0x156] = 0x2, -- Claire
		[0x15b] = 0x2, -- Claire
		[0x65b] = 0x2, -- Claire
--		[0x6eb] = 0x3, -- Captain
		[0xce2] = 0x4, -- Herman
		[0x2ac] = 0x5, -- Kurt
--		[0x26f] = 0x6, -- Veldark
		[0x541] = 0x6, -- Veldark
--		[0x145] = 0x6, -- Veldark
--		[0x845] = 0x7, -- Enemy Soldier
--		[0x154] = 0x8, -- Rick
		[0x2a1] = 0xa, -- Soldier
--		[0x1ac] = 0xa, -- Soldier
--		[0xbf4] = 0x9, -- President
--		[0xa4c] = 0x9, -- President
	}

	--Char: キャラクターID
	--	0x1 : ジェイク
	--	0x2 : クレア
	--	0x3 : 艦長
	--	0x4 : ハーマン
	--	0x5 : カーツ
	-- 	0x6 : 敵 ベルダーク少佐
	-- 	0x7 : 敵 一般兵士
	-- 	0x8 : 敵 リック
	-- 	0x9 : 友軍 一般兵
	-- 	0xA : 敵 大統領 (シェルマーク)
	-- 	0xB : 友軍 一般兵2

	-- キーの作り方: (A_VAL << 24) | I_VAL
	-- 値の構造    : 0x[Stage:4][Scene:4][Char:4][Text:4]
	-- ※Textは【各シーン内における、そのキャラクターごとの発言連番】です。

	local DialogueManager = {
		id_table = {

		-- Stage共通
		-- クレア (0x2)
		[(0x858805 << 24) | 0x00FF] = 0xf020, -- 「ジェイク、防御フィールド出力低下。危険です！」
		-- ジェイク (0x1)
		[(0x8587FA << 24) | 0x2518] = 0xf010, -- 「うわっ」

		-- ==========================================
		-- STAGE 1
		-- ==========================================

		-- Stage 1 / Scene 1 (オープニング突入)
		-- 艦長 (0x3)
		[(0x858835 << 24) | 0x1C11] = 0x1131, -- 「これより本艦は、敵のコロニーへ突入する」
		[(0x858835 << 24) | 0xF0E2] = 0x1132, -- 「目標は、コロニー内で建造中の戦艦だ」
		[(0x858835 << 24) | 0x532A] = 0x1133, -- 「アサルトスーツ小隊は突入後発進しろ」

		-- Stage 1 / Scene 2 (ジェイク発進)
		-- ジェイク (0x1)
		[(0x858824 << 24) | 0x2111] = 0x1211, -- 「こちらジェイク、発進する！」

		-- Stage 1 / Scene 3 (粒子砲の警告)
		-- クレア (0x2)
		[(0x85889C << 24) | 0xF03F] = 0x1321, -- 「艦長！敵戦艦の艦首にエネルギー反応！」
		[(0x85889C << 24) | 0x3FA5] = 0x1322, -- 「本艦の真正面です！」
		-- 艦長 (0x3)
		[(0x85889C << 24) | 0x090A] = 0x1331, -- 「なにっ！もう粒子砲を撃てるというのか！」
		-- ジェイク (0x1)
		[(0x85889C << 24) | 0x844B] = 0x1311, -- 「エネルギーユニットは、接続されちまったのか？」
		-- クレア (0x2)
		[(0x85889C << 24) | 0x0B12] = 0x1323, -- 「まだです！ でも時間がないわ！」
		-- ジェイク (0x1)
		[(0x85889C << 24) | 0x4139] = 0x1312, -- 「了解。それは俺が叩く！ バーシスは後退してくれ」

		-- Stage 1 / Scene 4 (ユニット位置確認)
		-- クレア (0x2)
		[(0x85891D << 24) | 0x844B] = 0x1421, -- 「エネルギーユニットは敵艦艦尾にあるはずです」
		[(0x85891D << 24) | 0xA80D] = 0x1422, -- 「レーダーで確認できるわ」
		-- ジェイク (0x1)
		[(0x85891D << 24) | 0x84F0] = 0x1411, -- 「ok でもまだ範囲外なようだ」

		-- Stage 1 / Scene 5 (建造中への愚痴)
		-- ハーマン (0x4)
		[(0x858958 << 24) | 0x331D] = 0x1541, -- 「くそっ！こいつのどこが建造中なんだよ！」
		-- ジェイク (0x1)
		[(0x858958 << 24) | 0x3EE7] = 0x1511, -- 「ぼやくなよハーマン」

		-- Stage 1 / Scene 6 (カーツの報告)
		-- カーツ (0x5)
		[(0x85897C << 24) | 0x2111] = 0x1651, -- 「こちらカーツです」
		[(0x85897C << 24) | 0x844B] = 0x1652, -- 「エネルギーユニットを確認しました！」
		[(0x85897C << 24) | 0x2BF1] = 0x1653, -- 「距離約１３０！」
		-- ジェイク (0x1)
		[(0x85897C << 24) | 0x4139] = 0x1611, -- 「了解！ まだまだ遠いな・・・」


		-- Stage 1 / Scene 7 (ハーマン被弾・離脱)
		-- ハーマン (0x4)
		[(0x8589BA << 24) | 0x2518] = 0x1741, -- 「うわぁ」
		-- ジェイク (0x1)
		[(0x8589BA << 24) | 0x1845] = 0x1711, -- 「どうした？ハーマン」
		-- ハーマン (0x4)
		[(0x8589BA << 24) | 0x2DF1] = 0x1742, -- 「脚に一発くらっちまった でもまだやれるぜ！」
		-- ジェイク (0x1)
		[(0x8589BA << 24) | 0x91B1] = 0x1712, -- 「ムリするな。バーシスに帰還しろ」
		-- ハーマン (0x4)
		[(0x8589BA << 24) | 0xA922] = 0x1743, -- 「りょ、了解・・・」

		-- Stage 1 / Scene 8 (ユニット発見)
		-- ジェイク (0x1)
		[(0x858A59 << 24) | 0x2111] = 0x1811, -- 「こちらジェイク、」
		[(0x858A59 << 24) | 0x844B] = 0x1812, -- 「エネルギーユニットを発見した。」
		-- クレア (0x2)
		[(0x858A59 << 24) | 0x4139] = 0x1821, -- 「了解！ただちに破壊してください。」
		[(0x858A59 << 24) | 0x3304] = 0x1822, -- 「いそいでっ！」

		-- Stage 1 / Scene 9 (破壊・離脱)
		-- ジェイク (0x1)
		[(0x858A90 << 24) | 0x133E] = 0x1911, -- 「やった！破壊したぞ！」
		-- 艦長 (0x3)
		[(0x858A9F << 24) | 0x5630] = 0x1931, -- 「よおし、全速で離脱だ！」

		-- クレア (0x2)
		[(0x858AB0 << 24) | 0x844B] = 0x1a21, -- 「エネルギーユニットが接続されてしまったわ！」
		-- 艦長 (0x3)
		[(0x858AB0 << 24) | 0x331D] = 0x1a31, -- 「くそっ！全速後退だ。」
		-- クレア (0x2)
		[(0x858AB0 << 24) | 0x4C20] = 0x1a22, -- 「きゃああ！」

		-- ==========================================
		-- STAGE 2
		-- ==========================================

		-- Stage 2 / Scene 1 (全機発進)
		-- 艦長 (0x3)
		[(0x858ADF << 24) | 0x384E] = 0x2131, -- 「全機発進だ！岩にぶつかるなよ。」
		-- クレア (0x2)
		[(0x858ADF << 24) | 0x4487] = 0x2121, -- 「侵入経路は追尾航法装置に入力してありますが、」
		[(0x858ADF << 24) | 0x1612] = 0x2122, -- 「こまかい岩は目視で避けてください。」
		-- ジェイク (0x1)
		[(0x858ADF << 24) | 0x1845] = 0x2111, -- 「どうせ、敵の迎撃があるんだ。うまくやるさ」

		-- Stage 2 / Scene 2 (ミサイル接近)
		-- クレア (0x2)
		[(0x858B3F << 24) | 0x1CF0] = 0x2221, -- 「ミサイル多数接近！かわすより破壊して！」
		-- クレア (0x2)
		[(0x8587EF << 24) | 0x0E5E] = 0x2222, -- 「気をつけて！」

		-- Stage 2 / Scene 3 (中心部到達)
		-- ジェイク (0x1)
		[(0x858B5A << 24) | 0xF049] = 0x2311, -- 「中心部に到達した。ブースターを切り離す。」
		-- クレア (0x2)
		[(0x858B5A << 24) | 0x4139] = 0x2321, -- 「了解、慎重に進んでください。」

		-- Stage 2 / Scene 4 (近接機雷)
		-- クレア (0x2)
		[(0x858BA4 << 24) | 0xF09A] = 0x2421, -- 「岩盤に近接機雷の反応があります。」
		-- ジェイク (0x1)
		[(0x858BA4 << 24) | 0x16D0] = 0x2411, -- 「分かった。警戒する。」

		-- Stage 2 / Scene 5 (加工施設への疑問)
		-- ジェイク (0x1)
		[(0x858B8A << 24) | 0xD6D5] = 0x2511, -- 「加工施設にしちゃ敵が多すぎるな・・・。」

		-- Stage 2 / Scene 6 (ハーマン施設破壊)
		-- ハーマン (0x4)
		[(0x858BC9 << 24) | 0x2111] = 0x2641, -- 「こちらハーマン、主な鉱石加工施設は破壊した」
		-- クレア (0x2)
		[(0x858BC9 << 24) | 0x4139] = 0x2621, -- 「了解、敵の攻撃に気を付けて帰還して下さい。」

		-- Stage 2 / Scene 7 (カーツ任務完了)
		-- カーツ (0x5)
		[(0x858BFF << 24) | 0x2111] = 0x2751, -- 「こちらカーツ、こちらも任務はほぼ完了。」
		-- クレア (0x2)
		[(0x858BFF << 24) | 0x4139] = 0x2721, -- 「了解、あとはあなただけね、ジェイク」
		-- ジェイク (0x1)
		[(0x858BFF << 24) | 0x1625] = 0x2711, -- 「わかっているさ」

		-- Stage 2 / Scene 8 (巨大エネルギー反応)
		-- ジェイク (0x1)
		[(0x858C32 << 24) | 0x0530] = 0x2811, -- 「よし、これでここは壊滅したも同然だな。」
		[(0x858C32 << 24) | 0x361F] = 0x2812, -- 「ん？・・・なんだ？」
		-- クレア (0x2)
		[(0x858C32 << 24) | 0x1845] = 0x2821, -- 「どうかしましたか？」
		-- ジェイク (0x1)
		[(0x858C32 << 24) | 0xF0B9] = 0x2813, -- 「前方の岩盤にエネルギー反応だ。かなりでかい。」
		-- クレア (0x2)
		[(0x858C32 << 24) | 0x2111] = 0x2822, -- 「こちらでも捕らえました。いやな予感がするわ。」
		-- ジェイク (0x1)
		[(0x858C32 << 24) | 0x39F1] = 0x2814, -- 「調べてみる。」

		-- Stage 2 / Scene 9 (機動兵器遭遇)
		-- ジェイク (0x1)
		[(0x858C9F << 24) | 0x331D] = 0x2911, -- 「くそっ！機動兵器だ！」

		-- Stage 2 / Scene A (機動兵器破壊)
		-- ジェイク (0x1)
		[(0x858CAE << 24) | 0x2111] = 0x2A11, -- 「こちらジェイク 敵機動兵器を破壊した。」
		-- クレア (0x2)
		[(0x858CAE << 24) | 0x2956] = 0x2A21, -- 「おつかれさま、作戦終了です。帰還してください」


		-- ==========================================
		-- STAGE 3
		-- ==========================================

		-- Stage 3 / Scene 1 (発進用意)
		-- 艦長 (0x3)
		[(0x858CDC << 24) | 0x384E] = 0x3131, -- 「全機発進用意！作戦通りアーク・ノバ内に進行し」
		[(0x858CDC << 24) | 0x1669] = 0x3132, -- 「内部から基地を破壊せよ」
		-- クレア (0x2)
		[(0x858CDC << 24) | 0x0D26] = 0x3121, -- 「バーシスでぎりぎりまで接近しますが」
		[(0x858CDC << 24) | 0x0335] = 0x3122, -- 「敵の対空砲火は強力です。充分、注意してください」

		-- Stage 3 / Scene 2 (進行ポイント指示)
		-- クレア (0x2)
		[(0x858D31 << 24) | 0x0D51] = 0x3221, -- 「ハーマンはポイント１４、カーツはポイント２２を通過してアーク・ノバに取りついて下さい。」
		-- ハーマン (0x4)
		[(0x858D31 << 24) | 0x4139] = 0x3241, -- 「了解！派手に決めるぜ！」

		-- Stage 3 / Scene 3 (侵入口探索)
		-- クレア (0x2)
		[(0x858D7F << 24) | 0x2AFD] = 0x3321, -- 「ジェイクはアーク・ノバ下部の侵入口を探して下さい。」
		-- ジェイク (0x1)
		[(0x858D7F << 24) | 0x2323] = 0x3311, -- 「ああ、そのつもりだ」

		-- Stage 3 / Scene 4 (ジェイクとりつき)
		-- ジェイク (0x1)
		[(0x858DAA << 24) | 0x2111] = 0x3411, -- 「こちらジェイク　アーク・ノバにとりついた。」
		-- ハーマン (0x4)
		[(0x858DAA << 24) | 0x1321] = 0x3441, -- 「ちっ！先をこされちまったな」

		-- Stage 3 / Scene 5 (カーツとりつき)
		-- カーツ (0x5)
		[(0x858DD5 << 24) | 0x0D66] = 0x3551, -- 「カーツです。アーク・ノバにとりつきました。」
		-- ジェイク (0x1)
		[(0x858DD5 << 24) | 0x1830] = 0x3511, -- 「ようし、侵入口を見つけしだい突入しろ。」

		-- Stage 3 / Scene 6 (ハッチ破壊)
		-- ジェイク (0x1)
		[(0x858E09 << 24) | 0x0D2A] = 0x3611, -- 「アーク・ノバのハッチを破壊した。」
		[(0x858E09 << 24) | 0x1C11] = 0x3612, -- 「これより突入する。」
		-- 艦長 (0x3)
		[(0x858E09 << 24) | 0x0530] = 0x3631, -- 「よし、派手に暴れてやれ」

		-- Stage 3 / Scene 7 (迎撃)
		-- ジェイク (0x1)
		[(0x858E38 << 24) | 0x4C5A] = 0x3711, -- 「じゃまするな！」

		-- Stage 3 / Scene 8 (指令室の位置)
		-- ジェイク (0x1)
		[(0x858E44 << 24) | 0x2111] = 0x3811, -- 「こちらジェイク、指令室はどこだ！？」
		-- クレア (0x2)
		[(0x858E44 << 24) | 0x0A23] = 0x3821, -- 「あなたの真下にあります。左からまわりこんで！」

		-- Stage 3 / Scene 9 (地球落下計画)
		-- 敵 (0x6)
		[(0x858E75 << 24) | 0xF04E] = 0x39b1, -- 「全員退避だ。作戦通り、この基地は地球に落とす」
		--[(0x858E75 << 24) | 0x2F6D] = 0x39b2, -- 「グランビアの出撃準備を急げ。私が出撃する。」
		-- ジェイク (0x1)
		[(0x858E75 << 24) | 0x090A] = 0x3911, -- 「なに？基地を落とすだと、どういう事だ！」

		-- Stage 3 / Scene A (目標変更)
		-- 艦長 (0x3)
		[(0x859008 << 24) | 0x1F59] = 0x3A31, -- 「みんな、よく聞け！ 敵はアーク・ノバを地球に落とすためのエンジンを作動させてしまった。攻撃目標をアーク・ノバのメイン・エンジンに変更する。」
		-- クレア (0x2)
		[(0x859008 << 24) | 0x45F1] = 0x3A21, -- 「繰り返します。全機、アーク・ノバの上部にあるエンジンを狙ってください。」

		-- Stage 3 / Scene B (爆発確認)
		-- クレア (0x2)
		[(0x858F59 << 24) | 0x0D2A] = 0x3B21, -- 「アーク・ノバ内部で大規模な爆発を確認！ 彼らはほんとうに要塞を地球に落とすつもりだわ」

		-- Stage 3 / Scene C (格納庫突入)
		-- ジェイク (0x1)
		[(0x858F1E << 24) | 0x0335] = 0x3C11, -- 「敵の格納庫を発見！これより突入する。」
		-- クレア (0x2)
		[(0x858F1E << 24) | 0x0E5E] = 0x3C21, -- 「気をつけてください。」
		[(0x858F1E << 24) | 0x698B] = 0x3C22, -- 「内部には大型兵器の反応があります。」


		-- ==========================================
		-- STAGE 3b (Stage 3後半の繰り上げ分)
		-- ==========================================

		-- Stage 3b / Scene 1 (グランビア遭遇)
		-- 敵 (0x6)
		[(0x858F8E << 24) | 0x0311] = 0x41b1, -- 「このグランビアはきさまにはとめられんぞ！」
		-- ジェイク (0x1)
		[(0x858F8E << 24) | 0x39F0] = 0x4111, -- 「要塞を地球に落とすなんて・・・ きさま、」
		[(0x858F8E << 24) | 0xED7E] = 0x4112, -- 「民間人をまきぞえにするつもりかっ！」
		-- 敵 (0x6)
		[(0x858F8E << 24) | 0x7CF0] = 0x41b2, -- 「核を使わないだけましというものだ。いくぞっ！」

		-- Stage 3b / Scene 2 (残り2分)
		-- クレア (0x2)
		[(0x85912D << 24) | 0x0D2A] = 0x4221, -- 「アーク・ノバ落下までの時間はあと２分です。エンジンに攻撃を集中してください」

		-- Stage 3b / Scene 3 (グランビア撃破)
		-- 敵 (0x6)
		[(0x858FED << 24) | 0x1665] = 0x43b1, -- 「ばかな！たった一機のアサルトスーツに・・・」

		-- Stage 3b / Scene 4 (残り1分)
		-- クレア (0x2)
		[(0x859159 << 24) | 0x1923] = 0x4421, -- 「あと１分！！まだ間に合うわ！ おねがい！ジェイク！」

		-- Stage 3b / Scene 5 (エンジン破壊催促)
		-- クレア (0x2)
		[(0x859084 << 24) | 0x3E06] = 0x4521, -- 「はやくエンジンを破壊してください。 時間がありません」

		-- Stage 3b / Scene 6 (作戦成功)
		-- クレア (0x2)
		[(0x8590A3 << 24) | 0xF076] = 0x4621, -- 「ふぅ、間に合いました。 アーク・ノバは地球への軌道から外れていきます」
		-- ジェイク (0x1)
		[(0x8590A3 << 24) | 0x4139] = 0x4611, -- 「了解・帰投する。」

		-- Stage 3b / Scene 7 (作戦失敗)
		-- クレア (0x2)
		[(0x8590D5 << 24) | 0x181B] = 0x4721, -- 「もうアーク・ノバの落下は止められません！ アーク・ノバから離脱してください。危険です。」
		-- ジェイク (0x1)
		[(0x8590D5 << 24) | 0xF1AF] = 0x4711, -- 「残念だ。こんなにも巨大な質量が地球に落ちるというのか・・・」


		-- ==========================================
		-- STAGE 4 (数値は5)
		-- ==========================================

		-- Stage 4 / Scene 1 (追撃命令)
		-- ベルダーク少佐 (0x6)
		[(0x859177 << 24) | 0x5E3D] = 0x5161, -- 「大気圏突入ぎりぎりまで、やつらを追いつめろ！」
		-- 一般兵士 (0x7)
		[(0x859177 << 24) | 0x4139] = 0x5171, -- 「了解！」
		-- リック (0x8)
		[(0x859177 << 24) | 0xA922] = 0x5181, -- 「りょ、了解！」

		-- Stage 4 / Scene 2 (大気圏突入の危機)
		-- クレア (0x2)
		[(0x85919E << 24) | 0xF03F] = 0x5221, -- 「艦長！ジェイクが」
		[(0x85919E << 24) | 0x5E3D] = 0x5222, -- 「大気圏に突入してしまいます！」
		-- 艦長 (0x3)
		[(0x85919E << 24) | 0x0D26] = 0x5231, -- 「バーシスを降下させろ！地球におりてもかまわん」

		-- Stage 4 / Scene 3 (収容要請と拒否)
		-- クレア (0x2)
		[(0x8591D4 << 24) | 0x00FF] = 0x5321, -- 「ジェイク、収容します。」
		[(0x8591D4 << 24) | 0x2017] = 0x5322, -- 「できるだけバーシスに接近してください。」
		-- ジェイク (0x1)
		[(0x8591D4 << 24) | 0x3E04] = 0x5311, -- 「いや、まだだ！こいつらを落とす！」

		-- Stage 4 / Scene 4 (逃げ遅れ)
		-- ベルダーク少佐 (0x6)
		[(0x859269 << 24) | 0x3C33] = 0x5461, -- 「そろそろ限界だな・・・よし、艇に戻るぞ！」
		-- リック (0x8)
		[(0x859269 << 24) | 0x28C5] = 0x5481, -- 「ベルダーク少佐！」
		[(0x859269 << 24) | 0x0F26] = 0x5482, -- 「バ、バーニアの出力が上がらない・・・」
		[(0x859269 << 24) | 0x0F07] = 0x5483, -- 「た、たすけて・・・」
		-- ベルダーク少佐 (0x6)
		[(0x859269 << 24) | 0x1204] = 0x5462, -- 「いま行くぞ！リック！」
		-- 一般兵士 (0x7)
		[(0x859269 << 24) | 0x22B7] = 0x5471, -- 「むりです少佐、もう間に合いません！」
		-- ベルダーク少佐 (0x6)
		[(0x859269 << 24) | 0x331D] = 0x5463, -- 「くそっ・・・！」

		-- Stage 4 / Scene 5 (リック救出)
		-- ジェイク (0x1)
		[(0x8592D7 << 24) | 0x0335] = 0x5511, -- 「敵の一機が逃げおくれたらしい。」
		[(0x8592D7 << 24) | 0x9EF0] = 0x5512, -- 「助けてやってくれ！」
		-- クレア (0x2)
		[(0x8592D7 << 24) | 0x21B7] = 0x5521, -- 「むちゃです！」
		[(0x8592D7 << 24) | 0x0D26] = 0x5522, -- 「バーシスのバランスが崩れてしまうわ！」
		-- 艦長 (0x3)
		[(0x8592D7 << 24) | 0xF086] = 0x5531, -- 「見殺しにはできん。やれるだけやってみろ！」
		-- クレア (0x2)
		[(0x8592D7 << 24) | 0x0F25] = 0x5523, -- 「わ、わかりました！」

		-- Stage 4 / Scene 6 (突入速度)
		-- クレア (0x2)
		[(0x859367 << 24) | 0x4461] = 0x5621, -- 「突入角度が深すぎます！降下速度が落ちません！」

		-- Stage 4 / Scene 7 (安否確認)
		-- ジェイク (0x1)
		[(0x859385 << 24) | 0xF03D] = 0x5711, -- 「大丈夫か！クレア！」
		-- クレア (0x2)
		[(0x859385 << 24) | 0x0F32] = 0x5721, -- 「え、ええ・・・なんとか。あなたは？」
		-- ジェイク (0x1)
		[(0x859385 << 24) | 0x1311] = 0x5712, -- 「こっちも大丈夫だ。」

		-- クレア (0x2)
		[(0x8595A0 << 24) | 0x0D2A] = 0x5722, -- 「アーク・ノバが地上に激突しました！」
		-- ジェイク (0x1)
		[(0x8595A0 << 24) | 0x1145] = 0x5713, -- 「どこに落ちた！？」
		-- クレア (0x2)
		[(0x8595A0 << 24) | 0x28C5] = 0x5723, -- 「ベルウェイ統合基地の北２０マイルです・・・」
		-- クレア (0x2)
		[(0x8595A0 << 24) | 0x031D] = 0x5724, -- 「近くの都市もいくつか巻き込まれたわ・・・・」
		-- カーツ (0x5)
		[(0x8595A0 << 24) | 0x1F0A] = 0x5751, -- 「なんてこった・・・」
		-- ジェイク (0x1)
		[(0x8595A0 << 24) | 0x1AAD] = 0x5714, -- 「奴らめ・・・・・・・・・・・・・・許さん！」

		-- Stage 4 / Scene 8 (敵輸送艇接近)
		-- クレア (0x2)
		[(0x8593B2 << 24) | 0x1323] = 0x5821, -- 「あっ！敵の輸送艇が接近してきます。」
		-- 艦長 (0x3)
		[(0x8593B2 << 24) | 0x1DF0] = 0x5831, -- 「数は？」
		-- クレア (0x2)
		[(0x8593B2 << 24) | 0xF1B8] = 0x5822, -- 「一隻だけのようですが、アサルトスーツを数機」
		[(0x8593B2 << 24) | 0x7B72] = 0x5823, -- 「射出しています。」
		-- 艦長 (0x3)
		[(0x8593B2 << 24) | 0x0D51] = 0x5832, -- 「ハーマン！カーツ！迎撃しろ！」
		-- ハーマン (0x4)
		[(0x8593B2 << 24) | 0x4139] = 0x5841, -- 「了解！」
		-- カーツ (0x5)
		--[(0x8593B2 << 24) | 0x4139] = 0x5851, -- 「了解！」

		-- Stage 4 / Scene 9 (損傷機体)
		-- ジェイク (0x1)
		[(0x859410 << 24) | 0x1B34] = 0x5911, -- 「俺もでるぞ！」
		-- クレア (0x2)
		[(0x859410 << 24) | 0x370B] = 0x5921, -- 「だめです！あなたの機体は損傷がはげしいわ！」
		-- ジェイク (0x1)
		[(0x859410 << 24) | 0x07F0] = 0x5912, -- 「心配してもらうほどじゃないさ」

		-- Stage 4 / Scene A (ハーマン撃墜)
		-- ハーマン (0x4)
		[(0x859446 << 24) | 0x331D] = 0x5A41, -- 「くそっ！こいつ素早い！」
		-- クレア (0x2)
		[(0x859446 << 24) | 0x1845] = 0x5A21, -- 「どうしました！？」
		-- ハーマン (0x4)
		[(0x859446 << 24) | 0x0335] = 0x5A42, -- 「敵のリーダーらしい！こっちに向かって・・・」
		[(0x859446 << 24) | 0x2588] = 0x5A43, -- 「ぐわぁっ！・・・・」
		[(0x859446 << 24) | 0x0101] = 0x5A44, -- 「（通信途絶のノイズ）」
		-- ジェイク (0x1)
		--[(0x859446 << 24) | 0x1845] = 0x5A11, -- 「どうした！？ハーマン！」

		-- Stage 4 / Scene B (反応消失)
		-- クレア (0x2)
		[(0x859499 << 24) | 0x0D51] = 0x5B21, -- 「ハーマンの機体の反応が消えました！」
		-- ジェイク (0x1)
		[(0x859499 << 24) | 0x1665] = 0x5B11, -- 「ばかなっ！？誰がハーマンを！」

		-- Stage 4 / Scene C (因縁の通信割込)
		-- ジェイク (0x1)
		[(0x8594C1 << 24) | 0x0411] = 0x5C11, -- 「こいつ、さっきの！」
		-- ベルダーク少佐 (0x6)
		[(0x8594C1 << 24) | 0x0712] = 0x5C61, -- 「また会ったな」
		-- ジェイク (0x1)
		[(0x8594C1 << 24) | 0x090A] = 0x5C12, -- 「なにっ！通信に割込んできた！？」
		-- ベルダーク少佐 (0x6)
		[(0x8594C1 << 24) | 0x4691] = 0x5C62, -- 「リックを助けてくれた礼はいわせてもらう。」
		[(0x8594C1 << 24) | 0x150B] = 0x5C63, -- 「だが彼は返してもらうぞ」
		-- ジェイク (0x1)
		[(0x8594C1 << 24) | 0x3B1E] = 0x5C13, -- 「させるかっ！」

		-- Stage 4 / Scene D (リック回収)
		-- ベルダーク少佐 (0x6)
		[(0x859518 << 24) | 0xF03D] = 0x5D61, -- 「大丈夫か、リック」
		-- リック (0x8)
		[(0x859518 << 24) | 0x1306] = 0x5D81, -- 「はっ、はい・・・少佐」
		-- ベルダーク少佐 (0x6)
		[(0x859518 << 24) | 0x0530] = 0x5D62, -- 「よし、あいさつはこのぐらいにしておこう」
		[(0x859518 << 24) | 0x2320] = 0x5D63, -- 「ひきあげるぞ！」

		-- Stage 4 / Scene E (取り逃がし)
		-- ジェイク (0x1)
		[(0x85954F << 24) | 0x0C12] = 0x5E11, -- 「まてっ！」

		-- Stage 4 / Scene F (撤退と敬礼)
		-- クレア (0x2)
		[(0x859558 << 24) | 0x2A35] = 0x5F21, -- 「敵アサルトスーツ隊、撤退してゆきます・・・」
		-- ジェイク (0x1)
		[(0x859558 << 24) | 0x1D21] = 0x5F11, -- 「ちくしょう、ハーマン ・・・・ちくしょう！！」
		-- 艦長 (0x3)
		[(0x859558 << 24) | 0xA0F0] = 0x5F31, -- 「総員、ハーマンに敬礼！」


		-- ==========================================
		-- STAGE 5 (数値は6)
		-- ==========================================

		-- Stage 5 / Scene 1 (傍受と激励)
		-- クレア (0x2)
		[(0x85967D << 24) | 0xF03F] = 0x6121, -- 「艦長！敵基地からの通信を傍受しました！」
		[(0x85967D << 24) | 0x472E] = 0x6122, -- 「シャトル発射の秒読みが開始されたようです！」
		-- 艦長 (0x3)
		[(0x85967D << 24) | 0xA5F0] = 0x6131, -- 「AS隊へのブースターの装着は完了しているか？」
		-- クレア (0x2)
		[(0x85967D << 24) | 0x0406] = 0x6123, -- 「はい！」
		-- 艦長 (0x3)
		[(0x85967D << 24) | 0x0530] = 0x6132, -- 「よし、少し早いが射出しろ。」
		-- クレア (0x2)
		[(0x85967D << 24) | 0x4139] = 0x6124, -- 「了解。」
		[(0x85967D << 24) | 0x96F0] = 0x6125, -- 「聞こえましたか？」
		-- ジェイク (0x1)
		[(0x85967D << 24) | 0x2323] = 0x6111, -- 「ああ、・・・」
		-- クレア (0x2)
		[(0x85967D << 24) | 0x326F] = 0x6126, -- 「ねえ、元気をだして」
		[(0x85967D << 24) | 0x0D51] = 0x6127, -- 「ハーマンの事はあなたのせいじゃないわ。」
		-- ジェイク (0x1)
		[(0x85967D << 24) | 0x1625] = 0x6112, -- 「わかってるよ、クレア。」

		-- Stage 5 / Scene 2 (戦闘機の警告)
		-- クレア (0x2)
		[(0x859729 << 24) | 0xB49C] = 0x6221, -- 「対空砲は無視していいわ。でも戦闘機には注意して」

		-- Stage 5 / Scene 3 (ブースターパージ)
		-- ジェイク (0x1)
		[(0x859749 << 24) | 0x0D7A] = 0x6311, -- 「ブースターの燃料がきれた！切り離す！」

		-- Stage 5 / Scene 4 (シャトル防衛線)
		-- 一般兵 (0x7)
		[(0x859762 << 24) | 0x1C11] = 0x6471, -- 「これ以上すすませるな！シャトルをまもるんだ！」

		-- Stage 5 / Scene 5 (敵撃破)
		-- 一般兵 (0x7)
		[(0x85977E << 24) | 0x2518] = 0x6571, -- 「うわっ！」

		-- Stage 5 / Scene 6 (発射場侵入)
		-- ジェイク (0x1)
		[(0x859787 << 24) | 0x724F] = 0x6611, -- 「発射場に侵入する。」
		-- クレア (0x2)
		[(0x859787 << 24) | 0x472E] = 0x6621, -- 「シャトルのサイロまではまだ遠いわ。気をつけて」

		-- Stage 5 / Scene 7 (サイロ最下層)
		-- ジェイク (0x1)
		[(0x8597AF << 24) | 0x66F1] = 0x6711, -- 「迷子になりそうだ」
		-- クレア (0x2)
		[(0x8597AF << 24) | 0x43F0] = 0x6721, -- 「最下層は底なしです！ 落ちたらあがってこれないわ！」

		-- Stage 5 / Scene 8 (大型兵器迎撃)
		-- ジェイク (0x1)
		[(0x8597DE << 24) | 0x0311] = 0x6811, -- 「このデカブツめ！落ちろ」

		-- Stage 5 / Scene 9 (シャトル目前)
		-- ジェイク (0x1)
		[(0x8597EE << 24) | 0x472E] = 0x6911, -- 「シャトルはこの奥か？」
		-- クレア (0x2)
		[(0x8597EE << 24) | 0x1833] = 0x6921, -- 「そうです、いそいで！」

		-- Stage 5 / Scene A (シャトル発射・ブースター要請)
		-- ジェイク (0x1)
		[(0x85980A << 24) | 0x1205] = 0x6A11, -- 「しまった！まにあわなかったか！」
		-- クレア (0x2)
		[(0x85980A << 24) | 0xC95F] = 0x6A21, -- 「ロケットブースターを射出します。」
		[(0x85980A << 24) | 0xABB6] = 0x6A22, -- 「装着後、シャトルを追撃してください。」
		-- ジェイク (0x1)
		[(0x85980A << 24) | 0x1625] = 0x6A12, -- 「わかった、早くしてくれ」

		-- Stage 5 / Scene B (大空の迎撃)
		-- 一般兵 (0x7)
		[(0x859853 << 24) | 0x69F1] = 0x6B71, -- 「相手は一機だけだ。撃ち落とせ！ シャトルをやらせるな！」

		-- Stage 5 / Scene C (シャトル破壊成功)
		-- ジェイク (0x1)
		[(0x8598C0 << 24) | 0x472E] = 0x6C11, -- 「シャトルのロケットが機能を停止した。 こいつはもうスクラップだ！」

		-- Stage 5 / Scene D (帰還)
		-- クレア (0x2)
		[(0x8598E9 << 24) | 0x2D6A] = 0x6D21, -- 「作戦成功です。バーシスに着艦してください。」
		-- ジェイク (0x1)
		[(0x8598E9 << 24) | 0x7327] = 0x6D11, -- 「クレア？」
		-- クレア (0x2)
		[(0x8598E9 << 24) | 0x090A] = 0x6D22, -- 「なに？」
		-- ジェイク (0x1)
		[(0x8598E9 << 24) | 0x0311] = 0x6D12, -- 「この戦争は早く終わらせなきゃな・・・。 ハーマンのためにも。」
		-- クレア (0x2)
		[(0x8598E9 << 24) | 0x1833] = 0x6D23, -- 「そうね、ジェイク」

		-- Stage 5 / Scene E (引き離し/失敗用？)
		-- ジェイク (0x1)
		[(0x859876 << 24) | 0x472E] = 0x6E11, -- 「シャトルのスピードが落ちない！ ひきはなされる！」

		-- Stage 5 / Scene F (大気圏離脱/ゲームオーバー用？)
		-- クレア (0x2)
		[(0x859895 << 24) | 0x472E] = 0x6F21, -- 「シャトルがまもなく大気圏を離脱します・・・」
		-- ジェイク (0x1)
		[(0x859895 << 24) | 0x0101] = 0x6F11, -- 「・・・すまん。」
		-- クレア (0x2)
		[(0x859895 << 24) | 0x00FF] = 0x6F22, -- 「ジェイク・・・」


		-- ==========================================
		-- STAGE 6 (数値は7)
		-- ==========================================

		-- Stage 6 / Scene 1 (作戦会議と先行)
		-- 艦長 (0x3)
		[(0x859939 << 24) | 0x2C1E] = 0x7131, -- 「さけて移動することはできんということか？」
		-- クレア (0x2)
		[(0x859939 << 24) | 0x0406] = 0x7121, -- 「はい。あと６時間以内に合流地点に着かなければ」
		[(0x859939 << 24) | 0x5B28] = 0x7122, -- 「ソルジャーソウル作戦に参加できません。」
		[(0x859939 << 24) | 0x0333] = 0x7123, -- 「そのためにはこの山を越えないと・・・」
		-- ジェイク (0x1)
		[(0x859939 << 24) | 0x1934] = 0x7111, -- 「俺とカーツが先行して高射砲を破壊する。」
		-- 艦長 (0x3)
		[(0x859939 << 24) | 0x47F0] = 0x7132, -- 「陣地の近くには偵察機がうろついているはずだ。」
		[(0x859939 << 24) | 0x1420] = 0x7133, -- 「できるだけ発見されないように行動しろ。」
		-- ジェイク (0x1)
		[(0x859939 << 24) | 0x4139] = 0x7112, -- 「了解。いくぞカーツ」
		-- カーツ (0x5)
		--[(0x859939 << 24) | 0x0406] = 0x7151, -- 「はい。」

		-- Stage 6 / Scene 2 (被弾/遭遇)
		-- ジェイク (0x1)
		[(0x8599EF << 24) | 0x2518] = 0x7211, -- 「うわっ！」

		-- Stage 6 / Scene 3 (スノークス発見報告)
		-- 一般兵 (0x7)
		[(0x8599F8 << 24) | 0x2111] = 0x7371, -- 「こちらスノークス！敵のアサルトスーツだ！ あの艦の奴にちがいない。警戒せよ！」

		-- Stage 6 / Scene 4 (スカウト被発見)
		-- ジェイク (0x1)
		[(0x859A24 << 24) | 0x2111] = 0x7411, -- 「こちらジェイク！スカウトに見つかった！」
		-- 艦長 (0x3)
		[(0x859A24 << 24) | 0x0D26] = 0x7431, -- 「バーシスの速度を落とすわけにはいかん！ 敵基地内に強行侵入しろ」
		-- ジェイク (0x1)
		[(0x859A24 << 24) | 0x4139] = 0x7412, -- 「了解！」

		-- Stage 6 / Scene 5 (無人の不気味さ)
		-- ジェイク (0x1)
		[(0x859A61 << 24) | 0x1535] = 0x7511, -- 「敵がどこにもいないな」
		-- カーツ (0x5)
		[(0x859A61 << 24) | 0x72F1] = 0x7551, -- 「妙ですね」

		-- Stage 6 / Scene 6 (伏兵遭遇)
		-- ジェイク (0x1)
		[(0x859A77 << 24) | 0x2518] = 0x7611, -- 「うわぁ！なんだこいつは」

		-- Stage 6 / Scene 7 (山頂到達の報告)
		-- ジェイク (0x1)
		[(0x859A87 << 24) | 0x0530] = 0x7711, -- 「よし、やったぞ！」
		-- クレア (0x2)
		[(0x859A87 << 24) | 0x2111] = 0x7721, -- 「こちらバーシス！本艦はまもなく山頂に達します」
		-- ジェイク (0x1)
		[(0x859A87 << 24) | 0x653E] = 0x7712, -- 「やばいな！急ぐぞ、カーツ！」

		-- Stage 6 / Scene 8 (建設機械)
		-- ジェイク (0x1)
		[(0x859ABE << 24) | 0x1111] = 0x7811, -- 「ここは本当に対空陣地なのか？ 建設機械ばかりじゃないか！」
		-- カーツ (0x5)
		[(0x859ABE << 24) | 0x231E] = 0x7851, -- 「さあね、とにかくもう少し探索してみましょう。」

		-- Stage 6 / Scene 9 (高射砲移動)
		-- ジェイク (0x1)
		[(0x859AFC << 24) | 0x1323] = 0x7911, -- 「あった！あれだ。バーシス！高射砲を発見」
		[(0x859AFC << 24) | 0x4207] = 0x7912, -- 「したぞ！」
		-- カーツ (0x5)
		[(0x859AFC << 24) | 0xF03D] = 0x7951, -- 「大変です！高射砲が外にでて行きます！」
		-- ジェイク (0x1)
		[(0x859AFC << 24) | 0x0D26] = 0x7913, -- 「バーシスが危ない！カーツ、外にでるぞ！」

		-- Stage 6 / Scene A (機動兵器と対空砲)
		-- カーツ (0x5)
		[(0x859C34 << 24) | 0x6338] = 0x7A51, -- 「機動兵器だ！！」
		-- ジェイク (0x1)
		[(0x859C34 << 24) | 0xB49C] = 0x7A11, -- 「対空砲が先だ！そんな奴に構うな！」
		-- カーツ (0x5)
		[(0x859C34 << 24) | 0x1833] = 0x7A52, -- 「そうもいかない様です」

		-- Stage 6 / Scene B (バーシス被弾危機)
		-- クレア (0x2)
		[(0x859B45 << 24) | 0xF03F] = 0x7B21, -- 「艦長！敵の砲撃です！」
		-- 艦長 (0x3)
		[(0x859B45 << 24) | 0x00FF] = 0x7B31, -- 「ジェイク達はどうした！？」
		-- クレア (0x2)
		[(0x859B45 << 24) | 0xF16C] = 0x7B22, -- 「砲台を追撃中のもようです」

		-- Stage 6 / Scene C (撃破)
		-- ジェイク (0x1)
		[(0x859C61 << 24) | 0x1830] = 0x7C11, -- 「ようし、落ちたぞ！」

		-- Stage 6 / Scene D (格納庫被弾)
		-- クレア (0x2)
		[(0x859B70 << 24) | 0x532A] = 0x7D21, -- 「アサルトスーツ格納庫に被弾！」
		-- ジェイク (0x1)
		[(0x859B70 << 24) | 0xA8F0] = 0x7D11, -- 「待ってろよ！今こいつをぶちこわしてやるからな」

		-- クレア (0x2)
		[(0x859BA1 << 24) | 0x8BF0] = 0x7D22, -- 「重力制御装置に被弾！　高度がさがります！」
		-- 艦長 (0x3)
		[(0x859BA1 << 24) | 0x7A53] = 0x7D31, -- 「サブエンジンでフォローしろ！」
		-- ジェイク (0x1)
		[(0x859BA1 << 24) | 0x331D] = 0x7D12, -- 「くそう！二機だけじゃもたないか！」

		-- クレア (0x2)
		[(0x859BE4 << 24) | 0x22F0] = 0x7D23, -- 「メインエンジン貫通！爆発します！！」
		[(0x859BE4 << 24) | 0x4C20] = 0x7D24, -- 「きゃああっ！」
		-- ジェイク (0x1)
		[(0x859BE4 << 24) | 0x7327] = 0x7D13, -- 「クレア！！」

		-- Stage 6 / Scene E (高射砲始末)
		-- ジェイク (0x1)
		[(0x859C0C << 24) | 0x72EF] = 0x7E11, -- 「高射砲は全部始末した」
		-- クレア (0x2)
		[(0x859C0C << 24) | 0x2223] = 0x7E21, -- 「ありがとう。」
		-- ジェイク (0x1)
		[(0x859C0C << 24) | 0xF156] = 0x7E12, -- 「お安い御用さ、クレア」

		-- Stage 6 / Scene F (作戦完了)
		-- ジェイク (0x1)
		[(0x859C6F << 24) | 0x181B] = 0x7F11, -- 「もう何もいないだろうな」
		-- クレア (0x2)
		[(0x859C6F << 24) | 0x3232] = 0x7F21, -- 「ええ、もう何の反応もありません。」
		-- ジェイク (0x1)
		[(0x859C6F << 24) | 0x2219] = 0x7F12, -- 「とりあえず生きのびたな」
		-- クレア (0x2)
		[(0x859C6F << 24) | 0x0101] = 0x7F22, -- 「・・・そうね」
		-- 艦長 (0x3)
		[(0x859C6F << 24) | 0x0530] = 0x7F31, -- 「よし、本隊と合流するぞ」


		-- ==========================================
		-- STAGE 7 (数値は8)
		-- ==========================================

		-- Stage 7 / Scene 1 (バーシス浮上不能・決意)
		-- クレア (0x2)
		[(0x859CB6 << 24) | 0x181B] = 0x8121, -- 「もうバーシスは浮上不能です！」
		[(0x859CB6 << 24) | 0x0A23] = 0x8122, -- 「あなたたちだけが頼りよジェイク」
		-- ジェイク (0x1)
		[(0x859CB6 << 24) | 0x2323] = 0x8111, -- 「ああ、わかってるさ！」
		-- クレア (0x2)
		[(0x859CB6 << 24) | 0xFD01] = 0x8123, -- 「生きてかえってきて」
		-- ジェイク (0x1)
		[(0x859CB6 << 24) | 0x2324] = 0x8112, -- 「ああ、かならず！」

		-- Stage 7 / Scene 2 (艦長の命令)
		-- 艦長 (0x3)
		[(0x859D0A << 24) | 0x2078] = 0x8231, -- 「生きている砲台は、全て開け、応戦するんだ！」
		-- クレア (0x2)
		[(0x859D0A << 24) | 0x4139] = 0x8221, -- 「了解！」

		-- Stage 7 / Scene 3 (数の脅威)
		-- ジェイク (0x1)
		[(0x859D2A << 24) | 0x0635] = 0x8311, -- 「敵はザコばかりだが数は多いぞ！注意しろ！」
		-- カーツ (0x5)
		[(0x859D2A << 24) | 0x4139] = 0x8351, -- 「了解！ジェイクもムチャしないでください」

		-- Stage 7 / Scene 4 (バーシス被弾)
		-- ジェイク (0x1)
		[(0x859DB8 << 24) | 0x8382] = 0x8411, -- 「議事堂はもうすぐだ！」
		-- クレア (0x2)
		[(0x859DB8 << 24) | 0x4487] = 0x8421, -- 「侵入して議会を押さえ」
		[(0x859DB8 << 24) | 0x4C20] = 0x8422, -- 「きゃああっ！」
		-- ジェイク (0x1)
		[(0x859DB8 << 24) | 0x1845] = 0x8412, -- 「どうしたっ！？」
		-- クレア (0x2)
		[(0x859DB8 << 24) | 0x0D26] = 0x8423, -- 「バーシスが被弾！」
		[(0x859DB8 << 24) | 0x1B17] = 0x8424, -- 「でも、まだ大丈夫。もちこたえてるわ。」

		-- Stage 7 / Scene 5 (議事堂侵入と通信途絶)
		-- ジェイク (0x1)
		[(0x859E16 << 24) | 0x2111] = 0x8511, -- 「こちらジェイク！これより侵入する！」
		-- クレア (0x2)
		[(0x859E16 << 24) | 0x4139] = 0x8521, -- 「了解！議会の議員達を連行し・・・・・・・」
		-- ジェイク (0x1)
		[(0x859E16 << 24) | 0x3602] = 0x8512, -- 「！？・・・・」
		[(0x859E16 << 24) | 0x1845] = 0x8513, -- 「どうした！？バーシス！応答しろ、クレア！」

		-- Stage 7 / Scene 6 (孤独な突入)
		-- ジェイク (0x1)
		[(0x859E63 << 24) | 0x4487] = 0x8611, -- 「侵入口をみつけた。応答してくれバーシス！」
		[(0x859E63 << 24) | 0x370B] = 0x8612, -- 「だめか・・・」

		-- Stage 7 / Scene 7 (大統領連行と通信割込)
		-- ジェイク (0x1)
		[(0x859E90 << 24) | 0x0311] = 0x8711, -- 「この議会場は合衆国軍が押えた。投降しろ！」
		-- 大統領 (0x9)
		[(0x859E90 << 24) | 0x131D] = 0x8791, -- 「くっ！」
		-- ジェイク (0x1)
		[(0x859E90 << 24) | 0x1E20] = 0x8712, -- 「きさまがシェルマーク大統領か！」
		-- 大統領 (0x9)
		[(0x859E90 << 24) | 0x0101] = 0x8792, -- 「・・・そうだ。」
		-- ジェイク (0x1)
		[(0x859E90 << 24) | 0x1256] = 0x8713, -- 「おまえを連行する！」
		-- ベルダーク少佐 (0x6)
		[(0x859E90 << 24) | 0x1833] = 0x8761, -- 「そうはさせん！」
		-- ジェイク (0x1)
		[(0x859E90 << 24) | 0x1E20] = 0x8714, -- 「きさまは！」

		-- Stage 7 / Scene 8 (ベルダークの納得)
		-- ジェイク (0x1)
		[(0x859EEB << 24) | 0x0E34] = 0x8811, -- 「俺を殺しても、もうどうにもならんぞ！」
		-- ベルダーク少佐 (0x6)
		[(0x859EEB << 24) | 0x1F33] = 0x8861, -- 「そんなことは関係ない！ 俺は俺自身が納得できるまで戦う！」

		-- Stage 7 / Scene 9 (大統領逃走)
		-- ジェイク (0x1)
		[(0x859F2A << 24) | 0x1665] = 0x8911, -- 「ばかなやつめ・・・はっ！大統領は？・・・」
		[(0x859F2A << 24) | 0x1662] = 0x8912, -- 「上かっ！」

		-- Stage 7 / Scene A (大統領の最期)
		-- ジェイク (0x1)
		[(0x859F4C << 24) | 0x181B] = 0x8A11, -- 「もうあきらめるんだな」
		-- 大統領 (0x9)
		[(0x859F4C << 24) | 0x0333] = 0x8A91, -- 「そのつもりだ・・・」
		-- ジェイク (0x1)
		[(0x859F4C << 24) | 0x1E20] = 0x8A12, -- 「きさまには責任をとってもらう。」
		-- 大統領 (0x9)
		[(0x859F4C << 24) | 0x01F0] = 0x8A92, -- 「責任？なんの責任だ？」
		[(0x859F4C << 24) | 0x0311] = 0x8A93, -- 「この戦争は私が起こしたわけじゃない。」
		[(0x859F4C << 24) | 0x0381] = 0x8A94, -- 「時の流れが我々を戦争へと導いたにすぎん！」
		-- ジェイク (0x1)
		[(0x859F4C << 24) | 0x5D2D] = 0x8A13, -- 「戦争の原因なんて問題じゃない！」
		--[(0x859F4C << 24) | 0x0311] = 0x8A14, -- 「この戦争で死んだ多くの人々への責任をとるんだ」
		-- 大統領 (0x9)
		[(0x859F4C << 24) | 0xD301] = 0x8A95, -- 「今の私にできることはこれぐらいだ・・」
		-- ジェイク (0x1)
		[(0x859FFA << 24) | 0x1101] = 0x8A15, -- 「こんな。ことで・・・」
		[(0x859FFA << 24) | 0x1F11] = 0x8A16, -- 「こんなことで責任をとったつもりなのかっ！」
		[(0x859FFA << 24) | 0xFA01] = 0x8A17, -- 「・・・・・・」

		-- Stage 7 / Scene B (デューク中尉からの通信)
		-- 友軍 一般兵 (0xA)
		[(0x859FFA << 24) | 0x1C0B] = 0x8BA1, -- 「だれか！だれか応答してくれ！」 ※友軍一般兵として2桁目を暫定で2に設定
		-- ジェイク (0x1)
		--[(0x859FFA << 24) | 0x1C0B] = 0x8B11, -- 「だれだっ！」
		-- 友軍 一般兵 (0xA)
		[(0x859FFA << 24) | 0x48F0] = 0x8BA2, -- 「第３２AS隊のデューク中尉だ！」
		[(0x859FFA << 24) | 0x0335] = 0x8BA3, -- 「敵の巨大な機動兵器が始動している！」
		[(0x859FFA << 24) | 0x85F1] = 0x8BA4, -- 「増援を・・・」
		-- ジェイク (0x1)
		[(0x859FFA << 24) | 0x1133] = 0x8B12, -- 「そこはどこだ！？」
		-- 友軍 一般兵 (0xA)
		[(0x859FFA << 24) | 0xF080] = 0x8BA5, -- 「国民議会ビルの地下の工場施設に・・・・・」
		[(0x859FFA << 24) | 0x2518] = 0x8BA6, -- 「うわあっ！」
		-- ジェイク (0x1)
		[(0x859FFA << 24) | 0x8A6E] = 0x8B13, -- 「応答しろ！デューク中尉！」
		[(0x859FFA << 24) | 0xFD01] = 0x8A17, -- 「・・・・・・」
		[(0x859FFA << 24) | 0x0311] = 0x8B14, -- 「この戦争に終わりはないのか！？」

		-- Stage 7 / Scene C (兵士の生き方)
		-- ジェイク (0x1)
		[(0x85A0E7 << 24) | 0x930A] = 0x8C11, -- 「なぜだ！？なぜきさまら向かってくるんだ！？もう戦争は終わったんだぞ！！」
		-- ベルダーク少佐 (0x6)
		[(0x85A0E7 << 24) | 0x1C33] = 0x8C61, -- 「それは俺たちが兵士だからだ！ 生きているかぎり戦いを続ける、それが兵士の生きかたというものだ！」
		-- ジェイク (0x1)
		--[(0x85A0E7 << 24) | 0x120B] = 0x8C12, -- 「だまれ！」

		-- Stage 7 / Scene D (リックの立ち塞がり)
		-- リック (0x8)
		[(0x85A28A << 24) | 0x1256] = 0x8D81, -- 「おまえをベルダーク少佐の元にはいかせない！」
		-- ジェイク (0x1)
		[(0x85A28A << 24) | 0x1F0A] = 0x8D11, -- 「なんだと！」
		-- リック (0x8)
		[(0x85A28A << 24) | 0x8971] = 0x8D82, -- 「少佐のじゃまをする奴は許さない。 少佐だけがこの国を救うことができるんだ！」
		-- ジェイク (0x1)
		[(0x85A28A << 24) | 0x06AD] = 0x8D12, -- 「奴はそんな男じゃない！わからないのか！？ 奴は全てを破壊しようとしているんだぞ！」
		-- リック (0x8)
		[(0x85A28A << 24) | 0x1C33] = 0x8D83, -- 「それ以上言うなっ！！」

		-- Stage 7 / Scene E (リック撃破)
		-- リック (0x8)
		[(0x859DAC << 24) | 0x2318] = 0x8E81, -- 「うあぁ！少佐！」


		-- ==========================================
		-- STAGE 8 (数値は9) 最終決戦：ビルドヴォーグ
		-- ==========================================

		-- Stage 8 / Scene 1 (最終機動兵器ビルドヴォーグ)
		-- ジェイク (0x1)
		[(0x85A14A << 24) | 0x0F11] = 0x9111, -- 「こ、この機動兵器は・・」
		-- ベルダーク少佐 (0x6)
		[(0x85A14A << 24) | 0x1376] = 0x9161, -- 「ふっふっふ・・・・・・はーっはっはっは！」
		[(0x85A14A << 24) | 0x87F1] = 0x9162, -- 「驚いたか！これが我が軍の最終機動兵器」
		[(0x85A14A << 24) | 0x289D] = 0x9163, -- 「ビルドヴォーグだ！こいつの前では貴様など」
		[(0x85A14A << 24) | 0x6DC9] = 0x9164, -- 「虫ケラにしかすぎん！」
		-- ジェイク (0x1)
		[(0x85A14A << 24) | 0x1665] = 0x9112, -- 「ばかな！」
		[(0x85A14A << 24) | 0x1F11] = 0x9113, -- 「こんなものを持ちだして、どうしようというんだ！」
		-- ベルダーク少佐 (0x6)
		[(0x85A14A << 24) | 0x0634] = 0x9165, -- 「俺は貴様を倒す！この俺のプライドを・・」
		[(0x85A14A << 24) | 0x0334] = 0x9166, -- 「俺の全てをお前はふみにじった！」
		[(0x85A14A << 24) | 0x0333] = 0x9167, -- 「その報いを受けてもらう！」

		-- Stage 8 / Scene 2 (プライドと守るもの)
		-- ベルダーク少佐 (0x6)
		[(0x85A202 << 24) | 0xC8EE] = 0x9261, -- 「貴様さえいなければ・・貴様の存在さえ抹消すれば俺は・・・・」
		-- ジェイク (0x1)
		[(0x85A202 << 24) | 0x0634] = 0x9211, -- 「俺は死ぬ訳にはいかない。俺には俺を待っている人が・・・バーシスのクルーが・・ ・・・そしてクレアがいるんだ！」

		-- Stage 8 / Scene 3 (ベルダーク少佐撃破・終局)
		-- ベルダーク少佐 (0x6)
		[(0x85A268 << 24) | 0x930A] = 0x9361, -- 「なぜだ・・・なぜこの俺が・・・・ ぐわぁ！！」

		-- ？
		[(0x85A30E << 24) | 0x1101] = 0xF000, -- 「こち・・・外宇宙探査隊・・・応・・・願いま・・・こ・ら・・外宇宙探査・・・・・答・・願い・す・・」

		},
		queue = {},
	}

	local v_buf = 0
	local a_buf = 0
	local a_reg16 = 0
	local a_reg16_buf = 0
	local v_count = 0
	local text_buf = {}
	local text_addr = 0
	local text_count = 0
	local voice_manager = {
		queue = {},
		stack = {},
		current = nil,
		channel = nil
	}
	local voice_type = 0

	function text_reset()
		v_buf = 0
		text_count = 0
		voice_manager.stack = {}
	end

	function DialogueManager.get_id(a_val, i_val, c_val)
		local key = (a_val << 24) | i_val
		local cid = CHAR_ID_MAP[c_val] or 0
		local cid_use = false
		local ret = DialogueManager.id_table[key] or 0x0000
		if ret == 0x5841 then cid_use = true end
		if ret == 0x5A21 then cid_use = true end
		if ret == 0x7121 then cid_use = true end
		if ret == 0x8BA1 then cid_use = true end
		if ret == 0xF010 then text_reset() end
		if cid_use and cid > 0 then ret = (ret&0xff0f) + (cid<<4) end
		return ret
	end

	local VOICE_TYPE_MAP = { -- skip可能なtextを指定
		[0x858835] = 1,
		[0x85889C] = 1,
		[0x858ADF] = 1,
		[0x858B5A] = 1,
		[0x858C32] = 1,
		[0x858CDC] = 1,
		[0x858E09] = 3,
		[0x858F1E] = 1,
		[0x858F8E] = 1,
		[0x858FED] = 3,
		
		[0x859177] = 4,
		[0x85919E] = 4,
		[0x8591D4] = 4,
		[0x859269] = 4,
		[0x8592D7] = 4,
		[0x859367] = 4,
		[0x8593B2] = 4,
		[0x859410] = 4,
		[0x859446] = 4,
		[0x859499] = 4,
		[0x8594C1] = 4,
		[0x859518] = 4,
		[0x85954F] = 4,
		[0x8595A0] = 4,
		[0x85967D] = 5,
		[0x85980A] = 5,
		[0x859939] = 6,
		[0x859A61] = 6,
		[0x859A87] = 6,
		[0x859AFC] = 6,
		[0x859CB6] = 7,
		[0x859DB8] = 7,
		[0x859E16] = 7,
		[0x859E63] = 7,
		[0x859E90] = 7,
		[0x859F2A] = 7,
		[0x859F4C] = 7,
		[0x859FFA] = 7,
		[0x85A14A] = 7,

		[0x859BE4] = 9, -- gameover demo
	}

	function valken_as_text(offset)
		if AS_VOICE == false then return end
		local a_reg = cpu.state["A"].value
		--MES("as:%04X music:%02X", a_reg, sound)
		if sound ~= 0 then
			fmod:play(a_reg)
		end
	end

	function valken_chara_text(offset)
		if TEXT_VOICE == false then return end
		local a_reg = cpu.state["A"].value
		--MES("A:%06X I:%04X", text_addr, a_reg)
		if text_addr ~= v_buf then
			local c_reg = mem:read_u16(0x1a2a)
			local voice_id = DialogueManager.get_id(text_addr, a_reg, c_reg)
			if voice_id and voice_id > 0x1000 then
				if voice_play(voice_id,text_addr) == 0 then
					-- MES("A:%06X I:%04X C:%04X", text_addr, a_reg, val)
				end
			end
			local val = mem:read_u16(0x1a2a)
			MES("* A:%06X I:%04X C:%04X", text_addr, a_reg, val)
			text_count = text_count + 1
		end

		v_buf = text_addr
		if a_reg == 0xFDFC or (a_reg & 0xff) == 0x00FA or (a_reg & 0xff) == 0x00FD then v_buf = 0 end
		if a_buf == a_reg then v_buf = 0 end
		a_buf = a_reg
	end

	function valken_chara_text_addr(offset)
		local a_reg = cpu.state["A"].value
		local x_reg = cpu.state["X"].value
		local val = (x_reg << 16) + a_reg
		text_addr = val
		text_reset()
		MES("text addr:%06X", val)
	end


	set_read_handlers(":maincpu", 0x84e24b, valken_as_text, 1)
	set_read_handlers(":maincpu", 0x80b14f, valken_chara_text)
	set_read_handlers(":maincpu", 0x84dd53, valken_chara_text_addr)

	local next_message_one_shot = 0

	function voice_play(voice,text_addr)
		if fmod:is_samples(voice) > 0 then
			voice_type = VOICE_TYPE_MAP[text_addr] or 0
			is_text_skip = 0
			if voice_type > 0 then is_text_skip = 1 end
			if not voice_manager.stack[voice] then
				voice_manager.stack[voice] = 1
				if voice == 0x7913 then return end
				if voice == 0x5A44 then return end
			else
				voice_manager.stack[voice] = voice_manager.stack[voice] + 1
				MES("Voice:%04X Type:%d Stack:%d", voice, voice_type, voice_manager.stack[voice])
				if voice == 0x5A44 and voice_manager.stack[voice] > 2 then return end
				if voice == 0x5B11 then return end
				if voice == 0x5B21 then return end
				if voice == 0x8111 then voice = 0x8112 end
				if voice == 0x8A13 then return end
				if voice == 0x8A17 and voice_manager.stack[voice] == 3 then return end
				if voice == 0x8A17 and voice_manager.stack[voice] == 4 then return end
				if voice == 0x8A93 then voice = 0x8A14 end
				if voice == 0x8AA3 then voice = 0x8A13 end
				if voice == 0x8BA1 then return end
				if voice == 0x8D11 then return end
				if voice == 0x8D12 then return end
				if voice == 0x8D82 then return end
				if voice == 0x8C61 then voice = 0x8C12 end
				if voice == 0x8C11 then voice = 0x8C61 end
				if voice == 0xF000 then return end
			end
			if voice_type == 0 then
				voice_manager.channel = fmod:get_channel(voice)
				table.insert(voice_manager.queue, voice)
			else
				if voice == 0x8714 and voice_manager.stack[voice] == 1 then voice = 0x8712 end
				fmod:play(voice)
				next_message_one_shot = 0
			end
			MES("Voice:%04X Type:%d", voice, voice_type)
			return 1
		end
		return 0
	end

	local function update_voice_queue()
		if not voice_manager.channel or (#voice_manager.queue == 0 and not voice_manager.current) then
			return
		end

		local is_playing = fmod:is_playing(voice_manager.channel)

		if voice_manager.current then
			if is_playing ~= 0 then
				return
			else
				voice_manager.current = nil
			end
		end

		if is_playing == 0 and #voice_manager.queue > 0 then
			local next_voice = table.remove(voice_manager.queue, 1)
			fmod:stop(7)
			fmod:play(next_voice)
			voice_manager.current = next_voice
		end
	end
	set_frame_handlers(update_voice_queue, "frame")

	local function wait_volume(volume)
		if not fmod then return end
		local is_playing = fmod:is_playing(6)
		local is_playing2 = fmod:is_playing(7)
		if is_playing == 0 and is_playing2 == 0 then
			fmod:volume(0,1.0)
			fmod:volume(1,1.0)
		end
	end
	local function voice2bgm_volume()
		if VOICE_BGM_LESS == false then return end
		local is_playing = fmod:is_playing(6)
		local is_playing2 = fmod:is_playing(7)

		if is_playing ~= 0 or is_playing2 ~= 0 then
			fmod:volume(0,VOICE_BGM_LESS_VOLUME)
			fmod:volume(1,VOICE_BGM_LESS_VOLUME)
			text_se_mute = 1
		else
			set_frames_wait_once(wait_volume, 15, 1.0)
			text_se_mute = 0
		end
	end
	set_frame_handlers(voice2bgm_volume)

	local BUTTON_A = "P1 A"
	local field_ms = nil
	if manager and manager.machine and manager.machine.ioport then
		local port = manager.machine.ioport.ports[PORT_TAG]
		if port and port.fields then
			field_ms = port.fields[BUTTON_A]
		end
	end

	local function field_ms_button_off()
		field_ms:set_value(0)
	end
	local function auto_next_message()
		if AUTO_NEXT_MESSAGE == false then return end
		local is_playing = fmod:is_playing(6)
		if is_playing == 0 and voice_type > 0 and next_message_one_shot == 0 then
			next_message_one_shot = 1
			field_ms:set_value(next_message_one_shot)
			set_frames_wait_once(field_ms_button_off, 3)
			MES("# next message")
		end
	end
	set_frame_handlers(auto_next_message, "frame")

end

return user
