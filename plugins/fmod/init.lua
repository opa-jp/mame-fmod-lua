-- int  fmod:play(int soundcode)
-- int  fmod:is_playing(int channel)
-- void fmod:stop(int channel)
-- void fmod:stop_all()
-- void fmod:volume(int channel, float volume)
-- void fmod:fade_out(int channel, float time) time=0.5(500ms)
-- void fmod:fade_in(int channel, float time)
-- void fmod:fade_in(int channel, float time, float volume) volume=1.0(default)
-- void fmod:set_frequency(int channel, float freq)
-- int  fmod:get_channel(int samples_num)

local exports = {}
local json = require("json")
local function inherit_plugin_info()
local f = io.open("plugins/fmod/plugin.json", "r")
	if f then
		local content = f:read("*all")
		f:close()
		local data = json.decode(content)
		if data and data.plugin then
			exports.name = data.plugin.description
			exports.version = data.plugin.version
			exports.menu_title = data.plugin.description
		end
	end
end
inherit_plugin_info()
local fmod_plugin = exports

common = require('fmod/src/common')
fmod_config = require('fmod/src/config')
local config_path = ""

function fmod_plugin.set_folder(path) config_path = path end

local plugin_root = "plugins/"
function exports.set_folder(path)
    fmod_config.set_path(plugin_root .. path)
end

