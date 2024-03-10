local level = require("levels.level1")
local level_names = require("levels.list")
local current_level = "level1"
local states = {
	base = {},
	moving = {},
	message = {},
	event_3_1 = {},
	event_3_1_5 = {},
}
local game_state = "base"
local pos = 0
local facing = 0
local solved_levels = {}
local history = {}
local messages = {}
local msg_level3 = {}
local events = { ["level3"] = { "3_1", "3_2", "3_3", "3_3.5", "3_4" } }
local event_name = nil
local current_message = ""
local portraits = {}

msg_level3[1] = {
	{ "antag", "Summers, autumns, winters,\nyour arms are now springs!" },
	{ "player", "Uh, what?" },
}

msg_level3[2] = {
	{ "player", "What the hell was that?" },
	{ "player", "Also, how am I going to push\nboxes with these stupid spring arms?" },
}

msg_level3[3] = {
	{ "player", "Well, here goes nothing!" },
}

msg_level3[4] = {
	{ "player", "Dammit!, it went much further\nthan I was expecting." },
	{ "player", "..." },
	{ "player", "This is going to make getting\nthe boxes where I want to a huge pain" },
}

local tiles = {}
local scale = 4
local spring = false
local dirs = {
	["north"] = 0,
	["east"] = 1,
	["south"] = 2,
	["west"] = 3,
}
local frame_timer = 0
local move_timer = 0
local key_count = 0
local sheet, lock, message_text
local up, down, left, right
local level_ids = {}
local last_entrance = { x = 8, y = 12 }

for i, v in ipairs(level_names) do
	level_ids[v] = i
end

local walls = {
	1,
	2,
	3,
	4,
	5,
	6,
	7,
	8,
	9,
	11,
	12,
	13,
	14,
	15,
	16,
	17,
	18,
	19,
	20,
	21,
	22,
	24,
	28,
	29,
	30,
	31,
	32,
	37,
	38,
	39,
}

local doors = {
	33,
	34,
	35,
	36,
	41,
	42,
	43,
	44,
}

local floor = 10
local goal = 25
local box = 26
local box_on_goal = 27

local player = {}
local antag = {}

for i, v in ipairs(arg) do
	if v == "--warp" or v == "-w" then
		if tonumber(arg[i + 1]) < 1 or tonumber(arg[i + 1]) > #level_names then
			break
		end
		if tonumber(arg[i + 1]) > 3 then
			events.level3 = {}
			spring = true
		end
		level = require("levels.level" .. arg[i + 1])
		current_level = "level" .. arg[i + 1]
		print(arg[i + 1])
	end
end

local function coords_to_index(x, y)
	return x + 1 + y * level.width
end

local function copy_table(t)
	local data = {}
	for k, v in pairs(t) do
		data[k] = v
	end
	return data
end

local function update_history()
	table.insert(history, { copy_table(level.layers[1].data), player.facing, player.x, player.y })
end

local function goal_in_level()
	for _, v in pairs(level.layers[1].data) do
		if v == goal then
			return true
		end
	end
	return false
end

local function check_wall(pos)
	for _, t in pairs({ walls, doors }) do
		for _, v in pairs(t) do
			if level.layers[1].data[pos] == v then
				return true
			end
		end
	end
	return false
end

local function check_box(pos)
	if level.layers[1].data[pos] == box or level.layers[1].data[pos] == box_on_goal then
		return true
	end
	return false
end

local function move_box(pos, direction)
	local found_box = false
	local x = math.fmod(pos, level.width)
	local y = math.floor(pos / level.height)

	if x == 1 or x == level.width then
		level.layers[1].data[pos] = floor
	end

	if not spring then
		update_history()
	end

	for _, v in pairs({ box, box_on_goal }) do
		if level.layers[1].data[pos] == v then
			found_box = true
		end
	end

	if not found_box then
		return false
	end

	if direction == dirs.north then
		new_pos = pos - level.width
	elseif direction == dirs.east then
		new_pos = pos + 1
	elseif direction == dirs.south then
		new_pos = pos + level.width
	elseif direction == dirs.west then
		new_pos = pos - 1
	end

	if check_wall(new_pos) or check_box(new_pos) then
		return false
	elseif level.layers[1].data[pos] == box then
		level.layers[1].data[pos] = floor
	elseif level.layers[1].data[pos] == box_on_goal then
		level.layers[1].data[pos] = goal
	end

	if level.layers[1].data[new_pos] == floor then
		level.layers[1].data[new_pos] = box
	elseif level.layers[1].data[new_pos] == goal then
		level.layers[1].data[new_pos] = box_on_goal
	end

	return true
