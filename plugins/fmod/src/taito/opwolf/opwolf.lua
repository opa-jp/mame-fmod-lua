local user = {}
function user.init()
	print("user script ok.")

	local rom = manager.machine.devices[":maincpu"].spaces["program"]
	local target_address = 0x001131
	local cheat_value = 0x02

	function no_flash_screen()
		print("Disable Screen Flash")
		rom:write_direct_u8(target_address, cheat_value)
	end

	set_frames_wait_once(no_flash_screen, 30)
end

return user
