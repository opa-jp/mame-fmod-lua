-- 右スティック
local STICK_1P_X = "JOYCODE_1_ZAXIS"
local STICK_1P_Y = "JOYCODE_1_RZAXIS"
local STICK_2P_X = "JOYCODE_2_ZAXIS"
local STICK_2P_Y = "JOYCODE_2_RZAXIS"
local DEADZONE = 12000

local user = {}

function user.init()
	print("user script ok.")

	-- fmod:log(1)

	local function get_dir(x, y)
		local angle = math.atan(-y, x) 
		if angle < 0 then angle = angle + (2 * math.pi) end

		local adjusted_angle = angle - (math.pi / 2)
		if adjusted_angle < 0 then adjusted_angle = adjusted_angle + (2 * math.pi) end

		adjusted_angle = (2 * math.pi) - adjusted_angle
		if adjusted_angle >= (2 * math.pi) then adjusted_angle = adjusted_angle - (2 * math.pi) end

		return math.floor((adjusted_angle / (math.pi / 4)) + 0.5) % 8
	end

	local input = manager.machine.input
	local mem = manager.machine.devices[":maincpu"].spaces["program"]
	local rotpos = 0
	local rotpos2 = 0
	local is_boot = false
	local function jackal_rotate()
		if not input or not mem or not is_boot then return end

		local tx = input:code_from_token(STICK_1P_X)
		local ty = input:code_from_token(STICK_1P_Y)
		local x = tx and input:code_value(tx) or 0
		local y = ty and input:code_value(ty) or 0

		if math.abs(x) > DEADZONE or math.abs(y) > DEADZONE then
			rotpos = get_dir(x, y)
		end

		mem:write_u8(0x0bd8, rotpos)
		mem:write_u8(0x0bd6, 0x64 + (rotpos * 2))

		local tx2 = input:code_from_token(STICK_2P_X)
		local ty2 = input:code_from_token(STICK_2P_Y)
		local x2 = tx2 and input:code_value(tx2) or 0
		local y2 = ty2 and input:code_value(ty2) or 0

		if math.abs(x2) > DEADZONE or math.abs(y2) > DEADZONE then
			rotpos2 = get_dir(x2, y2)
		end

		mem:write_u8(0x0c00, rotpos2)
		mem:write_u8(0x0bfe, 0x64 + (rotpos2 * 2))
	end

	local sound_addr = 0xff
	function get_sound_addr(offset, data)
		if offset == 0x1250 and data == 0x12 then
			sound_addr = 0
			is_boot = true
		end
		if offset == 0x1251 and sound_addr == 0 then
			sound_addr = data + 0x1200
		end
	end

	function sound_replace(offset, data)
		if offset == sound_addr then
			--print(string.format("sound1 D:%02X", data))
			xvib:play(data)
			if (fmod:play(data) == 1) then data = 0xff end
			sound_addr = 0xff
			return data
		end
		--print(string.format("sound2 D:%02X", data))
		xvib:play(data)
		if (fmod:play(data) == 1) then return 0x00 end
	end

	set_write_handlers(":maincpu", 0x1250, get_sound_addr, 2)
	set_write_handlers(":maincpu", 0x12b8, sound_replace,0x20)
	set_frame_handlers(jackal_rotate)

	fmod_config.register_user_menu("Rotate Control Settings", {
		{ 
			key = "stick_deadzone",
			label = "Stick Deadzone",
			type = "number",
			min = 1000,
			max = 36000,
			step = 1000,
			default = DEADZONE
		}
	})
end

return user
