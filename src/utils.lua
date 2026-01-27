local Utils = {}

function Utils.reverseTable(t)
    local newT = {}
    for i = #t, 1, -1 do
        table.insert(newT, t[i])
    end
    return newT
end

function Utils.copyGrid(grid)
    local newGrid = {}
    for y = 1, #grid do
        newGrid[y] = {}
        for x = 1, #grid[y] do
            newGrid[y][x] = grid[y][x]
        end
    end
    return newGrid
end

function Utils.gridsAreEqual(g1, g2)
    for y = 1, #g1 do
        for x = 1, #g1[y] do
            if g1[y][x] ~= g2[y][x] then
                return false
            end
        end
    end
    return true
end

function Utils.printGrid(grid)
    for y = 1, #grid do
        local line = ""
        for x = 1, #grid[y] do
            line = line .. grid[y][x] .. "\t"
        end
        print(line)
    end
end

return Utils
