local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local addr1, val1 = 0x004ea0, 0x1200
	local addr2, val2 = 0x004ec2, 0x1200
	rom:write_direct_u16(addr1, val1)
	rom:write_direct_u16(addr2, val2)
end

return user
