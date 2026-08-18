local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local target_address = 0x2017A4
	local cheat_value = 0x4E714E714E716016

	function no_flash_screen()
		print("Disable Screen Flash")
		rom:write_direct_u64(target_address, cheat_value)
	end

	set_frames_wait_once(no_flash_screen, 300)
end

return user
