local lib = {}

local function get_settings_path()
	return manager.machine.options.entries.homepath:value():match('([^;]+)') .. '/custombutton'
end

local function get_settings_filename()
	return emu.romname() .. '.cfg'
end

local function initialize_target(settings)
	if not (settings.port and settings.mask and settings.type) then
		return nil
	end

	local ioport = manager.machine.ioport
	local port = ioport.ports[settings.port]
	if not port then
		return nil
	end

	local field = port:field(settings.mask)
	if not field then
		return nil
	end

	local target_type = ioport:token_to_input_type(settings.type)
	if field.type ~= target_type then
		return nil
	end

	return {
		port = settings.port,
		mask = settings.mask,
		type = target_type,
		button = field
	}
end

local function initialize_button(settings)
	if not (settings.key and settings.targets) then
		return nil
	end

	local key = manager.machine.input:seq_from_tokens(settings.key)
	if not key then
		return nil
	end

	local new_button = {
		key = key,
		key_cfg = settings.key,
		targets = {}
	}

	for _, target_settings in ipairs(settings.targets) do
		local target = initialize_target(target_settings)
		if target then
			new_button.targets[#new_button.targets + 1] = target
		end
	end

	if #new_button.targets == 0 then
		return nil
	end

	return new_button
end

local function serialize_settings(button_list)
	local settings = {}

	for _, button in ipairs(button_list) do
		local targets = {}

		for _, target in ipairs(button.targets or {}) do
			targets[#targets + 1] = {
				port = target.port,
				mask = target.mask,
				type = manager.machine.ioport:input_type_to_token(target.type)
			}
		end

		if button.key_cfg and #targets > 0 then
			settings[#settings + 1] = {
				key = button.key_cfg,
				targets = targets
			}
		end
	end

	return settings
end

function lib:load_settings()
	local buttons = {}
	local json = require('json')
	local filename = get_settings_path() .. '/' .. get_settings_filename()

	local file = io.open(filename, 'r')
	if not file then
		return buttons
	end

	local loaded_settings = json.parse(file:read('a'))
	file:close()

	if not loaded_settings then
		emu.print_error(string.format(
			'Error loading custom button settings: error parsing file "%s" as JSON',
			filename))
		return buttons
	end

	for _, button_settings in ipairs(loaded_settings) do
		local new_button = initialize_button(button_settings)
		if new_button then
			buttons[#buttons + 1] = new_button
		end
	end

	return buttons
end

function lib:save_settings(buttons)
	local path = get_settings_path()
	local attr = lfs.attributes(path)

	if attr and attr.mode ~= 'directory' then
		emu.print_error(string.format(
			'Error saving custom button settings: "%s" is not a directory',
			path))
		return
	end

	local filename = path .. '/' .. get_settings_filename()

	if #buttons == 0 then
		os.remove(filename)
		return
	elseif not attr then
		lfs.mkdir(path)
	end

	local json = require('json')
	local data = json.stringify(serialize_settings(buttons), { indent = true })

	local file = io.open(filename, 'w')
	if not file then
		emu.print_error(string.format(
			'Error saving custom button settings: error opening file "%s" for writing',
			filename))
		return
	end

	file:write(data)
	file:close()
end

return lib
