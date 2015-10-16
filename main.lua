-- main.lua

-- Parameters.

local do_allow_many_start_pts = false


-- Internal globals.

local win_w, win_h

local maze_str
local maze = {}
local x_len, y_len

local entities = {}

local tile_size = 35

-- G[x][y] = {nbors of that grid pt}.
local G = {}

-- Valid values are 'draw_path', 'maze_edit', or eventually 'short_path'.
local mode = 'draw_path'

local clock = 0
local status_msg = {}


-- Internal hook system; a way to inject function calls into the run loop.

local draw_fns = {}
local mousepressed_fns = {}
local mousemoved_fns = {}


-- The Button class.
--
-- Usage:
--   -- This takes screen coords of the button's upper-left corner.
--   local button = Button.new(x, y, text)
--   button.on_click = <my function>
--

local Button = {}
Button.__index = Button  -- So we can use Button as a metatable.

function Button.new(x, y, text)
  local button = {x = x, y = y, text = text, w = 200, h = 30}
  setmetatable(button, Button)

  -- Add hooks to our run loop and input functions.
  table.insert(draw_fns, function () button:draw() end)
  table.insert(mousepressed_fns, function (x, y) button:mousepressed(x, y) end)
  table.insert(mousemoved_fns, function (x, y) button:mousemoved(x, y) end)

  return button
end

function Button:draw()
  local bkg_color = (self.is_hovered and {80, 80, 140} or {40, 40, 90})
  love.graphics.setColor(bkg_color)
  love.graphics.rectangle('fill', self.x, self.y, self.w, self.h)
  love.graphics.setColor(255, 255, 255)
  love.graphics.print(self.text, self.x + 10, self.y + 10)

  -- Draw a highlight outline if we're highlighted.
  if self.is_highlighted then
    love.graphics.setColor(255, 255, 255)
    love.graphics.rectangle('line', self.x - 1, self.y - 1,
                                    self.w + 1, self.h + 1)
  end
end

function Button:mousepressed(x, y)
  if self.on_click and self.is_hovered then self:on_click(x, y) end
end

function Button:mousemoved(x, y)
  self.is_hovered = (x >= self.x and x < self.x + self.w and
                     y >= self.y and y < self.y + self.h)
end


-- Button helper data and functions.

local buttons = {}

function highlight_button(button)
  for _, b in pairs(buttons) do
    b.is_highlighted = (b == button)
  end
end


-- Grid drawing functions.

local y_grid_offset = 40

function draw_tile(x, y)
  y = y + y_grid_offset / tile_size
  love.graphics.rectangle('fill', x * tile_size, y * tile_size,
                          tile_size - 1, tile_size - 1)
end

function draw_dot(x, y, r)
  y = y + y_grid_offset / tile_size
  love.graphics.circle('fill',
                       (x + 0.5) * tile_size, (y + 0.5) * tile_size, r, 20)
end

