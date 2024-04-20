local level = {}
local level_names = require("levels.list")
local id = require("id")
local current_level = "level1"
local data = {}
local old_data = {}
local states = {
    title = {},
    starting = {},
    base = {},
    moving = {},
    message = {},
    ["end"] = {},
    event_3_1 = {},
    event_3_1_5 = {},
}

local game_state = "title"
local pos = 0
local solved_levels = { count = 0 }
local history = {}
local messages = {}
local sounds = {}
local events = { ["level3"] = { "3_1", "3_2", "3_3", "3_3.5", "3_4" } }
local event_name = nil
local current_message = ""
local portraits = {}
local key_pressed = false
local offset_x, offset_y = 0, 0
local width, height, flags = 0, 0, {}

local msg = require("msg")

local tiles = {}
local scale = 4
local spring = false
local tile_flip = false
local dirs = {
    ["north"] = 0,
    ["east"] = 1,
    ["south"] = 2,
    ["west"] = 3,
}
local wait = 0
local frame_timer = 0
local move_timer = 0
local key_count = 0
local sheet, lock, message_text, title
local up, down, left, right
local level_ids = {}
local last_entrance = { x = 8, y = 12 }

for i, v in ipairs(level_names) do
    level_ids[v] = i
end

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

        current_level = "level" .. arg[i + 1]
        game_state = "base"
    end
end

local function coords_to_index(x, y)
    return x + 1 + y * level.width
end

local function copy_table(t)
    local result = {}
    for k, v in pairs(t) do
        result[k] = v
    end
    return result
end

local function diff_table(t1, t2)
    for i, v in ipairs(t1) do
        if v ~= t2[i] then
            return true
        end
    end
    return false
end

