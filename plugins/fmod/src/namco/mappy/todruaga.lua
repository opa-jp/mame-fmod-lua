local user = {}

-- https://www4.big.or.jp/~yotchi/druaga/druaga.html
local druaga_data = {
	[1] = { item = "カッパーマトック", hint = "グリーンスライムを３匹倒す" },
	[2] = { item = "ジェットブーツ", hint = "ブラックスライムを２匹倒す" },
	[3] = { item = "ポーションオブヒーリング", hint = "ブルーナイトのどちらかを倒す" },
	[4] = { item = "チャイム", hint = "扉を通過" },
	[5] = { item = "ホワイトソード", hint = "呪文を歩きながら３回受ける", col = 0xffffff00 },
	[6] = { item = "キャンドル", hint = "最上段から下がる" },
	[7] = { item = "シルバーマトック", hint = "カッパーマトックを壊す" },
	[8] = { item = "ポーションオブパワー", hint = "スタート地点から、Ｘ，Ｙ軸がズレた地点で剣を抜く", col = 0xff80ffff },
	[9] = { item = "ポーションオブエナジードレイン", hint = "最上段の左から９，１０ブロック目の間を通過", col = 0xffff8080 },
	[10] = { item = "ガントレット", hint = "レッドスライムの呪文を盾で受ける", col = 0xffffff00 },
	[11] = { item = "キャンドル", hint = "最下段から上がる" },
	[12] = { item = "アーマー", hint = "最下段にドルイドを出現させる", col = 0xffffff00 },
	[13] = { item = "レッドラインシールド", hint = "敵を全滅させる前に扉を通過してから全滅", col = 0xffffff00 },
	[14] = { item = "ドラゴンポット", hint = "TIME 5000まで待つ", col = 0xff80ffff },
	[15] = { item = "グリーンネックレス", hint = "剣を振りながらブルーナイトと交差" },
	[16] = { item = "パーマネントキャンドル", hint = "左右の外壁に触れる" },
	[17] = { item = "ポーションオブアンロック", hint = "ゴースト５回ワープ", col = 0xffffff00 },
	[18] = { item = "ドラゴンスレイヤー", hint = "外壁に触れずにしばらく待つ", col = 0xffffff00 },
	[19] = { item = "ブックオブライト", hint = "扉を開ける" },
	[20] = { item = "ポーションオブパワー", hint = "敵を１匹も倒さずに、扉を開ける", col = 0xff80ffff },
	[21] = { item = "グリーンリング", hint = "しばらく静止" },
	[22] = { item = "ポーションオブエナジードレイン", hint = "右７，左１，右７", col = 0xffff8080 },
	[23] = { item = "バイブル", hint = "ウイザードのみ全滅" },
	[24] = { item = "バランス", hint = "スタート地点で剣を振る", col = 0xffffff00 },
	[25] = { item = "なし", hint = "" },
	[26] = { item = "ハイパーガントレット", hint = "ドルイドを倒してから鍵を取る", col = 0xffffff00 },
	[27] = { item = "レッドネックレス", hint = "ブルーウィルオーウィスプと交差", col = 0xffffff00 },
	[28] = { item = "ブックオブゲートディテクト", hint = "剣を抜いた状態で扉の上で静止" },
	[29] = { item = "ゴールドマトック", hint = "上右下左×３" },
	[30] = { item = "ポーションオブアンロック", hint = "Ａ及びＢ地点とX,Y軸がずれた点を３回通る" },
	[31] = { item = "パール", hint = "スタートボタンを押す" },
	[32] = { item = "バランス", hint = "剣を２回連続で振る", col = 0xffffff00 },
	[33] = { item = "ブルーラインシールド", hint = "シルバードラゴンと交差", col = 0xffffff00 },
	[34] = { item = "ブックオブキーディテクト", hint = "ミラーナイトのどちらかを倒す" },
	[35] = { item = "ポーションオブエナジードレイン", hint = "ローパー２匹と交差", col = 0xffff8080 },
	[36] = { item = "バランス", hint = "ファイヤーエレメントを通過", col = 0xffffff00 },
	[37] = { item = "ハイパーヘルメット", hint = "ゴーストを全滅後、ローパーと交差", col = 0xffffff00 },
	[38] = { item = "グリーンクリスタルロッド", hint = "剣を出した状態でウイザードの呪文を盾で受ける", col = 0xffffff00 },
	[39] = { item = "レッドリング", hint = "上２、下５" },
	[40] = { item = "ポーションオブデス", hint = "TIME 10000以下の時にローパーと交差", col = 0xffff0000 },
	[41] = { item = "ポーションオブキュアー", hint = "クオックスを倒す" },
	[42] = { item = "サファイアメイス", hint = "鍵を取る前と取ったあとにすれ違う。", col = 0xff80ffff },
	[43] = { item = "ポーションオブエナジードレイン", hint = "緑,黒,追,青,暗緑,暗黄の順に倒す", col = 0xffff8080 },
	[44] = { item = "バランス", hint = "ドルイド,メイジ,ソーサラー,ウイザードの順に倒す", col = 0xffffff00 },
	[45] = { item = "アンチドート/エクスカリバー", hint = "リザード,ハイパー,ミラー,黒,青の順に倒し、最初からある宝を後に取る", col = 0xffffff00 },
	[46] = { item = "ブルーネックレス", hint = "四隅を通過し、最初に触れた外壁の場所に行く" },
	[47] = { item = "ポーションオブアンロック", hint = "レッドハンドローパーを倒す", col = 0xffff8080 },
	[48] = { item = "レッドクリスタルロッド", hint = "四隅を通過する", col = 0xffffff00 },
	[49] = { item = "ポーションオブエナジードレイン", hint = "扉を通過してから、ウイザードを全滅させる" },
	[50] = { item = "ポーションオブパワー", hint = "隅以外の上下左右すべての外壁に触れる", col = 0xff80ffff },
	[51] = { item = "バランス", hint = "レバー入れっぱなし", col = 0xffffff00 },
	[52] = { item = "ハイパーアーマー", hint = "壁を４枚壊す", col = 0xffffff00 },
	[53] = { item = "ポーションオブアンロック", hint = "(10,8)を下向きに通過" },
	[54] = { item = "ブルーリング", hint = "(10,2)で下を向く" },
	[55] = { item = "なし", hint = "" },
	[56] = { item = "空箱", hint = "呪文を盾以外で受ける" },
	[57] = { item = "ルビーメイス", hint = "扉を通過後、サキュバスとリザードマンを倒す", col = 0xffffff00 },
	[58] = { item = "ブルークリスタルロッド", hint = "(10,8),(10,2),(10,5)の順に通過", col = 0xffffff00 },
	[59] = { item = "ドルアーガの倒し方", hint = "速いハイパーナイト→分身ウイザード→クオックス→ドルアーガの順に倒す" },
	[60] = { item = "クリア方法", hint = "イシター通過→(10,8),(10,2)で下を向く→カイを助ける→(10,5)で下を向く" },
}

