local list = {}
local count = 1

while true do
    if love.filesystem.getInfo("levels/level" .. tostring(count) .. ".lua") then
        list[count] = "level" .. tostring(count)
    else
        break
    end
    count = count + 1
end

return list
