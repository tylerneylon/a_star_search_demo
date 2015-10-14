-- main.lua


-- Internal globals.

local win_w, win_h


-- Love callbacks.

function love.load()
  win_w, win_h = love.graphics.getDimensions()
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
