local config = {}
local json = require("json")

-- 初期値
config.settings = {
	samples_reload = false,
	samples_tag = "default",
	gain = 1.0,
	expo = 2.0,
	thresh = 0.01,
	data_gain = 1.0,
	limitsize_samples_onmemory = 524288 * 2 * 3
}

config.tag_options = { "default" }
config.enabled = false


local config_file = "config.json"

local is_user_config = false

function config.set_path(path)
	config_file = path .. "_config.json"
end

function config.add_tag_option(new_tag)
	for _, v in ipairs(config.tag_options) do
		if v == new_tag then return end 
	end
	table.insert(config.tag_options, new_tag)
end

function config.add_tag_options(...)
	local new_tags = {...}
	for _, tag in ipairs(new_tags) do
		config.add_tag_option(tag)
	end
end

function config.tag_table_size()
	return #config.tag_options
end

function config.get_tag()
	local tag = config.settings.samples_tag or config.tag_options(1)
	return tag
end

function config.load()
	local f = io.open(config_file, "r")
	if f then
		local data = f:read("*all")
		f:close()
		local decoded = json.decode(data)
		if decoded then
			for k, v in pairs(decoded) do config.settings[k] = v end
		end
	else
		config.save()
	end
	config.apply_params()
end

function config.save()
	local f = io.open(config_file, "w")
	if f then
		f:write(json.encode(config.settings))
		f:close()
	else
	        print("!!! ERROR: Could not save config file !!!")
		print("Path: " .. tostring(config_file))
		print("Reason: " .. tostring(err))
	end
end

function config.apply_params()
	if not manager.machine then return end
	local fdev = manager.machine.devices[":fmod"]
	if not fdev then return end
	local fmod = as_fmod(fdev)
	if fmod then
		fmod:set_vib_params(config.settings.gain, config.settings.expo, config.settings.thresh)
		--fmod:clear_vib_data()
	end
	if xvib then
		local max_power = 65535
		local min_power = 0
		if config.settings.data_gain < 1.0 then
			max_power = config.settings.data_gain * 65535.0
		end
		if config.settings.thresh < 1.0 then
			min_power = config.settings.thresh * 65535.0
		end
		if max_power > 65535 then max_power = 65535 end
		if min_power > 65535 then min_power = 65535 end
		xvib:set_motorpower_max(max_power, max_power)
		xvib:set_motorpower_min(min_power, min_power)
	end
end

