local id = {}

local t = {
    floor = 10,
    cage = 24,
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
    oneway = 59,
    box_on_oneway = 63,
    box_in_cage = 64,
}

for k, v in pairs(t) do
    id[k] = v
end

id.holes = { 52, 53, 54 }

id.walls = {
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

id.boxes = {
    t.box,
    t.box_on_goal,
    t.box_on_plate,
    t.box_on_tile,
    t.box_on_bplate,
    t.box_on_box,
    t.box_on_oneway,
    t.box_in_cage,
}

id.doors = {
    33,
    34,
    35,
    36,
    41,
    42,
    43,
    44,
}

id.oneways = {
    t.oneway,
    t.oneway + 1,
    t.oneway + 2,
    t.oneway + 3,
}

id.box_to_floor = {
    [t.box] = t.floor,
    [t.box_on_goal] = t.goal,
    [t.box_on_tile] = t.tile,
    [t.box_on_plate] = t.plate,
    [t.box_on_bplate] = t.bplate,
    [t.box_on_box] = t.box_floor,
    [t.box_on_oneway] = t.oneway,
    [t.box_in_cage] = t.cage,
}

id.floor_to_box = {}

for k, v in pairs(id.box_to_floor) do
    id.floor_to_box[v] = k
end

for _, v in pairs(id.oneways) do
    id.floor_to_box[v] = t.box_on_oneway
end

return id