local function update_history(t)
    local update = false
    if #history > 0 then
        update = diff_table(history[#history][1], t)
    else
        update = true
    end
    if update then
        table.insert(history, { copy_table(t), player.facing, player.x, player.y })
    end
end

local function goal_in_level()
    for _, v in pairs(data) do
        if v == id.goal then
            return true
        end
    end
    return false
end

local function check_wall(pos, is_box)
    for _, t in pairs({ id.walls, id.doors }) do
        for _, v in pairs(t) do
            if data[pos] == v then
                return true
            end
        end
    end

    if is_box then
        for _, v in pairs(id.oneways) do
            if data[pos] == v and v ~= (id.oneway + player.facing) then
                return true
            end
        end
        if data[pos] == id.box_wall then
            return true
        end
    else
        for _, v in pairs(id.holes) do
            if data[pos] == v then
                return true
            end
        end
    end
    return false
end

local function check_box(pos)
    for _, v in pairs(id.boxes) do
        if data[pos] == v then
            return true
        end
    end

    return false
end

local function flip_tiles()
    for i, v in pairs(data) do
        if v == id.block then
            data[i] = id.tile
        elseif v == id.tile and not (coords_to_index(player.x, player.y) == i) then
            data[i] = id.block
        end
    end
end

local function move_box(pos, direction)
    local found_box = false
    local x = math.fmod(pos, level.width)
    --local y = math.floor(pos / level.height)
    local new_pos
    local hole = false

    if x <= 1 or x >= level.width then
        data[pos] = id.floor
    end

    for _, v in pairs(id.boxes) do
        if data[pos] == v then
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

    if check_wall(new_pos, true) or check_box(new_pos) then
        return false
    end

    if data[pos] == id.box_on_plate and data[new_pos] == id.tile and states.moving.has_moved then
        return false
    end

    for _, v in pairs(id.holes) do
        if data[new_pos] == v then
            data[new_pos] = id.box_floor
            hole = true
            if data[new_pos + level.width] == id.holes[1] then
                data[new_pos + level.width] = id.holes[3]
            end
        end
    end

    for _, v in pairs(id.oneways) do
        if data[new_pos] == v then
            data[new_pos] = id.oneways[1]
        end
    end

    if data[pos] == id.box_on_oneway then
        data[pos] = level.layers[1].data[pos]
        if data[pos] == id.box_on_oneway then
            data[pos] = id.floor
        end
    else
        data[pos] = id.box_to_floor[data[pos]]
    end

    if not hole then
        data[new_pos] = id.floor_to_box[data[new_pos]]
    end

    return true
end

local function open_entrance()
    if player.facing == dirs.north then
        if not (data[coords_to_index(8, 13)] == 36) then
            return
        end
        data[coords_to_index(8, 13)] = 10
        data[coords_to_index(8, 14)] = 10
    end

    if player.facing == dirs.east then
        data[coords_to_index(0, 7)] = 10
        data[coords_to_index(1, 7)] = 10
    end

    if player.facing == dirs.south then
        data[coords_to_index(8, 1)] = 10
        data[coords_to_index(8, 0)] = 10
    end

    if player.facing == dirs.west then
        data[coords_to_index(15, 7)] = 10
        data[coords_to_index(16, 7)] = 10
    end
end

local function nuke_doors()
    if current_level == "level16" and solved_levels.count >= 16 then
        data[coords_to_index(8, 0)] = 49
        data[coords_to_index(8, 1)] = 57
    end

    for i, v in ipairs(data) do
        for _, d in ipairs(id.doors) do
            if v == d then
                data[i] = 10
            end
        end
    end
end

local function change_level(level_name, pos, open)
    if not level_name then
        return
    end

    history = {}
    level = require("levels." .. level_name)

    data = copy_table(level.layers[1].data)

    if not pos and level.properties.start then
        if level.properties.start == "north" then
            pos = { 8, 2 }
            player.facing = dirs.south
        elseif level.properties.start == "east" then
            pos = { 14, 7 }
            player.facing = dirs.west
        elseif level.properties.start == "south" then
            pos = { 8, 12 }
            player.facing = dirs.north
        elseif level.properties.start == "west" then
            pos = { 2, 7 }
            player.facing = dirs.east
        end
    elseif not pos then
        pos = { 8, 12 }
        player.facing = dirs.north
    end

    last_entrance.x = pos[1]
    last_entrance.y = pos[2]
    player.x = pos[1]
    player.y = pos[2]
    current_level = level_name

    if solved_levels[current_level] then
        nuke_doors()
    end

    if open then
        open_entrance()
    end
end

local function reset_level()
    data = copy_table(level.layers[1].data)
    history = {}
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
    if solved_levels[current_level] then
        nuke_doors()
    end
    open_entrance()
end

local function clear_level()
    solved_levels[current_level] = true
    solved_levels.count = solved_levels.count + 1
    nuke_doors()
    sounds.door:play()
end

local function rescale(w, h)
    if h > w * 0.875 then
        scale = w / 256
    else
        scale = h / 224
    end
    offset_x = math.floor((w / scale - 256) / 2)
    offset_y = math.floor((h / scale - 224) / 2)
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
        if current_level == "level16" then
            states["end"].starting = true
            game_state = "end"
        end
        change_level(level.properties.north, { 8, 12 }, true)
    elseif player.x == 15 and player.y == 7 then
        change_level(level.properties.east, { 2, 7 }, true)
    elseif player.x == 8 and player.y == 13 then
        change_level(level.properties.south, { 8, 2 }, true)
    elseif player.x == 1 and player.y == 7 then
        change_level(level.properties.west, { 14, 7 }, true)
    end

    return "floor"
end

function antag.draw()
    love.graphics.draw(antag.image, player.quads[antag.frame + 1 + antag.facing * 4], antag.x * 16, antag.y * 16 - 10)
end

function states.base.draw()
    love.graphics.scale(scale, scale)
    love.graphics.translate(offset_x - 8, offset_y - 8)
    for i, v in ipairs(data) do
        love.graphics.draw(sheet, tiles[v], math.fmod(i - 1, level.width) * 16, math.floor((i - 1) / level.width) * 16)
    end
    love.graphics.draw(
        player[player.sprite],
        player.quads[player.frame + 1 + player.facing * 4],
        player.x * 16,
        player.y * 16 - 10
    )
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, 8, 232)
    love.graphics.rectangle("fill", 0, 0, 264, 8)
    love.graphics.rectangle("fill", 264, 0, 8, 232)
    love.graphics.rectangle("fill", 0, 232, 264, 8)
    love.graphics.setColor(1, 1, 1)
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
                if event_name == "3_1" then
                    move_timer = 0
                    messages = msg.level3[1]
                elseif event_name == "3_2" then
                    messages = msg.level3[2]
                elseif event_name == "3_3" then
                    messages = msg.level3[3]
                elseif event_name == "3_3.5" then
                    spring = true
                    pos = player.move_attempt
                    game_state = "moving"
                    return
                elseif event_name == "3_4" then
                    messages = msg.level3[4]
                end
                current_message = table.remove(messages, 1)
                message_text:set(current_message[2])
                game_state = "message"
                return
            end

            old_data = copy_table(data)

            if spring then
                update_history(old_data)
                pos = player.move_attempt
                game_state = "moving"
                return
            end

            if move_box(player.move_attempt, player.facing) then
                update_history(old_data)
                player.moved_to = player.move()

                if not sounds.door:isPlaying() then
                    sounds.push:play()
                end

                if not goal_in_level() and not solved_levels[current_level] then
                    clear_level()
                end

                if tile_flip then
                    tile_flip = false
                    flip_tiles()
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
            if not goal_in_level() and not solved_levels[current_level] then
                clear_level()
            end

            if states.moving.has_moved and (data[pos] == id.box_on_plate or data[pos] == id.box_on_bplate) then
                flip_tiles()
                states.moving.stop_sound = sounds.click
            else
                states.moving.stop_sound = sounds.hit
            end

            if states.moving.has_moved then
                if not sounds.door:isPlaying() then
                    states.moving.stop_sound:play()
                end
            end

            states.moving.has_moved = false
            game_state = "base"
        else
            if not states.moving.has_moved and data[pos] == id.plate then
                flip_tiles()
            end
            states.moving.has_moved = true
        end

        if tile_flip then
            tile_flip = false
            flip_tiles()
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
    love.graphics.draw(message_box, 16, 16)

    love.graphics.setColor(0, 0, 0)
    love.graphics.draw(message_text, 65, 21)

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(message_text, 64, 20)

    love.graphics.draw(portraits[current_message[1]], 24, 24)
end

function states.message.update(dt)
    if event_name == "3_1" then
        sounds.door:play()
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
    data[coords_to_index(8, 0)] = id.floor
    data[coords_to_index(8, 1)] = id.floor
    data[coords_to_index(8, 3)] = id.tile
    move_timer = move_timer + dt
    frame_timer = frame_timer + dt
    if frame_timer > 0.15 then
        antag.frame = math.fmod(antag.frame + 1, 4)
        frame_timer = frame_timer - 0.15
    end
    if move_timer > 0.3 then
        move_timer = move_timer - 0.3
        antag.y = antag.y + 1
    end
    if antag.y == 5 then
        move_timer = 0
        frame_timer = 0
        antag.frame = 0
        player.sprite = "spring"
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
    if frame_timer > 0.15 then
        antag.frame = math.fmod(antag.frame + 1, 4)
        frame_timer = frame_timer - 0.15
    end
    if move_timer > 0.3 then
        move_timer = move_timer - 0.3
        antag.y = antag.y - 1
    end
    if antag.y == -2 then
        data[coords_to_index(8, 0)] = 33
        data[coords_to_index(8, 1)] = 41
        data[coords_to_index(8, 3)] = 39
        sounds.door:play()
        move_timer = 0
        event_name = ""
        game_state = "base"
        return
    end
end

function states.title.draw()
    love.graphics.scale(scale)
    love.graphics.translate(offset_x, offset_y)
    love.graphics.draw(title, 0, 0)
end

function states.title.update(dt)
    wait = wait - dt
    if wait > 0 then
        return
    else
        wait = 0
    end
    if key_pressed then
        wait = 0.3
        game_state = "starting"
    end
end

states.starting.draw = states.base.draw

function states.starting.update(dt)
    wait = wait - dt
    if wait > 0 then
        return
    else
        wait = 0
    end
    game_state = "base"
end

states["end"].draw = function()
    love.graphics.scale(scale)
    love.graphics.translate(-8, -8)
    love.graphics.draw(message_box, 16, 16)
    love.graphics.setColor(0, 0, 0)
    love.graphics.draw(message_text, 25, 21)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(message_text, 24, 20)
end

states["end"].update = function()
    if states["end"].starting then
        states["end"].starting = false
        lock = false
        messages = copy_table(msg.end_)
        states["end"].msg_count = 1
        message_text:set(msg.end_[states["end"].msg_count])
    end
    if love.keyboard.isDown("space") then
        if not lock then
            lock = true
            states["end"].msg_count = states["end"].msg_count + 1
            if not msg.end_[states["end"].msg_count] then
                wait = 0.5
                change_level(level_names[1], { 8, 12 })
                game_state = "title"
                return
            end
            message_text:set(msg.end_[states["end"].msg_count])
        end
    else
        lock = false
    end
end

function love.load()
    love.window.setMode(256 * scale, 224 * scale, { resizable = true, minwidth = 512, minheight = 448 })
    width, height, flags = love.window.getMode()
    love.graphics.setDefaultFilter("nearest", "nearest")
    sheet = love.graphics.newImage("graphics/level_tiles.png")
    msg_font = love.graphics.newFont("graphics/PixeloidSans.ttf", 9, "mono")
    message_text = love.graphics.newText(msg_font, "")
    portraits = {
        ["player"] = love.graphics.newImage("graphics/player_portrait.png"),
        ["antag"] = love.graphics.newImage("graphics/antag_portrait.png"),
    }
    message_box = love.graphics.newImage("graphics/message_box.png")
    title = love.graphics.newImage("graphics/title.png")
    sounds = {
        ["hit"] = love.audio.newSource("sounds/hit.wav", "static"),
        ["click"] = love.audio.newSource("sounds/click.wav", "static"),
        ["door"] = love.audio.newSource("sounds/door.wav", "static"),
        ["push"] = love.audio.newSource("sounds/push.wav", "static"),
    }
    states.moving.stop_sound = sounds.hit

    player.quads = {}
    player.x = 8
    player.y = 12
    player.normal = love.graphics.newImage("graphics/char_normal.png")
    player.spring = love.graphics.newImage("graphics/char_spring.png")
    player.facing = dirs.north
    player.frame = 0
    player.alt = 1
    player.sprite = "normal"
    player.state = "idle"

    if spring then
        player.sprite = "spring"
    end

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
    change_level(current_level)
end

function love.draw()
    states[game_state].draw()
end

function love.update(dt)
    states[game_state].update(dt)
end

function love.keypressed(key)
    if key ~= "f11" then
        key_pressed = true
    end
    if key == "escape" then
        love.event.quit()
    elseif key == "pagedown" then
        local new_level = level_names[level_ids[current_level] + 1]
        if new_level then
            change_level(new_level)
        else
            change_level(level_names[1])
        end
    elseif key == "pageup" then
        local new_level = level_names[level_ids[current_level] - 1]
        if new_level then
            change_level(new_level)
        else
            change_level(level_names[#level_names])
        end
    elseif key == "delete" then
        if love.keyboard.isDown("lshift", "rshift") and not solved_levels[current_level] then
            clear_level(current_level)
        else
            nuke_doors()
        end
    elseif key == "insert" then
        if spring then
            player.sprite = "normal"
        else
            player.sprite = "spring"
        end
        spring = not spring
    elseif key == "z" or key == "backspace" then
        if not (game_state == "base") then
            return
        end

        local entry = table.remove(history)

        if not entry then
            reset_level()
            return
        end

        if not diff_table(entry[1], data) then
            entry = table.remove(history)
        end

        data = copy_table(entry[1])
        player.facing = entry[2]
        player.x = entry[3]
        player.y = entry[4]

        if solved_levels[current_level] then
            nuke_doors()
        end
    elseif key == "=" then
        local _, _, flags = love.window.getMode()
        local width, height = love.window.getDesktopDimensions(flags.display)
        local new_scale = math.floor(scale) + 1
        if 256 * new_scale > width or 224 * new_scale > height then
            new_scale = new_scale - 1
        end
        scale = new_scale
        love.window.setMode(256 * scale, 224 * scale, { resizable = true, minwidth = 512, minheight = 448 })
        offset_x, offset_y = 0, 0
    elseif key == "-" then
        local new_scale = math.ceil(scale) - 1
        if new_scale < 2 then
            new_scale = 2
        end
        scale = new_scale
        love.window.setMode(256 * scale, 224 * scale, { resizable = true, minwidth = 512, minheight = 448 })
        offset_x, offset_y = 0, 0
    elseif key == "r" or key == "home" then
        if not (game_state == "base") then
            return
        end

        if love.keyboard.isDown("lshift", "rshift") then
            if not solved_levels[current_level] then
                return
            end
            solved_levels[current_level] = nil
            solved_levels.count = solved_levels.count - 1
        end

        reset_level()
    elseif key == "f1" then
        print(current_level, solved_levels.count, #level_names)
    elseif key == "f11" then
        if not love.window.getFullscreen() then
            width, height, flags = love.window.getMode()
            love.window.setFullscreen(true)
        else
            love.window.setMode(width, height, flags)
            rescale(width, height)
        end
    end
end

function love.keyreleased()
    key_pressed = false
end

function love.resize(w, h)
    WindowWidth = w
    WindowHeight = h
    rescale(w, h)
end
