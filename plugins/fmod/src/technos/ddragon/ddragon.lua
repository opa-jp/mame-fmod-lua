local user = {}

function user.init()
	print("user script ok.")
	fmod:log(2) -- FMOD側の動作確認ログ

	load_samples() -- samples/vibrationリストの読み込み

	function user.sound_replace(offset, data, mask, old_data) -- ここで送られてくるサウンドコードをどう処理するか決める
		print(string.format("D:%02X", data)) -- とりあえずサウンドコードが送られてきているか確認
		xvib:play(data) -- 振動
		if (fmod:play(data) == 1) then data = 0xff end -- サウンド再生。　成功時には1が返るので、dataに0xff(サウンド停止)を入れてゲーム側のサウンドを止める
		return data
	end

	set_write_handler(":maincpu", 0x380e, user.sound_replace) -- サウンドコードが送られてくるアドレス

end

return user