end

local function nuke_level()
	package.loaded["levels." .. current_level] = nil
	_G["levels." .. current_level] = nil
end

local function open_entrance()
	if player.facing == dirs.north then
		level.layers[1].data[coords_to_index(8, 13)] = 10
		level.layers[1].data[coords_to_index(8, 14)] = 10
	end

	if player.facing == dirs.east then
		level.layers[1].data[coords_to_index(0, 7)] = 10
		level.layers[1].data[coords_to_index(1, 7)] = 10
	end

	if player.facing == dirs.south then
		level.layers[1].data[coords_to_index(8, 1)] = 10
		level.layers[1].data[coords_to_index(8, 0)] = 10
	end

	if player.facing == dirs.west then
		level.layers[1].data[coords_to_index(15, 7)] = 10
		level.layers[1].data[coords_to_index(16, 7)] = 10
	end
end

local function nuke_doors()
	for i, v in ipairs(level.layers[1].data) do
		for _, d in ipairs(doors) do
			if v == d then
				level.layers[1].data[i] = 10
			end
		end
	end
end

local function change_level(level_name, x, y, open)
	if level_name then
		history = {}
		nuke_level()
		level = require("levels." .. level_name)
		last_entrance.x = x
		last_entrance.y = y
		player.x = x
		player.y = y
		current_level = level_name

		if solved_levels[current_level] then
			nuke_doors()
		end

		if open then
			open_entrance()
		end
	end
end

local function reset_level()
	nuke_level()
	level = require("levels." .. current_level)
	player.x = last_entrance.x
	player.y = last_entrance.y
	if player.y == 2 then
		player.facing = dirs.south
	end
	if player.x == 14 then
		player.facing = dirs.west
	end
	if player.y == 12 then
		player.facing = dirs.north
	end
	if player.x == 2 then
		player.facing = dirs.east
	end
	open_entrance()
end

function player.move()
	local north = coords_to_index(player.x, player.y - 1)
	local east = coords_to_index(player.x + 1, player.y)
	local south = coords_to_index(player.x, player.y + 1)
	local west = coords_to_index(player.x - 1, player.y)

	if player.facing == dirs.north then
		player.move_attempt = north
		if check_wall(north) or player.y < 1 then
			return "wall"
		elseif check_box(north) then
			return "box"
		end
		player.y = player.y - 1
	elseif player.facing == dirs.east then
		player.move_attempt = east
		if check_wall(east) or player.x >= level.width - 1 then
			return "wall"
		elseif check_box(east) then
			return "box"
		end
		player.x = player.x + 1
	elseif player.facing == dirs.south then
		player.move_attempt = south
		if check_wall(south) or player.y >= level.height - 1 then
			return "wall"
		elseif check_box(south) then
			return "box"
		end
		player.y = player.y + 1
	elseif player.facing == dirs.west then
		player.move_attempt = west
		if check_wall(west) or player.x < 1 then
			return "wall"
		elseif check_box(west) then
			return "box"
		end

		player.x = player.x - 1
	end

	if player.x == 8 and player.y == 1 then
		change_level(level.properties.north, 8, 12, true)
	elseif player.x == 15 and player.y == 7 then
		change_level(level.properties.east, 2, 7, true)
	elseif player.x == 8 and player.y == 13 then
		change_level(level.properties.south, 8, 2, true)
	elseif player.x == 1 and player.y == 7 then
		change_level(level.properties.west, 14, 7, true)
	end

	return "floor"
end

function antag.draw()
	love.graphics.draw(antag.image, player.quads[antag.frame + 1 + antag.facing * 4], antag.x * 16, antag.y * 16 - 10)
end

function states.base.draw()
	love.graphics.scale(scale, scale)
	love.graphics.translate(-8, -8)
	for k, v in pairs(level.layers[1].data) do
		love.graphics.draw(sheet, tiles[v], math.fmod(k - 1, level.width) * 16, math.floor((k - 1) / level.width) * 16)
	end
	love.graphics.draw(
		player[player.sprite],
		player.quads[player.frame + 1 + player.facing * 4],
		player.x * 16,
		player.y * 16 - 10
	)
end

