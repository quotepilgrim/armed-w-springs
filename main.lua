local level = require("levels.level1")
local current_level = "level1"
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
local sheet, lock, page_lock
local up, down, left, right
local level_names = require("levels.list")
local level_ids = {}
local last_entrance = {x = 8, y = 12}

for i, v in pairs(level_names) do
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
	33, 34, 35, 36, 41, 42, 43, 44
}

local goal = 25
local box = 26
local box_on_goal = 27

local player = {}

local function player_to_map_position(x, y)
	return x + 1 + y * level.width
end

local function check_wall(pos)
	for _, t in pairs({walls, doors}) do
		for _, v in pairs(t) do
			if level.layers[1].data[pos] == v then
				return true
			end
		end
	end
	return false
end

local function nuke_level()
	package.loaded["levels." .. current_level] = nil
	_G["levels." .. current_level] = nil
end

local function open_entrance()
	if player.facing == dirs.north then
		level.layers[1].data[player_to_map_position(8,13)] = 10
		level.layers[1].data[player_to_map_position(8,14)] = 10
	end
	
	if player.facing == dirs.east then
		level.layers[1].data[player_to_map_position(0,7)] = 10
		level.layers[1].data[player_to_map_position(1,7)] = 10
	end

	if player.facing == dirs.south then
		level.layers[1].data[player_to_map_position(8,1)] = 10
		level.layers[1].data[player_to_map_position(8,0)] = 10
	end
	
	if player.facing == dirs.west then
		level.layers[1].data[player_to_map_position(15,7)] = 10
		level.layers[1].data[player_to_map_position(16,7)] = 10
	end
end

local function change_level(level_name, x, y, open)
	if level_name then
		nuke_level()
		level = require("levels." .. level_name)
		last_entrance.x = x
		last_entrance.y = y
		player.x = x
		player.y = y
		current_level = level_name
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

local function nuke_doors()
	for i, v in ipairs(level.layers[1].data) do
		for _, d in ipairs(doors) do
			if v == d then
				level.layers[1].data[i] = 10
			end
		end
	end
end

function player.move()
	local north = player_to_map_position(player.x, player.y - 1)
	local east = player_to_map_position(player.x + 1, player.y)
	local south = player_to_map_position(player.x, player.y + 1)
	local west = player_to_map_position(player.x - 1, player.y)
	if player.facing == dirs.north then
		if check_wall(north) or player.y < 1 then
			return
		end
		player.y = player.y - 1
	elseif player.facing == dirs.east then
		if check_wall(east) or player.x >= level.width-1 then
			return
		end
		player.x = player.x + 1
	elseif player.facing == dirs.south then
		if check_wall(south) or player.y >= level.height-1 then
			return
		end
		player.y = player.y + 1
	elseif player.facing == dirs.west then
		if check_wall(west) or player.x < 1 then
			return
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
end

function love.load()
	love.window.setMode(256 * scale, 224 * scale)
	love.graphics.setDefaultFilter("nearest", "nearest")
	sheet = love.graphics.newImage("graphics/level_tiles.png")

	player.quads = {}
	player.x = 8
	player.y = 12
	player.normal = love.graphics.newImage("graphics/char_normal.png")
	player.facing = dirs.north
	player.frame = 0
	player.alt = 1
	player.sprite = "normal"
	player.state = "idle"

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

function love.update(dt)
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

	if love.keyboard.isDown("pagedown") then
		if not page_lock then
			page_lock = true
			local new_level = level_names[level_ids[current_level] + 1]
			if new_level then
				player.facing = dirs.north
				change_level(new_level, 8, 12)
			end
		end
	elseif love.keyboard.isDown("pageup") then
		if not page_lock then
			page_lock = true
			local new_level = level_names[level_ids[current_level] - 1]
			if new_level then
				player.facing = dirs.north
				change_level(new_level, 8, 12)
			end
		end
	else
		page_lock = false
	end
	
	if love.keyboard.isDown("r") then
		reset_level()
	end

	if love.keyboard.isDown("delete") then
		nuke_doors()
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
		elseif down then
			player.facing = dirs.south
			player.state = "moving"
		elseif left then
			player.facing = dirs.west
			player.state = "moving"
		elseif right then
			player.facing = dirs.east
			player.state = "moving"
		end
	else
		player.state = "idle"
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
			lock = true
			player.move()
		end
		if move_timer > 0.3 then
			move_timer = move_timer - 0.3
			player.move()
		end
	elseif player.state == "idle" then
		move_timer = 0
		frame_timer = 0
		player.frame = 0
		lock = false
	end
end
