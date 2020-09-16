local Player = Object:extend()

function Player:new(x, y)
    self.x = x
    self.y = y
end

function Player:update()
    self.x = self.x + rnd(2) - 1
    self.y = self.y + rnd(2) - 1
end

function Player:draw()
    spr(0, self.x, self.y)
end

-- START MAIN
local player

function _init()
    player = Player(60, 60)
end

function _update()
    player:update()
end

function _draw()
    cls()
    print('This is an empty project.')
    player:draw()
end
-- END MAIN