function states.base.update(dt)
	if love.keyboard.isDown("w", "up", "kp8") then
		up = true
	else
		up = false
	end

	if love.keyboard.isDown("s", "down", "kp2") then
		down = true
	else
		down = false
	end

	if love.keyboard.isDown("a", "left", "kp4") then
		left = true
	else
		left = false
	end

	if love.keyboard.isDown("d", "right", "kp6") then
		right = true
	else
		right = false
	end

	key_count = 0
	for _, v in pairs({ up, down, left, right }) do
		if v then
			key_count = key_count + 1
		end
	end

	if key_count == 1 then
		if up then
			player.facing = dirs.north
			player.state = "moving"
		elseif right then
			player.facing = dirs.east
			player.state = "moving"
		elseif down then
			player.facing = dirs.south
			player.state = "moving"
		elseif left then
			player.facing = dirs.west
			player.state = "moving"
		end
	else
		player.state = "idle"
		if event_name == "3_3" or event_name == "3_3.5" then
			player.state = "moving"
		end
	end

	if player.state == "moving" then
		move_timer = move_timer + dt
		frame_timer = frame_timer + dt
		if frame_timer > 0.15 then
			player.frame = math.fmod(player.frame + 1, 4)
			frame_timer = frame_timer - 0.15
		end
		if not lock then
			player.alt = math.fmod(player.alt + 2, 4)
			player.frame = player.alt
			player.moved_to = player.move()
			lock = true
		end
		if move_timer > 0.3 then
			move_timer = move_timer - 0.3
			player.moved_to = player.move()
		end
		if player.moved_to == "box" or event_name == "3_3.5" then
			player.moved_to = ""
			if current_level == "level3" and #events.level3 > 0 then
				event_name = table.remove(events.level3, 1)
				print(events.level3)
				if event_name == "3_1" then
					move_timer = 0
					event_count = 1
					messages = msg_level3[1]
				elseif event_name == "3_2" then
					messages = msg_level3[2]
				elseif event_name == "3_3" then
					messages = msg_level3[3]
				elseif event_name == "3_3.5" then
					spring = true
					pos = player.move_attempt
					game_state = "moving"
					return
				elseif event_name == "3_4" then
					messages = msg_level3[4]
				end
				current_message = table.remove(messages, 1)
				message_text:set(current_message[2])
				game_state = "message"
				return
			end
			if spring then
				update_history()
				pos = player.move_attempt
				game_state = "moving"
				return
			end
			if move_box(player.move_attempt, player.facing) then
				player.moved_to = player.move()
				if not goal_in_level() then
					solved_levels[current_level] = true
					nuke_doors()
				end
			end
		end
	elseif player.state == "idle" then
		move_timer = 0
		frame_timer = 0
		player.frame = 0
		lock = false
	end
end

states.moving.draw = states.base.draw

function states.moving.update(dt)
	move_timer = move_timer + dt
	frame_timer = frame_timer + dt

	if move_timer > 0.05 then
		if not move_box(pos, player.facing) then
			if not goal_in_level() then
				solved_levels[current_level] = true
				nuke_doors()
			end
			game_state = "base"
		end

		if player.facing == dirs.north then
			pos = pos - level.width
		elseif player.facing == dirs.east then
			pos = pos + 1
		elseif player.facing == dirs.south then
			pos = pos + level.width
		elseif player.facing == dirs.west then
			pos = pos - 1
		end
		move_timer = move_timer - 0.05
	end

	if frame_timer > 0.2 then
		player.frame = 0
	end
end

function states.message.draw()
	states.base.draw()
	if event_name == "3_1" then
		return
	end
	antag.draw()
	love.graphics.setColor(0, 0, 255)
	love.graphics.rectangle("fill", 16, 16, 240, 48)

	love.graphics.setColor(0, 0, 0)
	for i = 1, 2 do
		love.graphics.draw(message_text, 65, 21)
	end

	love.graphics.setColor(255, 255, 255)
	for i = 1, 2 do
		love.graphics.draw(message_text, 64, 20)
	end

	love.graphics.draw(portraits[current_message[1]], 24, 24)
end

function states.message.update(dt)
	if event_name == "3_1" then
		game_state = "event_3_1"
		return
	end
	if love.keyboard.isDown("space") then
		if not lock then
			lock = true
			current_message = table.remove(messages, 1)
			if not current_message then
				if event_name == "3_1.5" then
					antag.facing = dirs.north
					game_state = "event_3_1_5"
				else
					game_state = "base"
				end
				return
			end
			message_text:set(current_message[2])
		end
	else
		lock = false
	end
end

function states.event_3_1.draw()
	states.base.draw()
	antag.draw()
end