function fmod_plugin.startplugin()
	print("--- FMOD SCRIPT START ---")
	fmod_config.register_menu(exports.menu_title)

	local fdev = nil
	fmod = nil
	local xdev = nil
	xvib = nil
	hook = nil
	mem_write_handler = nil
	mem_read_handler = nil
	p_handle = nil

	local user = nil
	local is_first_time = true
	local samples_tag = ""
	local pending_stops = {}
	local is_samples_load = 0

	local active_taps = {}
	local is_system_running = false
	local active_frame_callbacks = active_frame_callbacks or {}
	local mame_frame_handles = mame_frame_handles or {}

	local IP = "127.0.0.1"
	local PORT = 40287

	local function set_fmod()
		if not fmod then
			fdev = manager.machine.devices[":fmod"]
			if fdev then
				fmod = as_fmod(fdev)
				print("set:fmod - Device Linked")
				print(fmod)
				print(getmetatable(fmod))
				
				local mt = getmetatable(fmod)
				for k, v in pairs(mt) do
					if type(k) == "string" then
						--print("fmod method:", k)
					end
				end
			end
		end
	end

	local function set_xvib()
		if not xvib then
			xdev = manager.machine.devices[":vibe"]
			if xdev then
				xvib = as_xvibe(xdev)
				print("set:xvib - Device Linked")
			end
		end
	end

	local function get_filename(path)
		if not path then return nil end
		local filename = string.match(path, "[^/\\]+$")
		if filename then
			filename = string.match(filename, "(.+)%.[^%.]+$") or filename
		end
		return filename
	end

	function clear_all_handlers()
		--clear_write_handlers()
		clear_handlers()
		clear_frame_handlers()
	end

	local old_data = {}
	function write_wrapper(offset, addr, data, mask, callback, mem)
		local old_data = 0
		local save_table = {
			[8] = function() old_data = mem:read_u8(addr) end,
			[16] = function() old_data = mem:read_u16(addr) end,
			[32] = function() old_data = mem:read_u32(addr) end,
		}
		local data_save = save_table[mem.data_width]
		if type(data_save) == "function" then data_save() end
		return callback(addr, data, mask, old_data)
	end

	function set_write_handler(cpu, addr, cb, range, spaces)
		spaces = spaces or "program"
		if not user then return end
	        local mem = manager.machine.devices[cpu].spaces[spaces]
		if mem then
			range = range or 1
			local add_range = (mem.data_width / 8) * range - 1
			mem_write_handler = mem:install_write_tap(
				addr,
				addr + add_range,
				"writes",
				-- function(offset, data, mask) write_wrapper(offset, addr, data, mask, cb, mem) end
				cb
			)
			return true
		end
		return nil
	end

	function set_write_handlers_delay(cpu_tag, addr, cb, range, spaces)
		spaces = spaces or "program"
		local device = manager.machine.devices[cpu_tag]
		if not device then return nil end
		local mem = device.spaces[spaces]
		if not mem then return nil end
		local tap_key = cpu_tag .. "_" .. string.format("0x%x", addr)
		if not active_taps[tap_key] then
			active_taps[tap_key] = { callbacks = {} }
			range = range or 1
			local add_range = (mem.data_width / 8) * range - 1
			active_taps[tap_key].tap_object = mem:install_write_tap(
				addr,
				addr + add_range,
				"writes",
				function(offset, data, mask)
					for _, callback in ipairs(active_taps[tap_key].callbacks) do
						callback(offset, data, mask)
					end
				end
			)
		end
		table.insert(active_taps[tap_key].callbacks, cb)
		return true
	end

	function clear_write_handlers_deley()
		for key, item in pairs(active_taps) do
			if item.tap_object then
				item.tap_object:remove()
			end
		end
		active_taps = {}
	end

	function set_write_handlers(cpu_tag, addr, cb, range, spaces)
		spaces = spaces or "program"
		local device = manager.machine.devices[cpu_tag]
		if not device then return nil end
		local mem = device.spaces[spaces]
		if not mem then return nil end
		range = range or 1
		local add_range = (mem.data_width / 8) * range - 1
		local tap_key = cpu_tag .. "_" .. spaces .. "_" .. string.format("0x%x", addr) .. "_" .. tostring(cb)
		if not active_taps[tap_key] then
			active_taps[tap_key] = mem:install_write_tap(
				addr,
				addr + add_range,
				"writes_" .. tap_key,
				cb
			)
		end
		return true
	end

	function clear_write_handlers()
		if mem_write_handler then
			mem_write_handler:remove()
			mem_write_handler = nil
		end
		for key, tap_object in pairs(active_taps) do
			if tap_object then
				tap_object:remove()
			end
		end
		active_taps = {}
		--print("--- ALL WRITE HANDLERS SUCCESSFULLY CLEARED ---")
	end

	function set_read_handler(cpu, addr, cb)
		if not user then return end
	        local mem = manager.machine.devices[cpu].spaces["program"]
		if mem then
			local range = (mem.data_width / 8) - 1
			mem_read_handler = mem:install_read_tap(
				addr,
				addr + range,
				"read_hook",
				cb
			)
			return true
		end
		return nil
	end

	function set_read_handlers(cpu_tag, addr, cb, range, spaces)
		spaces = spaces or "program"
		local device = manager.machine.devices[cpu_tag]
		if not device then return nil end
		local mem = device.spaces[spaces]
		if not mem then return nil end

		range = range or 1
		local add_range = (mem.data_width / 8) * range - 1

		local tap_key = cpu_tag .. "_" .. spaces .. "_" .. string.format("0x%x", addr) .. "_" .. tostring(cb)

		if not active_taps[tap_key] then
			active_taps[tap_key] = mem:install_read_tap(
				addr,
				addr + add_range,
				"reads_" .. tap_key,
				cb
			)
		end
		return true
	end

	function clear_handlers()
		if mem_write_handler then
			mem_write_handler:remove()
			mem_write_handler = nil
		end
		if mem_read_handler then
			mem_read_handler:remove()
			mem_read_handler = nil
		end
		for key, tap_object in pairs(active_taps) do
			if tap_object then
				tap_object:remove()
			end
		end
		active_taps = {}
	end

	local reset_subscription
	local reset_subscription_stop
	local is_once = false
	local function on_stop()
		is_system_running = false
		if manager.machine.system.name == '___empty' then return end
		if user then
			print("--- STOP FMOD USER SCRIPT ---")
			if type(user.deinit) == "function" then user.deinit() end
		else
			return
		end
		user = nil
		fmod = nil
		fdev = nil
		xvib = nil
		xdev = nil
		hook = nil
		clear_all_handlers()
		if mem_write_handler then
			mem_write_handler:remove()
			mem_write_handler = nil
		end
		if mem_read_handler then
			mem_read_handler:remove()
			mem_read_handler = nil
		end
		if p_handle then
			p_handle:unregister()
			p_handle = nil
		end
		samples_tag = ""
		is_first_time = true
		pending_stops = {}
		--is_once = false
	end

	local function on_start()
		if manager.machine then
			fmod_config.enabled = false
			if manager.machine.system.name == '___empty' then
				if is_once == false then
					is_once = true
					reset_subscription = emu.add_machine_reset_notifier(on_start)
					reset_subscription_stop = emu.add_machine_stop_notifier(on_stop)
				end
				return
			end
			print("--- CHECK FMOD USER SCRIPT ---")
			local software = common.get_software()
			local fmodfile
			local source = manager.machine.system.source_file
			local product, file = source:match("([^/]+)/([^/]+).cpp$")
			local basedir = 'fmod/src/' .. product .. '/' .. file .. '/'
			local srcname
			local status
			clear_all_handlers()
			if manager.machine.system.name then
				srcname = basedir .. manager.machine.system.name
				if software then srcname = srcname .. '/' .. get_filename(software) end
				print('Trying ROM Name Source: ' .. srcname .. '.lua')
				package.loaded[srcname] = nil
				status, result = pcall(require, srcname)
				if status then user = result end
			end
			if not user then
				if manager.machine.system.parent ~= "0" then
					srcname = basedir .. manager.machine.system.parent
					if software then srcname = srcname .. '/' .. get_filename(software) end
					print('Trying Parent Source: ' .. srcname .. '.lua')
					package.loaded[srcname] = nil
					status, result = pcall(require, srcname)
					if status then user = result end
				end
			end
			if not user then
				if not result:find("not found") then
					print("--- LUA ERROR IN USER SCRIPT ---")
					print("Source: " .. srcname .. ".lua")
					print("Error: " .. tostring(result))
					print("--------------------------------")
				else
					print("No script file found for: " .. manager.machine.system.name .. " (Checked parent/system in " .. basedir .. ")")
				end
			else
				print("--- START FMOD USER SCRIPT ---")
				fmod_config.enabled = true
				--exports.set_folder(srcname)
				fmod_config.set_path(plugin_root .. srcname)
				fmod_config.load()
				set_fmod()
				set_xvib()
				is_samples_load = 0
				user.init()
				if is_samples_load == 0 then load_samples() end
				is_system_running = true
			end
			is_first_time = false
		end
	end

	reset_subscription = emu.add_machine_reset_notifier(on_start)
	reset_subscription_stop = emu.add_machine_stop_notifier(on_stop)


	function install_lua_read_handler(config)
		local cpu = manager.machine.devices[config.cpu or ":maincpu"]
		if not cpu then print("[Error] cpu") return end

		local space = cpu.spaces[config.space or "program"]
		if not space then print("[Error] space") return end

		local start_addr = config.start_addr
		local end_addr = config.end_addr or (start_addr + (space.data_width / 8) - 1)

		emu.install_read_handler(space, start_addr, end_addr, config.callback)
		print(string.format("Read install memory: 0x%X - 0x%X", start_addr, end_addr))
	end

	function install_lua_write_handler(config)
		local cpu = manager.machine.devices[config.cpu or ":maincpu"]
		if not cpu then print("[Error] cpu") return end

		local space = cpu.spaces[config.space or "program"]
		if not space then print("[Error] space") return end

		local start_addr = config.start_addr
		local end_addr = config.end_addr or (start_addr + (space.data_width / 8) - 1)

		emu.install_write_handler(space, start_addr, end_addr, config.callback)
		print(string.format("Write install memory: 0x%X - 0x%X", start_addr, end_addr))
	end


	function load_samples(tag, forced)
		tag = tag or fmod_config.get_tag();
		fmod_config.settings.samples_tag = tag
		xvib:load_vibration_file()
		if is_first_time or forced == 1 or fmod_config.settings.samples_reload then
			is_samples_load = 1
			--if (fmod_config.tag_table_size() < 2) then tag = 'default' end
			local res = fmod:load_samples(tag, 0, fmod_config.settings.limitsize_samples_onmemory)
			if is_first_time then
				local tags = fmod:get_tags()
				if #tags > 0 then
					fmod_config.add_tag_options(table.unpack(tags))
				end
			end
			return res
		end
	end

	local next_slot_id = 1
	function set_frame_handlers(cb, mode)
		mode = mode or "notifier"
		if type(cb) ~= "function" then return nil end
		local key_name = "frame_user_slot_" .. next_slot_id
		active_frame_callbacks[key_name] = cb
		next_slot_id = next_slot_id + 1
		if not mame_frame_handles[mode] then 
			if mode == "notifier" then
				mame_frame_handles[mode] = emu.add_machine_frame_notifier(function()
					if not is_system_running then return end
					for key, callback in pairs(active_frame_callbacks) do
						if string.match(key, "^frame_user_slot_") and callback then
							pcall(callback)
						end
					end
				end)
			else
				mame_frame_handles[mode] = emu.register_frame_done(function()
					if not is_system_running then return end
					for key, callback in pairs(active_frame_callbacks) do
						if string.match(key, "^frame_user_slot_") and callback then
							pcall(callback)
						end
					end
				end, mode)
			end
		end
		return key_name 
	end

	function clear_frame_handlers()
		active_frame_callbacks = {}
		next_slot_id = 1
	end

	function set_frames_wait_once(callback_func, delay_frames, ...)
		local current_frame = delay_frames
		local args = { ... }
		local notifier
		notifier = emu.add_machine_frame_notifier(function()
			current_frame = current_frame - 1
			if current_frame <= 0 then
				if notifier then
					if type(notifier.unsubscribe) == "function" then
						notifier:unsubscribe()
					elseif type(notifier.remove) == "function" then
						notifier:remove()
					end
				end
				callback_func(table.unpack(args))
			end
		end)
	end

	local last_reload_samples_key_state = false
	local reload_samples_key_code = nil
	function monitor_reload_samples_key()
		if is_loading or manager.machine.system.name == '___empty' then return end

		local input = manager.machine.input
		if not input then return end

		if not reload_samples_key_code then
			reload_samples_key_code = input:code_from_token("KEYCODE_HOME")
		end

		if reload_samples_key_code then
			local current_state = input:code_pressed(reload_samples_key_code)
			if not current_state and last_reload_samples_key_state then
				last_reload_samples_key_state = false 
				local tag = fmod_config.settings.samples_tag
				if tag and tag ~= "" then
					print("FMOD: Loading samples for [" .. tag .. "]")
					load_samples(tag, 1)
				end
				return 
			end
			last_reload_samples_key_state = current_state
		end
	end

	emu.register_frame_done(monitor_reload_samples_key)


	function play_vib(code)
		local data = user.XVIB_LIST[code]
		if not data then return end

		if pending_stops[code] then
			xvib:stop_id(pending_stops[code])
			pending_stops[code] = nil
		end

		if data.next then
			xvib:rumble(code, data.l, data.r, 65535)
			pending_stops[data.next] = code
		else
			xvib:rumble(code, data.l, data.r, data.time)
		end
	end


	tcp_output = nil
	function ensure_tcp_connected(tcp_port)
		tcp_port = tcp_port or PORT
		PORT = tcp_port
		if tcp_output then return true end
		local socket_path = string.format("socket.%s:%d", IP, PORT)
		local has_file, f = pcall(emu.file, "", 1)
		if not has_file or not f then
			has_file, f = pcall(emu.file, "r")
		end

		if has_file and f then
			local error_code = f:open(socket_path)
			if error_code == nil or error_code == 0 or tostring(error_code) == "file_error.NONE" then
				tcp_output = f
				print(string.format("[TCP CONNECT] connected to -> %s", socket_path))
				return true
			end
		end

		print("[Error] internal socket failed to open. Check if App is running and firewall allows port " .. PORT)
		return false
	end

	function tcp_send_command(command, player, data)
		if not ensure_tcp_connected() then return end
		local message = string.format("%s:%s:%s\n", command, player, data)
		local success, err = pcall(function()
			tcp_output:write(message)
		end)

		if not success then
			print("[Error] TCP transmission failed: " .. tostring(err))
			if tcp_output then
				pcall(function() tcp_output:close() end)
				tcp_output = nil
			end
		end
	end


	local udp_output = nil
	function ensure_udp_connected()
		if udp_output then return true end
		local has_socket, socket = pcall(require, "socket")
		if not has_socket or not socket then
			print("[Error] LuaSocket module not found. Check MAME Lua environment.")
			return false
		end
		local success, udp = pcall(socket.udp)
		if not success or not udp then
			print("[Error] Failed to create UDP socket.")
			return false
		end
		udp:settimeout(0)
		udp_output = udp
		print(string.format("[UDP INIT] UDP target set -> %s:%d", IP, PORT))
		return true
	end

	function udp_send_command(command, player, data)
		if not ensure_udp_connected() then return end
		local message = string.format("%s:%s:%s\n", command, player, data)
		local success, err = pcall(function()
			return udp_output:sendto(message, IP, PORT)
		end)
		if not success or not err then
			print("[Error] UDP transmission failed: " .. tostring(err or "Unknown error"))
			if udp_output then
				pcall(function() udp_output:close() end)
				udp_output = nil
			end
		end
	end


	function MES(fmt, ...)
		print(string.format("" .. fmt, ...))
	end

	function logerror(fmt, ...)
		io.stderr:write(string.format("[LOG] " .. fmt, ...))
	end


end


return exports
