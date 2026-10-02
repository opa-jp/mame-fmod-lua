local exports = {
	name = 'custombutton',
	version = '0.1.0',
	description = 'Custom Button plugin',
	license = 'BSD-3-Clause',
	author = { name = 'OpenAI' }
}

local custombutton = exports
local frame_subscription, stop_subscription

function custombutton.startplugin()
	local buttons = {}
	local input_manager
	local menu_handler
	local active_fields = {}

	local function process_frame()
		local button_states = {}

		for _, custom in ipairs(buttons) do
			if custom.key and custom.targets
				and input_manager:seq_pressed(custom.key) then

				for _, target in ipairs(custom.targets) do
					if target.button then
						local key = target.port .. '\0' .. target.mask .. '.' .. target.type
						local state = button_states[key] or { 0, target.button }
						state[1] = 1
						button_states[key] = state
					end
				end
			end
		end

		-- Release fields that were driven by this plugin in the previous frame.
		for key, field in pairs(active_fields) do
			if not button_states[key] then
				field:clear_value()
			end
		end

		for key, state in pairs(button_states) do
			state[2]:set_value(state[1])
		end

		active_fields = {}
		for key, state in pairs(button_states) do
			active_fields[key] = state[2]
		end
	end

	local function load_settings()
		local loader = require('custombutton/custombutton_save')
		if loader then
			buttons = loader:load_settings()
		end
		input_manager = manager.machine.input
		active_fields = {}
	end

	local function save_settings()
		for _, field in pairs(active_fields) do
			field:clear_value()
		end
		active_fields = {}

		local saver = require('custombutton/custombutton_save')
		if saver then
			saver:save_settings(buttons)
		end

		menu_handler = nil
		input_manager = nil
		buttons = {}
	end

	local function menu_callback(index, event)
		if menu_handler then
			return menu_handler:handle_menu_event(index, event, buttons)
		end
		return false
	end

	local function menu_populate()
		if not menu_handler then
			local status, msg = pcall(function()
				menu_handler = require('custombutton/custombutton_menu')
			end)
			if not status then
				emu.print_error(string.format(
					'Error loading custombutton menu: %s', msg))
			end
			if menu_handler then
				menu_handler:init_menu(buttons)
			end
		end

		if menu_handler then
			return menu_handler:populate_menu(buttons)
		end

		return {{
			_p('plugin-custombutton', 'Failed to load Custom Button menu'),
			'', 'off'
		}}
	end

	frame_subscription = emu.add_machine_frame_notifier(process_frame)
	emu.register_prestart(load_settings)
	stop_subscription = emu.add_machine_stop_notifier(save_settings)
	emu.register_menu(
		menu_callback,
		menu_populate,
		_p('plugin-custombutton', 'Custom Button')
	)
end

return exports
