-- main.lua


-- Internal globals.

local win_w, win_h

local maze_str
local maze = {}
local x_len, y_len


-- Internal functions.

function pr(...)
  print(string.format(...))
end

-- Love callbacks.

function love.load()
  win_w, win_h = love.graphics.getDimensions()

  maze_str = loadfile('maze.data')()

  -- Convert maze_str into a table of tables so that maze[x][y] is 0 or 1.
  -- 1 = a wall, 0 = no wall.
  maze = {}
  local x, y = 1, 1
  for line in maze_str:gmatch('[^\n]+') do
    if x_len == nil then
      x_len = #line
      for x = 1, x_len do maze[x] = {} end
    end
    x = 1
    for c in line:gmatch('.') do
      maze[x][y] = (c == '*' and 1 or 0)  -- Means c == '*' ? 1 : 0.
      x = x + 1
    end
    y = y + 1
  end
  y_len = #maze[1]

  -- Below is debug code to check that the maze was parsed correctly.
  --[[
  for y = 1, y_len do
    for x = 1, x_len do
      io.write(maze[x][y] .. ' ')
    end
    print('')
  end
  --]]
end

function love.update(dt)
end

function love.draw()
  love.graphics.setColor(20, 180, 40)
  love.graphics.rectangle('fill', 10, 10, 20, 20)
end

function love.mousepressed(x, y, button)
  print('mouse click:', x, y, button)
  print('window size: ', win_w, win_h)
end
