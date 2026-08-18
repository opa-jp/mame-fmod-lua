local user = {}
function user.init()
	print("user script ok.")

	local gun1_x = 0xa0
	local gun1_y = 0x70
	local is_boot = nil

	local screen = manager.machine.screens[":screen"]
	local screen_width = screen.width
	local screen_height = screen.height

	local ioport = manager.machine.ioport
	local port_x = nil
	local port_y = nil
	local port2_x = nil
	local port2_y = nil

	local min_val = 0x10
	local max_val = 0xf0
	local range = max_val - min_val

	for tag, port in pairs(ioport.ports) do
		local upper_tag = string.upper(tag)
		if string.find(upper_tag, "GUN1X") then port_x = port end
		if string.find(upper_tag, "GUN1Y") then port_y = port end
		if string.find(upper_tag, "GUN2X") then port2_x = port end
		if string.find(upper_tag, "GUN2Y") then port2_y = port end
	end

	local function send_x1(offset, data)
		if not is_boot then return end
		local raw_x = port_x:read()
		local pct_x = (raw_x - min_val) / range
		if pct_x < 0.0 then pct_x = 0.0 end
		if pct_x > 1.0 then pct_x = 1.0 end
		gun1_x = math.floor(pct_x * screen_width)
		return gun1_x
	end
	local function send_y1(offset, data)
		if not is_boot then return end
		local raw_y = port_y:read()
		local pct_y = (raw_y - min_val) / range
		if pct_y < 0.0 then pct_y = 0.0 end
		if pct_y > 1.0 then pct_y = 1.0 end
		gun1_y = math.floor(pct_y * screen_height)
		return gun1_y
	end

	local function send_x2(offset, data)
		if not is_boot then return end
		local raw_x = port2_x:read()
		local pct_x = (raw_x - min_val) / range
		if pct_x < 0.0 then pct_x = 0.0 end
		if pct_x > 1.0 then pct_x = 1.0 end
		gun2_x = math.floor(pct_x * screen_width)
		return gun2_x
	end
	local function send_y2(offset, data)
		if not is_boot then return end
		local raw_y = port2_y:read()
		local pct_y = (raw_y - min_val) / range
		if pct_y < 0.0 then pct_y = 0.0 end
		if pct_y > 1.0 then pct_y = 1.0 end
		gun2_y = math.floor(pct_y * screen_height)
		return gun2_y
	end

	local function check_boot(offset, data)
		if data == 0x5555 then is_boot = false end
		if data == 0x80 then is_boot = true end
	end

	set_write_handlers(":maincpu", 0x50d2f0, send_x1)
	set_write_handlers(":maincpu", 0x50d2f2, send_y1)

	set_write_handlers(":maincpu", 0x50d2f4, send_x2)
	set_write_handlers(":maincpu", 0x50d2f6, send_y2)

	set_write_handlers(":maincpu", 0x5010c6, check_boot)
end

return user