function user.init()
	print("user script ok.")
	--fmod:log(1)

	local is_running = false
	local mute = 0
	local addr_array = {}
	local nop_array = {}

	local maincpu = manager.machine.devices[":maincpu"]
	local ram = maincpu.spaces["program"]
	local soundcpu = manager.machine.devices[":sub"]
	local sndram = soundcpu.spaces["program"]

	local draw_item_text = false
	local draw_item_text_count = 0
	local container = manager.machine.render.ui_container
	function draw_text()
		local current_floor = ram:read_u8(0x1704)+1
		if draw_item_text_count > 0 then
			draw_item_text_count = draw_item_text_count - 1
			if draw_item_text_count == 0 then draw_item_text = false end
			if current_floor >= 1 and current_floor <= 60 then
				local data = druaga_data[current_floor]
				local line1 = string.format("[%dF] %s", current_floor, data.item)
				local line2 = data.hint
				local color1 = 0xff00ff00
				if data.col then color1 = data.col end
				container:draw_text("center", 0.86, line1, color1, 0x00000000)
				container:draw_text("center", 0.91, line2, 0xffffffff, 0x00000000)
			end
		end
	end

	local function is_roper_stage(num)
		local list = { [25]=true, [28]=true, [35]=true, [37]=true, [40]=true, [51]=true, [54]=true, [56]=true }
		return list[num] or false
	end

	function sound_reset(state)
		--print(string.format("reset:%d",state))
		fmod:stop_all()
		if state == 1 then is_running = false end
		for i = 0, 33 do
			nop_array[i] = 1
			addr_array[i] = state
		end
	end

	function sound_replace(offset, data)
		local s = (offset&0xff) - 0x40
		local p = 0
		if is_running == false and s == 0x1f and data == 0x00 then is_running = true sound_reset(0) end
		if not is_running then return end
		if addr_array[s] == 0 and data == 1 then
			p = 1
			addr_array[s] = data
		end
		if s == 0x1b or s == 0x01 then sound_reset(0) end
		if data == 0 and nop_array[s] == 0x00 then fmod:play(0xff) end
		if p == 1 then
			local cs = s
			--print(string.format("D:%02X %02X", s, data))
			xvib:play(s)

			if cs == 0 then draw_item_text_count = 220 end

			if cs == 0x05 and is_roper_stage(ram:read_u8(0x1704)+1) == true then cs = cs + 0x80 end
			if (fmod:play(cs) == 1) then nop_array[s] = 0x00 end
			if fmod:get_channel(cs) == 1 then
				nop_array[s] = data
				mute = s
			end
		end
		if data == 1 then data = nop_array[s] end
		return data
	end

	function sound_check(offset, data)
		if not is_running then return end
		local s = (offset&0xff) - 0x40
		addr_array[s] = data
	end

	function mute_seq(offset, data)
		if not is_running then return end
		if mute > 0 then
			if fmod:is_playing(1) == 1 then
				sndram:write_u8(0x40 + mute, 0x01)
				data = 0
			else
				sndram:write_u8(0x40 + mute, 0x00)
				mute = 0
			end
		end
		return data
	end

	sound_reset(1)

	set_write_handlers(":maincpu", 0x403f, sound_replace, 33)
	set_write_handlers(":sub", 0x3f, sound_check, 33)
	set_write_handlers(":sub", 0x80, mute_seq, 0x20)
	set_frame_handlers(draw_text, "frame")
end

return user
