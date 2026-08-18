local user = {}

function user.init()
	print("user script ok.")

	local input = manager.machine.input

	local WHEEL_CODE = input:code_from_token("JOYCODE_1_XAXIS")   -- ハンドル
	local ACCEL_CODE = input:code_from_token("JOYCODE_1_SLIDER2") -- 右トリガー（アクセル）
	local BRAKE_CODE = input:code_from_token("JOYCODE_1_SLIDER1") -- 左トリガー（ブレーキ）

	local max_val = 65536
	local deadzone = 5000
	local last_logged_accel = -1
	local last_logged_brake = -1

	local cpu = manager.machine.devices[":maincpu"]
	local mem = cpu.spaces["program"]
	local io_in1 = manager.machine.ioport.ports[":IN1"]

	function rf2b_io()
		if not io_in1 then return end

		local val_x = WHEEL_CODE and input:code_value(WHEEL_CODE) or 0
		local final_x = 52

		if math.abs(val_x) < deadzone then
			final_x = 52
		else
			local sign = (val_x > 0) and 1 or -1
			local adjusted_val = val_x - (sign * deadzone)
			local ratio = adjusted_val / (max_val - deadzone)
			final_x = math.floor(52 + (ratio * 52))
		end

		if final_x < 0 then final_x = 0 elseif final_x > 104 then final_x = 104 end

		local wheel_data = (0xffcc + final_x) & 0xffff
		mem:write_u16(0x01ea70, wheel_data)


		local val_accel = ACCEL_CODE and input:code_value(ACCEL_CODE) or 0
		local norm_accel = math.abs(val_accel) / 65535

		local accel_pattern = 0x0
		if norm_accel < 0.15 then     accel_pattern = 0x0  -- 0000
		elseif norm_accel < 0.40 then accel_pattern = 0x1  -- 0001
		elseif norm_accel < 0.65 then accel_pattern = 0x3  -- 0011
		elseif norm_accel < 0.85 then accel_pattern = 0x7  -- 0111
		else                          accel_pattern = 0xf  -- 1111
		end

--	if accel_pattern ~= last_logged_accel then print(string.format("Accel Pattern: %X", accel_pattern)) last_logged_accel = accel_pattern end

		local val_brake = BRAKE_CODE and input:code_value(BRAKE_CODE) or 0
		local norm_brake = math.abs(val_brake) / 65535

		local brake_value = 0
		if norm_brake < 0.15 then     brake_value = 0
		elseif norm_brake < 0.45 then brake_value = 1
		elseif norm_brake < 0.80 then brake_value = 2
		else                          brake_value = 3
		end

--	if brake_value ~= last_logged_brake then local bit_str = (brake_value == 0 and "00" or brake_value == 1 and "01" or brake_value == 2 and "10" or "11") print(string.format("Brake Value: %d (Bits: %s) | Raw: %d", brake_value, bit_str, val_brake)) last_logged_brake = brake_value end

		local ret = 0x0000

		ret = ret + (brake_value * 0x0100)
		ret = ret + (accel_pattern * 0x1000)

		local data1 = io_in1:read()
		if (data1 & 0x10) ~= 0 then
			ret = ret + 0x0800
		end

		ret = ret + (final_x & 0x7f)
		mem:write_u16(0x070000, ret)
	end

	local scb = 0
	local vb = 0
	function sound_replace(offset, data, mask)
		sc = data & mask
		--if sc == 0x21 then return end
			if scb ~= 0x21 then
				vb = 1
			end
			if sc == 0x16 and scb ~= 0 then
				vb = 0
			end

		if vb == 1 then
			xvib:play(sc)
		end
		--end
		if sc == 0x21 then return end
		--print(string.format("data:%02X", sc))
		scb = sc
	end

	set_write_handlers(":maincpu", 0x05c000, sound_replace)
	set_frame_handlers(rf2b_io)
end

return user
