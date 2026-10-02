local lib = {}

local commonui

local MENU_TYPES = {
	MAIN = 0,
	EDIT = 1,
	ADD = 2,
	TARGETS = 3,
	INPUT_SELECT = 4
}

local MENU_SECTIONS = {
	HEADER = 0,
	CONTENT = 1,
	FOOTER = 2
}

local header_height = 0
local content_height = 0
local menu_stack = { MENU_TYPES.MAIN }

local initial_button
local main_selection_save
local configure_selection_save
local target_selection_save

local hotkey_poller
local current_button = {}
local initial_target
local target_menu

local function menu_section(index)
	if index <= header_height then
		return MENU_SECTIONS.HEADER, index
	elseif index <= content_height then
		return MENU_SECTIONS.CONTENT, index - header_height
	else
		return MENU_SECTIONS.FOOTER, index - content_height
	end
end

local function create_new_button()
	return {
		key = nil,
		key_cfg = nil,
		targets = {}
	}
end

local function is_button_complete(button)
	return button.key and button.key_cfg
		and button.targets and #button.targets > 0
end

local function target_name(target)
	return target.button and target.button.name
		or _p('plugin-custombutton', 'n/a')
end

local function targets_text(button)
	if not button.targets or #button.targets == 0 then
		return _p('plugin-custombutton', '[not set]')
	end

	local names = {}
	for _, target in ipairs(button.targets) do
		names[#names + 1] = target_name(target)
	end
	return table.concat(names, ' + ')
end

-- Main menu

local function populate_main_menu(buttons)
	local ioport = manager.machine.ioport
	local input = manager.machine.input
	local menu = {}

	table.insert(menu, {
		_p('plugin-custombutton', 'Custom buttons'), '', 'off'
	})
	table.insert(menu, {
		string.format(
			_p('plugin-custombutton', 'Press %s to delete'),
			manager.ui:get_general_input_setting(
				ioport:token_to_input_type('UI_CLEAR'))),
		'', 'off'
	})
	table.insert(menu, {'---', '', ''})
	header_height = #menu

	if #buttons > 0 then
		for index, button in ipairs(buttons) do
			local text = string.format(
				_p('plugin-custombutton', '%s -> %s'),
				input:seq_name(button.key),
				targets_text(button))
			table.insert(menu, { text, '', '' })

			if index == initial_button then
				main_selection_save = #menu
			end
		end
	else
		table.insert(menu, {
			_p('plugin-custombutton', '[no custom buttons]'), '', 'off'
		})
	end

	initial_button = nil
	content_height = #menu

	table.insert(menu, {'---', '', ''})
	table.insert(menu, {
		_p('plugin-custombutton', 'Add custom button'), '', ''
	})

	local selection = main_selection_save
	main_selection_save = nil
	return menu, selection
end

local function handle_main_menu(index, event, buttons)
	local section, adjusted_index = menu_section(index)

	if section == MENU_SECTIONS.CONTENT then
		if event == 'select' then
			initial_button = adjusted_index
			main_selection_save = index
			current_button = buttons[adjusted_index]
			table.insert(menu_stack, MENU_TYPES.EDIT)
			return true
		elseif event == 'clear' then
			table.remove(buttons, adjusted_index)
			main_selection_save = index
			if adjusted_index > #buttons then
				main_selection_save = main_selection_save - 1
			end
			return true
		end
	elseif section == MENU_SECTIONS.FOOTER and event == 'select' then
		main_selection_save = index
		current_button = create_new_button()
		table.insert(menu_stack, MENU_TYPES.ADD)
		return true
	end

	return false
end

-- Configure / Add menu
--
-- The ADD screen is also the game-button configuration screen.
-- Selecting "Add Game buttons" immediately opens MAME's input
-- selection menu; after selecting a field, the user returns to
-- this same screen and the new button is displayed underneath.
-- Assigned buttons can be selected and removed with CLEAR.

local function populate_configure_menu(menu)
	local key_name = current_button.key
		and manager.machine.input:seq_name(current_button.key)
		or _p('plugin-custombutton', '[not set]')

	table.insert(menu, {
		_p('plugin-custombutton', 'Custom button'),
		key_name,
		hotkey_poller and 'lr' or ''
	})

	-- header_height is set by populate_edit_menu()/populate_add_menu().
	-- Keep it unchanged: Custom button is content row 1 and
	-- Add Game buttons is content row 2.
	table.insert(menu, {
		_p('plugin-custombutton', 'Add Game buttons'), '', ''
	})

	for i, target in ipairs(current_button.targets or {}) do
		table.insert(menu, {
			string.format(
				_p('plugin-custombutton', '  Button %d'),
				i),
			target_name(target),
			''
		})
	end

	content_height = #menu
end

local function handle_configure_menu(index, event, is_add, buttons)
	if hotkey_poller then
		if hotkey_poller:poll() then
			if hotkey_poller.sequence then
				current_button.key = hotkey_poller.sequence
				current_button.key_cfg =
					manager.machine.input:seq_to_tokens(
						hotkey_poller.sequence)
			end
			hotkey_poller = nil
			return true
		end
		return false
	end

	local section, adjusted_index = menu_section(index)

	if section ~= MENU_SECTIONS.CONTENT then
		return false
	end

	print(adjusted_index)

	-- Row 1: Custom button.
	if adjusted_index == 1 then
		if event == 'select' then
			if not commonui then
				commonui = require('commonui')
			end
			hotkey_poller = commonui.switch_polling_helper()
			return true
		end
		return false
	end

	-- Row 2: Add Game buttons.
	if adjusted_index == 2 then
		if event == 'select' then
			target_selection_save = index
			initial_target = nil
			target_menu = nil
			table.insert(menu_stack, MENU_TYPES.INPUT_SELECT)
			return true
		end
		return false
	end

	-- Rows 3+: assigned game buttons.
	local target_index = adjusted_index - 2
	if current_button.targets
		and current_button.targets[target_index] then

		if event == 'clear' then
			table.remove(current_button.targets, target_index)

			-- Keep the cursor on the nearest remaining target, or
			-- on Add Game buttons when the last target was removed.
			local new_target_count = #current_button.targets
			if new_target_count > 0 then
				configure_selection_save =
					header_height + 2 + math.min(
						target_index, new_target_count)
			else
				configure_selection_save = header_height + 2
			end
			return true
		elseif event == 'select' then
			table.remove(current_button.targets, target_index)

			-- Keep the cursor on the nearest remaining target, or
			-- on Add Game buttons when the last target was removed.
			local new_target_count = #current_button.targets
			if new_target_count > 0 then
				configure_selection_save =
					header_height + 2 + math.min(
						target_index, new_target_count)
			else
				configure_selection_save = header_height + 2
			end
			return true
		elseif event == 'back' then
			-- Selecting an assigned button does not leave this screen.
			-- CLEAR is used to remove it.
			configure_selection_save = index
			return true
		end
	end

	return false
end

local function populate_edit_menu()
	local menu = {}

	table.insert(menu, {
		_p('plugin-custombutton', 'Edit custom button'), '', 'off'
	})
	table.insert(menu, {'---', '', ''})
	header_height = #menu

	populate_configure_menu(menu)
	content_height = #menu

	table.insert(menu, {'---', '', ''})
	table.insert(menu, {
		_p('plugin-custombutton', 'Delete'), '', ''
	})
	table.insert(menu, {'---', '', ''})
	table.insert(menu, {
		_p('plugin-custombutton', 'Done'), '', ''
	})

	local selection = configure_selection_save
	configure_selection_save = nil

	if hotkey_poller then
		return hotkey_poller:overlay(menu, selection, 'lrrepeat')
	end

	return menu, selection, 'lrrepeat'
end

local function handle_edit_menu(index, event, buttons)
	local section, adjusted_index = menu_section(index)

	if section == MENU_SECTIONS.FOOTER
		and adjusted_index == 2
		and event == 'select' then

		table.remove(buttons, initial_button)
		if initial_button > #buttons then
			main_selection_save = math.max(
				1, main_selection_save - 1)
		end

		initial_button = nil
		table.remove(menu_stack)
		return true

	elseif section == MENU_SECTIONS.FOOTER
		and adjusted_index == 4
		and event == 'select' then

		initial_button = nil
		table.remove(menu_stack)
		return true

	elseif event == 'back' then
		initial_button = nil
		table.remove(menu_stack)
		return true

	elseif section == MENU_SECTIONS.CONTENT then
		return handle_configure_menu(
			index, event, false, buttons)
	end

	return false
end

local function populate_add_menu()
	local menu = {}

	table.insert(menu, {
		_p('plugin-custombutton', 'Add custom button'), '', 'off'
	})
	table.insert(menu, {'---', '', ''})
	header_height = #menu

	populate_configure_menu(menu)
	content_height = #menu

	table.insert(menu, {'---', '', ''})

	if is_button_complete(current_button) then
		table.insert(menu, {
			_p('plugin-custombutton', 'Create'), '', ''
		})
	else
		table.insert(menu, {
			_p('plugin-custombutton', 'Cancel'), '', ''
		})
	end

	local selection = configure_selection_save
	configure_selection_save = nil

	if hotkey_poller then
		return hotkey_poller:overlay(menu, selection, 'lrrepeat')
	end

	return menu, selection, 'lrrepeat'
end

local function handle_add_menu(index, event, buttons)
	local section, adjusted_index = menu_section(index)

	if section == MENU_SECTIONS.FOOTER
		and event == 'select' then

		if is_button_complete(current_button) then
			table.insert(buttons, current_button)
			initial_button = #buttons
		end

		table.remove(menu_stack)
		return true

	elseif event == 'back' then
		table.remove(menu_stack)
		return true

	elseif section == MENU_SECTIONS.CONTENT then
		return handle_configure_menu(
			index, event, true, buttons)
	end

	return false
end

-- Input selection used by "Add Game buttons".
-- When a field is selected, return directly to the ADD/EDIT screen.
local function populate_input_select_menu()
	local function is_supported_input(field)
		if field.is_analog or field.is_toggle then
			return false
		end
		if field.type_class == 'config'
			or field.type_class == 'dipswitch' then
			return false
		end
		return true
	end

	local function action(field)
		if field then
			local exists = false

			for _, target in ipairs(current_button.targets or {}) do
				if target.port == field.port.tag and
					target.mask == field.mask and
					target.type == field.type then
						exists = true
						break
					end
			end

			if not exists then
				current_button.targets[#current_button.targets + 1] = {
					port = field.port.tag,
					mask = field.mask,
					type = field.type,
					button = field
				}

				configure_selection_save = header_height + 2 -- 2:Add Game buttons
			end

			initial_target = field
			target_menu = nil
			table.remove(menu_stack)
		end
	end

	if not commonui then
		commonui = require('commonui')
	end

	target_menu = commonui.input_selection_menu(
		action,
		_p('plugin-custombutton', 'Select a game button'),
		is_supported_input
	)

	return target_menu:populate(initial_target)
end

local function handle_input_select_menu(index, event)
	return target_menu:handle(index, event)
end

function lib:init_menu(buttons)
	header_height = 0
	content_height = 0
	menu_stack = { MENU_TYPES.MAIN }
	current_button = {}
	target_menu = nil
	initial_target = nil
end

function lib:populate_menu(buttons)
	local current_menu = menu_stack[#menu_stack]

	if current_menu == MENU_TYPES.MAIN then
		return populate_main_menu(buttons)
	elseif current_menu == MENU_TYPES.EDIT then
		return populate_edit_menu()
	elseif current_menu == MENU_TYPES.ADD then
		return populate_add_menu()
	elseif current_menu == MENU_TYPES.TARGETS then
		return populate_targets_menu()
	elseif current_menu == MENU_TYPES.INPUT_SELECT then
		return populate_input_select_menu()
	end
end

function lib:handle_menu_event(index, event, buttons)
	manager.machine:popmessage()

	local current_menu = menu_stack[#menu_stack]

	if current_menu == MENU_TYPES.MAIN then
		return handle_main_menu(index, event, buttons)
	elseif current_menu == MENU_TYPES.EDIT then
		return handle_edit_menu(index, event, buttons)
	elseif current_menu == MENU_TYPES.ADD then
		return handle_add_menu(index, event, buttons)
	elseif current_menu == MENU_TYPES.TARGETS then
		return handle_targets_menu(index, event)
	elseif current_menu == MENU_TYPES.INPUT_SELECT then
		return handle_input_select_menu(index, event)
	end

	return false
end

return lib
