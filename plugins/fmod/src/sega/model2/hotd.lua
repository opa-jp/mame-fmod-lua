local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local target_address = 0x018610
	local cheat_value = 0x0A000000
	rom:write_direct_u32(target_address, cheat_value) -- Disable Screen Flash
end

return user