function draw_path(path)
  local p = {}
  for i, coord in ipairs(path) do
    p[#p + 1] = (coord + 0.5) * tile_size
    if i % 2 == 0 then p[#p] = p[#p] + y_grid_offset end
  end
  love.graphics.line(p)
end


-- Ray-marching functions.

-- This is an iterator.
-- It returns a function that returns the next element with each call,
-- finally returning nil when all elements have been returned.
-- Each element is an array of elements of the set.
-- This code is essentially algorithm L from section 7.2.1.3 of
-- Knuth's The Art of Computer Programming.
local function all_nonzero_subsets_in_order(set)  -- Input is a key set.
  local set_arr = {}
  for key in pairs(set) do set_arr[#set_arr + 1] = key end

  local n = #set_arr
  local t = 1  -- The set of the next subset to return.

  -- c[i] is the index of the ith item to return.
  -- We only return set_arr[c[1], ... , c[t]].
  local c = {1, n + 1, 0}

  return function ()
    -- Return nil if we're done.
    if t > n then return nil end

    -- Build the return set based on c.
    local ret = {}
    for i = 1, t do ret[set_arr[c[i]]] = true end

    -- Walk up j to see how we can increment c.
    local j = 1
    while c[j] + 1 == c[j + 1] do
      c[j] = j
      j = j + 1
    end

    -- Calculate the next c values.
    if j > t then
      -- We're done with the current t.
      t = t + 1
      for i = 1, t do c[i] = i end
      c[t + 1], c[t + 2] = n + 1, 0
    else
      -- Not done with t; set up the next c values.
      c[j] = c[j] + 1
    end

    return ret
  end
end

-- Returns the next integer 'after' from in the given dir. dir is expected
-- to be nonzero.
local function next_hit(from, dir)
  if dir > 0 then
    return math.floor(from + 1)
  else
    return math.ceil (from - 1)
  end
end

-- Returns the min of elements of t; t is expected to be an array of numbers.
-- Returns nil if t is empty.
local function min(t)
  local m
  for _, v in pairs(t) do
    if m == nil or v < m then
      m = v
    end
  end
  return m
end

local function sign(x)
  if x > 0 then return  1 end
  if x < 0 then return -1 end
  return 0
end


-- Internal functions.

-- Save the current maze to saved_maze.data.
-- The loaded maze is from maze.data, so you may need to move files around to
-- load this maze the next time you run this program.
function save_maze()
  f = io.open('new_maze.data', 'w')
  f:write('local maze = [[\n')
  for y = 1, y_len do
    for x = 1, x_len do
      f:write(maze[x][y] == 1 and '*' or ' ')
    end
    f:write('\n')
  end
  f:write(']]\n\nreturn maze\n')
  f:close()

  status_msg.msg  = 'saved!'
  status_msg.x    = 710
  status_msg.y    =  20
  status_msg.till = clock + 5
end

function pr(...)
  print(string.format(...))
end

-- Returns the Euclidean distance from (x, y) to the goal point.
function d(x, y)
  -- The goal point is (x_len, 1).
  local dx, dy = x - x_len, y - 1
  return math.sqrt(dx ^ 2 + dy ^ 2)
end

-- This builds the graph structure in G.
-- G[x][y] = {nbors of grid point (x, y)}
function build_G()
  for x = 1, x_len do G[x] = {} end
  for y = 1, y_len do
    for x = 1, x_len do
      if maze[x][y] == 0 then  -- Make sure the grid space is not a wall.
        G[x][y] = {}  -- This is the nbor list.
        if maze[x + 1][y] == 0 then table.insert(G[x][y], {x + 1, y}) end
        if maze[x - 1][y] == 0 then table.insert(G[x][y], {x - 1, y}) end
        if maze[x][y + 1] == 0 then table.insert(G[x][y], {x, y + 1}) end
        if maze[x][y - 1] == 0 then table.insert(G[x][y], {x, y - 1}) end
      end
    end
  end

  -- Below is debug code to help verify that G is correct.
  --[[
  for y = 1, y_len do
    for x = 1, x_len do
      if G[x][y] then
        pr('G[%d][%d] has nbors:', x, y)
        for _, nbor in pairs(G[x][y]) do
          pr('  {%d, %d}', nbor[1], nbor[2])
        end
      end
    end
  end
  --]]
end

-- This returns a list of x, y pairs starting at the given arguments and
-- ending at the goal point x_len, 1. This uses A* search.
function find_path_via_A_star(start_x, start_y)
  -- Our goal point is {x_len, 1}.

  -- Set up the metadata.
  -- pt_data[x][y] = { shortest_to_here, approx_shortest_via }
  local pt_data = {}
  for x = 1, x_len do pt_data[x] = {} end
  for y = 1, y_len do
    for x = 1, x_len do
      pt_data[x][y] = { shortest_to_here    = math.huge,
                        approx_shortest_via = math.huge }
    end
  end
  pt_data[start_x][start_y] = { shortest_to_here = 0,
                                approx_shortest_via = d(start_x, start_y) }

  local to_explore = {{start_x, start_y}}

  while #to_explore > 0 do

    -- Find the to_explore member with minimum approx_shortest_via.
    local shortest   = math.huge
    local best_pt    = nil
    local best_index = nil
    for index, pt in pairs(to_explore) do
      local data = pt_data[pt[1]][pt[2]]
      if data.approx_shortest_via < shortest then
        shortest   = data.approx_shortest_via
        best_pt    = pt
        best_index = index
      end
    end
    table.remove(to_explore, best_index)

    -- Explore all nbors of best_pt.
    local best_pt_data = pt_data[best_pt[1]][best_pt[2]]
    for _, nbor in pairs(G[best_pt[1]][best_pt[2]]) do
      local nbor_data = pt_data[nbor[1]][nbor[2]]
      if best_pt_data.shortest_to_here + 1 < nbor_data.shortest_to_here then
        nbor_data.shortest_to_here = best_pt_data.shortest_to_here + 1
        nbor_data.approx_shortest_via =
            nbor_data.shortest_to_here + d(nbor[1], nbor[2])
        nbor_data.prev_pt_on_path = best_pt
        table.insert(to_explore, nbor)
      end
    end
  end

  -- Build the path itself.
  -- The format will be path = {x1, y1, x2, y2, ..., goalx, goaly}.
  local path = {}
  local pt = {x_len, 1}
  while pt ~= nil do
    table.insert(path, 1, pt[2])
    table.insert(path, 1, pt[1])
    local data = pt_data[pt[1]][pt[2]]
    pt = data.prev_pt_on_path
  end

  return path
end

function path_is_ok(x1, y1, x2, y2)

  local grid = {x1, y1}
  local p    = {x1 + 0.5, y1 + 0.5}
  local dir  = {x2 - x1, y2 - y1}

  local total_dist = 0  -- Measured in units of the dir vectors.
  local t = {}  -- Tracks incremental movement along the ray.
  local q = {}  -- Helps track potential next points.

  while true do

    -- Find the next_hit distance t for each coord i.
    for i = 1, 2 do
      t[i] = math.huge
      if dir[i] ~= 0 then
        --print('processing dir[' .. i .. ']')
        q[i] = next_hit(p[i], dir[i])
        t[i] = (q[i] - p[i]) / dir[i]
      end
    end

    -- min_set = { i : t[i] = min(t) }, as a key set.
    local min_set = {}
    local t_min = min(t)

    -- We're done if we've passed the destination point, which is distance 1
    -- away from the start point in units of the dir vector.
    total_dist = total_dist + t_min
    if total_dist > 1 then return true end

    for i = 1, 2 do
      -- We allow for 0.001 tolerance of machien precision error.
      if math.abs(t[i] - t_min) < 0.001 then min_set[i] = true end
    end

    -- Move p forward by distance t_min.
    for i = 1, 2 do
      p[i] = p[i] + t_min * dir[i]
    end

    -- Check for any collisions.
    for s in all_nonzero_subsets_in_order(min_set) do
      local h = {}
      for i = 1, 2 do
        -- s is a key set
        h[i] = grid[i] + (s[i] and 1 or 0) * sign(dir[i])
      end
      -- Is there a wall between grid and h?
      if maze[h[1]][h[2]] == 1 then return false end
    end

    -- Officially move the grid pt forward.
    for i = 1, 2 do
      grid[i] = grid[i] + (min_set[i] and 1 or 0) * sign(dir[i])
    end
  end

  assert(false, 'should not get out of while loop here')
end

function print_path(path)
  io.write('path: ')
  for i, coord in ipairs(path) do
    io.write(coord .. ' ')
    if i % 2 == 0 then io.write('  ') end
  end
  print('')  -- Ending newline.
end

-- This returns a list of x, y pairs starting at the given arguments and
-- ending at the goal point x_len, 1. This uses A* and then optimizes that path.
function find_path_via_short_cut_star(start_x, start_y)
  local path = find_path_via_A_star(start_x, start_y)

  -- Turn this on in the future to help debugging, if needed.
  if false then print_path(path) end

  -- Suppose the path contains the 3-point subpath A, B, C. Then we can go
  -- straight from A to C, skipping B, when the grid rectangle with corners at A
  -- and C has all possible edges in the graph G.
  local num_pts = #path / 2
  for i = 1, num_pts do
    while true do
      -- Check to see if we can go straight from pt i to pt i + 2.
      local j = i + 2
      if 2 * j > #path then break end
      if path_is_ok(path[2 * i - 1], path[2 * i],
                    path[2 * j - 1], path[2 * j]) then
        table.remove(path, 2 * (i + 1) - 1)
        table.remove(path, 2 * (i + 1) - 1)
      else
        break
      end
    end
  end
  return path
end

-- This returns a list of x, y pairs starting at the given arguments and
-- ending at the goal point x_len, 1.
function find_path(start_x, start_y)
  if mode == 'draw_path' then
    return find_path_via_A_star(start_x, start_y)
  else  -- Assume mode == 'short_path'.
    return find_path_via_short_cut_star(start_x, start_y)
  end
end

-- Entity class.

local Entity = {}

Entity.__index = Entity

function Entity:draw()
  love.graphics.setColor(100, 0, 120)
  draw_path(self.path)

  love.graphics.setColor(190, 0, 220)
  draw_dot(self.x, self.y, 7)
end

function Entity.new(x, y)
  local entity = {x = x, y = y}
  entity.path = find_path(x, y)
  return setmetatable(entity, Entity)
end


-- Love callbacks.

function love.load()
  win_w, win_h = love.graphics.getDimensions()
  love.graphics.setLineWidth(5)

  -- Set up the buttons.
  local  draw_path_button = Button.new( 10, 10, 'draw path mode')
  local short_path_button = Button.new(150, 10, 'short path mode')
  local  maze_edit_button = Button.new(290, 10, 'maze edit mode')
  buttons = {draw_path_button, short_path_button, maze_edit_button}
  highlight_button(draw_path_button)
  local mode_names = {'draw_path', 'short_path', 'maze_edit'}
  for i, b in pairs(buttons) do
    b.w = 130
    b.on_click = function ()
      mode = mode_names[i]
      highlight_button(b)
    end
  end

  -- Add the save maze button.
  local save_maze_button = Button.new(580, 10, 'save maze')
  save_maze_button.w = 120
  save_maze_button.on_click = save_maze

  maze_str = loadfile('maze.data')()

  -- Convert maze_str into a table of tables so that maze[x][y] is 0 or 1.
  -- 1 = a wall, 0 = no wall.
  maze = {}
  local x, y = 1, 1
  for line in maze_str:gmatch('[^\n]+') do
    if x_len == nil then
      x_len = #line
      for x = 0, x_len + 1 do maze[x] = {} end
    end
    x = 1
    for c in line:gmatch('.') do
      maze[x][y] = (c == '*' and 1 or 0)  -- Means c == '*' ? 1 : 0.
      x = x + 1
    end
    y = y + 1
  end
  y_len = #maze[1]

  -- Build the grid connectivity graph.
  build_G()

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
  clock = clock + dt
end

function love.draw()
  love.graphics.setColor(20, 180, 40)

  -- Draw a status msg if appropriate.
  if status_msg.till and clock < status_msg.till then
    love.graphics.setColor(255, 255, 255)
    love.graphics.print(status_msg.msg, status_msg.x, status_msg.y)
  end

  -- Draw the maze.
  local bkg_color  = { 40,  40,  40}
  local wall_color = {160, 180, 130}
  local colors = {[0] = bkg_color, [1] = wall_color}
  for y = 1, y_len do
    for x = 1, x_len do
      love.graphics.setColor(colors[maze[x][y]])
      draw_tile(x, y)
    end
  end

  -- Draw all the entities.
  for _, entity in pairs(entities) do
    entity:draw()
  end

  -- Draw the goal.
  love.graphics.setColor(0, 200, 0)
  draw_dot(x_len, 1, 10)

  for _, draw_fn in pairs(draw_fns) do
    draw_fn()
  end
end

function love.mousepressed(x, y, button)
  -- Call any hooked functions.
  for _, mousepress_fn in pairs(mousepressed_fns) do
    mousepress_fn(x, y, button)
  end

  x = math.floor(x / tile_size)
  y = math.floor((y - y_grid_offset) / tile_size)

  -- Bail if they clicked outside the grid.
  if x < 1 or x > x_len or y < 1 or y > y_len then return end

  if mode == 'maze_edit' then
    maze[x][y] = 1 - maze[x][y]
    G = {}
    build_G()
    return
  end

  if maze[x][y] == 0 then
    if do_allow_many_start_pts then
      table.insert(entities, Entity.new(x, y))
    else
      entities = {Entity.new(x, y)}
    end
  end
end

function love.mousemoved(x, y)
  for _, mousemove_fn in pairs(mousemoved_fns) do
    mousemove_fn(x, y)
  end
end
