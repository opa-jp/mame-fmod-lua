local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local target_address = 0x584A4
	local cheat_value = 0x08000004
	rom:write_direct_u32(target_address, cheat_value) -- Disable Screen Flash

	local WEAPON_MAP = {
		[0x01] = "normal",
		[0x02] = "rifle",
		[0x03] = "automatic",
		[0x04] = "machinegun",
		[0x05] = "shotgun",
		[0x06] = "magnum"
	}

	local function send_weapon_change(player, weapon_id)
		local weapon_name = WEAPON_MAP[weapon_id] or "unknown"
		tcp_send_command("weponchange",player,weapon_name)
		--print(string.format("send : %s[%s] -> %s", "weponchange", player, weapon_name))
	end

	local last_p1_weapon = -1
	local last_p2_weapon = -1

	function check_wepon()
		local mem = manager.machine.devices[":maincpu"].spaces["program"]
		local current_p1 = mem:read_u8(0x50EE88)
		if current_p1 ~= last_p1_weapon then
			if last_p1_weapon ~= -1 and current_p1 > 0 then
				send_weapon_change("p1", current_p1)
			end
			last_p1_weapon = current_p1
		end
		local current_p2 = mem:read_u8(0x50EE8C)
		if current_p2 ~= last_p2_weapon then
			if last_p2_weapon ~= -1 and current_p2 > 0 then
				send_weapon_change("p2", current_p2)
			end
			last_p2_weapon = current_p2
		end
	end

	set_frame_handlers(check_wepon)
end
return user
