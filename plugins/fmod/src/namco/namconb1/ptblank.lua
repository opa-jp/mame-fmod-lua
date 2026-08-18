local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local p1_addr, p1_val = 0x00987C, 0x6004
	local p2_addr, p2_val = 0x009902, 0x6004

	function no_flash_screen()
		print("Disable P1 & P2 Screen Flash - Applied!")

		p1_temp = rom:read_direct_u16(p1_addr)
		p2_temp = rom:read_direct_u16(p2_addr)

		rom:write_direct_u16(p1_addr, p1_val)
		rom:write_direct_u16(p2_addr, p2_val)
	end
	set_frames_wait_once(no_flash_screen, 30)
end

return user