function states.event_3_1.update(dt)
	level.layers[1].data[coords_to_index(8, 0)] = floor
	level.layers[1].data[coords_to_index(8, 1)] = floor
	level.layers[1].data[coords_to_index(8, 3)] = goal
	move_timer = move_timer + dt
	frame_timer = frame_timer + dt
	if frame_timer > 0.15 then
		antag.frame = math.fmod(antag.frame + 1, 4)
		frame_timer = frame_timer - 0.15
	end
	if move_timer > 0.15 then
		move_timer = move_timer - 0.15
		antag.y = antag.y + 1
	end
	if antag.y == 5 then
		move_timer = 0
		frame_timer = 0
		antag.frame = 0
		event_name = "3_1.5"
		game_state = "message"
		return
	end
end

function states.event_3_1_5.draw()
	states.base.draw()
	antag.draw()
end

function states.event_3_1_5.update(dt)
	move_timer = move_timer + dt
	frame_timer = frame_timer + dt
	if move_timer > 0.15 then
		move_timer = move_timer - 0.15
		antag.y = antag.y - 1
	end
	if move_timer > 0.15 then
		move_timer = move_timer - 0.15
		antag.y = antag.y + 1
	end
	if antag.y == -2 then
		level.layers[1].data[coords_to_index(8, 0)] = 33
		level.layers[1].data[coords_to_index(8, 1)] = 41
		level.layers[1].data[coords_to_index(8, 3)] = 39
		move_timer = 0
		event_name = ""
		game_state = "base"
		return
	end
end

function love.load()
	love.window.setMode(256 * scale, 224 * scale)
	love.graphics.setDefaultFilter("nearest", "nearest")
	sheet = love.graphics.newImage("graphics/level_tiles.png")
	msg_font = love.graphics.newFont(10)
	message_text = love.graphics.newText(msg_font, "")
	portraits = {
		["player"] = love.graphics.newImage("graphics/player_portrait.png"),
		["antag"] = love.graphics.newImage("graphics/antag_portrait.png"),
	}

	player.quads = {}
	player.x = 8
	player.y = 12
	player.normal = love.graphics.newImage("graphics/char_normal.png")
	player.facing = dirs.north
	player.frame = 0
	player.alt = 1
	player.sprite = "normal"
	player.state = "idle"

	antag.x = 8
	antag.y = -2
	antag.image = love.graphics.newImage("graphics/antag.png")
	antag.facing = dirs.south
	antag.frame = 0

	for i = 1, 8 do
		for j = 1, 8 do
			tiles[i + (j - 1) * 8] = love.graphics.newQuad((i - 1) * 16, (j - 1) * 16, 16, 16, 128, 128)
		end
	end

	for i = 1, 4 do
		for j = 1, 4 do
			player.quads[i + (j - 1) * 4] = love.graphics.newQuad((i - 1) * 16, (j - 1) * 24, 16, 24, 64, 96)
		end
	end
end

function love.draw()
	states[game_state].draw()
end

function love.update(dt)
	states[game_state].update(dt)
end

function love.keypressed(key, scancode, isrepeat)
	if key == "escape" then
		love.event.quit()
	elseif key == "pagedown" then
		local new_level = level_names[level_ids[current_level] + 1]
		if new_level then
			player.facing = dirs.north
			change_level(new_level, 8, 12)
		else
			change_level(level_names[1], 8, 12)
		end
	elseif key == "pageup" then
		local new_level = level_names[level_ids[current_level] - 1]
		if new_level then
			player.facing = dirs.north
			change_level(new_level, 8, 12)
		else
			change_level(level_names[#level_names], 8, 12)
		end
	elseif key == "delete" then
		nuke_doors()
	elseif key == "insert" then
		spring = not spring
	elseif key == "z" or key == "backspace" then
		local data = table.remove(history)
		if not data then
			reset_level()
			return
		end
		level.layers[1].data = copy_table(data[1])
		player.facing = data[2]
		player.x = data[3]
		player.y = data[4]
	elseif key == "=" then
		local _, _, flags = love.window.getMode()
		local width, height = love.window.getDesktopDimensions(flags.display)
		local new_scale = scale + 1
		if 256 * new_scale > width or 224 * new_scale > height then
			return
		end
		scale = new_scale
		love.window.setMode(256 * scale, 224 * scale)
	elseif key == "-" then
		local new_scale = scale - 1
		if new_scale < 2 then
			return
		end
		scale = new_scale
		love.window.setMode(256 * scale, 224 * scale)
	elseif key == "r" then
		reset_level()
	end
end
