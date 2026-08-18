local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local target_address = 0x00923C
	local cheat_value = 0x4E714E714E714E71
	rom:write_direct_u64(target_address, cheat_value) -- Disable Screen Flash
end

return user