function config.register_menu(title)
	is_user_config = false
	emu.register_menu(
		function(index, event)
			local changed = false
			if index == 1 then
				if event == 'left' or event == 'right' or event == 'select' then
					config.settings.samples_reload = not config.settings.samples_reload
					changed = true
				end
			elseif index == 2 then
				local current_idx = 1
				for i, v in ipairs(config.tag_options) do
					if v == config.settings.samples_tag then current_idx = i break end
				end
				if event == 'left' then
					current_idx = (current_idx - 2) % #config.tag_options + 1
					changed = true
				elseif event == 'right' then
					current_idx = current_idx % #config.tag_options + 1
					changed = true
				elseif event == 'select' then
					fmod:menu_pause(1)
					local result = load_samples(config.settings.samples_tag,1)
					fmod:menu_pause(0)
					if result == 18 then
						manager.machine:popmessage("Error: Failed to load samples!")
					elseif result ~= 0 then
						manager.machine:popmessage(string.format("Error: Failed to load samples in tag:%s", config.get_tag()))
					end
				end
				config.settings.samples_tag = config.tag_options[current_idx]
			elseif index == 3 then -- Gain
				if event == 'left' then config.settings.gain = math.max(0, config.settings.gain - 0.05); changed = true
				elseif event == 'right' then config.settings.gain = math.min(5.0, config.settings.gain + 0.05); changed = true end
			elseif index == 4 then -- Expo
				if event == 'left' then config.settings.expo = math.max(1.0, config.settings.expo - 0.5); changed = true
				elseif event == 'right' then config.settings.expo = math.min(5.0, config.settings.expo + 0.5); changed = true end
			elseif index == 5 then -- Thresh
				if event == 'left' then config.settings.thresh = math.max(0.0, config.settings.thresh - 0.005); changed = true
				elseif event == 'right' then config.settings.thresh = math.min(0.3, config.settings.thresh + 0.005); changed = true end
			elseif index == 6 then -- Thresh
				if event == 'left' then config.settings.data_gain = math.max(0.05, config.settings.data_gain - 0.05); changed = true
				elseif event == 'right' then config.settings.data_gain = math.min(1.0, config.settings.data_gain + 0.05); changed = true end
			elseif index == 7 then
				local step = 262144
				if event == 'left' then 
					config.settings.limitsize_samples_onmemory = math.max(262144, config.settings.limitsize_samples_onmemory - step)
					changed = true
				elseif event == 'right' then 
					config.settings.limitsize_samples_onmemory = config.settings.limitsize_samples_onmemory + step
					changed = true 
				end
			end

			if changed then
				config.apply_params()
				config.save()
				return true
			end
			return false
		end,

		function()
			if not config.enabled then 
				local menu_items = {
					{ "--- Status ---", "Not Supported", "heading" },
					{ "", "", "" },
					{ "No user script found for this ROM.", "", "" }
				}
				return menu_items, nil, nil
			else
				local menu_items = {
					{ "Reset to Samples Reload", config.settings.samples_reload and "On" or "Off", 'lr' },
					{ "Select Samples Tag", config.settings.samples_tag, 'lr' },
					{ "Vibration Gain", string.format("%.2f", config.settings.gain), 'lr' },
					{ "Vibration Expo", string.format("%.1f", config.settings.expo), 'lr' },
					{ "Vibration Threshold", string.format("%.3f", config.settings.thresh), 'lr' },
					{ "Vibration Gain (data)", string.format("%.2f", config.settings.data_gain), 'lr' },
					{ "Sample Memory Limit", string.format("%.2f MB", config.settings.limitsize_samples_onmemory / 1024 / 1024), 'lr' },
				}
				return menu_items, nil, 'lrrepeat'
			end
		end,
		title
	)
end

function config.register_user_menu(title, items_def, on_change_callback)
	-- items_def: メニュー項目の定義テーブル
	-- on_change_callback: 値変更時に呼び出したいユーザースクリプト側の関数 (apply_params)

	if config.settings then
		local initial_applied = false
		for _, item in ipairs(items_def) do
			if config.settings[item.key] == nil then
				config.settings[item.key] = item.default
				initial_applied = true
			end
		end
		if initial_applied then
			config.save()
		end
	end

	if is_user_config == true then return end
	is_user_config = true

	emu.register_menu(
		function(index, event)
			if not config.settings then return false end
			local item = items_def[index]
			if not item then return false end

			local changed = false

			if item.type == "number" then
				local current_val = config.settings[item.key] or item.default
				if event == 'left' then
					config.settings[item.key] = math.max(item.min or 0, current_val - (item.step or 1))
					changed = true
				elseif event == 'right' then
					config.settings[item.key] = math.min(item.max or 100, current_val + (item.step or 1))
					changed = true
				end
			elseif item.type == "bool" then
				if event == 'left' or event == 'right' or event == 'select' then
					local current_val = config.settings[item.key]
					if current_val == nil then current_val = item.default end
					config.settings[item.key] = not current_val
					changed = true
				end
			end

			if changed then
				config.save()
				if type(on_change_callback) == "function" then
					on_change_callback()
				end
				return true
			end
			return false
		end,

		function()
			local menu_items = {}
			for _, item in ipairs(items_def) do
				local val = config.settings[item.key]
				if val == nil then val = item.default end

				local display_val = ""
				if item.type == "bool" then
					display_val = val and "On" or "Off"
				else
					display_val = tostring(val)
				end

				table.insert(menu_items, { item.label, display_val, "lr" })
			end
			return menu_items, nil, 'lrrepeat'
		end,

		title
	)
end

return config
