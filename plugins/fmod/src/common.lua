local common = {}

	function common.file_exists(path)
		local f = io.open(path, "r")
		if f then
			f:close()
			return true
		end
		return false
	end

	function common.get_software()
		for tag, device in pairs(manager.machine.images) do
			if device.exists then
				local name = "Unknown"
				if device.software_item_name then
					name = device.software_item_name
				elseif device.filename then
					name = device.filename:match("^.+/(.+)$") or device.filename
				end
				print("Tag: " .. tag)
				print("Loaded: " .. name)
				return name
			end
		end
	end

	function common.view_device_list()
		for tag, _ in pairs(manager.machine.devices) do
			local dev = manager.machine.devices[tag]
			local dev_name = "Unknown"
			if type(dev) == "userdata" or type(dev) == "table" then
				local status, result = pcall(function() return dev:name() end)
				if status then dev_name = result end
			end
			print(string.format("Tag: %-20s | Name: %s", tag, dev_name))
		end
	end

return common
