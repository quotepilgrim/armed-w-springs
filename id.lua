local t = {}

local id = {
    floor = 10,
    goal = 25,
    box = 26,
    box_on_goal = 27,
    block = 39,
    tile = 40,
    plate = 45,
    box_on_plate = 46,
    box_on_tile = 47,
    bplate = 50,
    box_wall = 51,
    box_on_bplate = 55,
    box_on_box = 56,
    box_floor = 58,
}

for k, v in pairs(id) do
    t[k] = v
end

t.holes = { 52, 53, 54 }

t.walls = {
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    9,
    11,
    12,
    13,
    14,
    15,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    28,
    29,
    30,
    31,
    32,
    37,
    38,
    39,
    48,
}

t.boxes = {
    id.box,
    id.box_on_goal,
    id.box_on_plate,
    id.box_on_tile,
    id.box_on_bplate,
    id.box_on_box,
}

t.doors = {
    33,
    34,
    35,
    36,
    41,
    42,
    43,
    44,
}

t.box_to_floor = {
    [id.box] = id.floor,
    [id.box_on_goal] = id.goal,
    [id.box_on_tile] = id.tile,
    [id.box_on_plate] = id.plate,
    [id.box_on_bplate] = id.bplate,
    [id.box_on_box] = id.box_floor,
}

t.floor_to_box = {}

for k, v in pairs(t.box_to_floor) do
    t.floor_to_box[v] = k
end

return t
