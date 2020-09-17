TEAMS = {
    SWE = {
        palette = {
            -- Shirt
            [10] = 10,
            -- Shorts
            [12] = 12,
        },
    },
    GER = {
        palette = {
            -- Shirt
            [10] = 7,
            -- Shorts
            [12] = 0,
        },
    },
    DEN = {
        palette = {
            -- Shirt
            [10] = 8,
            -- Shorts
            [12] = 7,
        },
    },
    NED = {
        palette = {
            -- Shirt
            [10] = 9,
            -- Shorts
            [12] = 7,
        },
    },
    SCO = {
        palette = {
            -- Shirt
            [10] = 1,
            -- Shorts
            [12] = 7,
        },
    },
    ENG = {
        palette = {
            -- Shirt
            [10] = 7,
            -- Shorts
            [12] = 1,
        },
    },
    FRA = {
        palette = {
            -- Shirt
            [10] = 12,
            -- Shorts
            [12] = 7,
        },
    },
    CIS = {
        palette = {
            -- Shirt
            [10] = 8,
            -- Shorts
            [12] = 7,
        },
    },
}

DIRECTIONS = {
    S = 'S',
    N = 'N',
    E = 'E',
    W = 'W',
}

-- Dimensions in tiles
FIELD_BUFFER = 4
FIELD_WIDTH = 24
FIELD_HEIGHT = 48

function setPalette(palette)
    for original, replacement in pairs(palette) do
        pal(original, replacement)
    end
end

function resetPalette()
    pal()
    palt(0, false)
    palt(14, true)
end

Wall = Object:extend()


function Wall:new(x, y, width, height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    bumpWorld:add(self, self.x, self.y, self.width, self.height)
end

GoalWall = Wall:extend()


FieldLine = Object:extend()


function FieldLine:new(x, y, width, height, isGoal)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.isGoal = isGoal
    bumpWorld:add(self, self.x, self.y, self.width, self.height)
end

Ball = Object:extend()
Ball.FRICTION = 0.98
Ball.PASS_SPEED = 2
Ball.SHOOT_SPEED = 4

function Ball:new(x, y)
    self.x = x
    self.y = y
    self.velX = 0
    self.velY = 0
    self.controllingPlayer = nil
    bumpWorld:add(self, self.x, self.y, 2, 2)
end

function Ball:moveFilter(other)
    if other:is(Wall) then
        return 'slide'
    end
    return 'cross'
end

function Ball:update()
    if self.controllingPlayer then
        self.velX = 0
        self.velY = 0
    end
    self.velX = self.velX * Ball.FRICTION
    self.velY = self.velY * Ball.FRICTION

    self.x = self.x + self.velX
    self.y = self.y + self.velY
    self:move(self.x, self.y)
end

function Ball:move(x, y)
    self.x, self.y, collisions, _ = bumpWorld:move(self, x, y, self.moveFilter)
    for collision in all(collisions) do
        if collision.other:is(FieldLine) then
            if collision.other.isGoal then
                -- TODO goal!
            else
                -- TODO thrown in
            end
        elseif collision.other:is(Wall) then
            local elasticity = -1
            if collision.other:is(GoalWall) then
                elasticity = -0.25
            end
            if collision.normal.x ~= 0 then
                self.velX = self.velX * elasticity
            elseif collision.normal.y ~= 0 then
                self.velY = self.velY * elasticity
            end
        elseif collision.other:is(Player) then
            -- TODO this is duplicated between Ball and Player; ideally we'd only need one.
            self.controllingPlayer = collision.other
        end
    end
end

function Ball:pass(velX, velY)
    self.controllingPlayer = nil
    self.velX = Ball.PASS_SPEED * velX
    self.velY = Ball.PASS_SPEED * velY
end

function Ball:shoot(velX, velY)
    self.controllingPlayer = nil
    self.velX = Ball.SHOOT_SPEED * velX
    self.velY = Ball.SHOOT_SPEED * velY
end

function Ball:draw()
    circfill(self.x + 1, self.y + 1, 1, 7)
end

Player = Object:extend()
Player.DIRECTION_DATA = {
    N = { spriteIndex = 16, xFlip = false, angle = 0.25, ballXOffset = 0, ballYOffset = -3 },
    S = { spriteIndex = 0, xFlip = false, angle = 0.75, ballXOffset = 0, ballYOffset = 6 },
    E = { spriteIndex = 32, xFlip = true, angle = 0, ballXOffset = 6, ballYOffset = 0 },
    W = { spriteIndex = 32, xFlip = false, angle = 0.5, ballXOffset = -3, ballYOffset = 0 },
}

function Player:new(team, gridX, gridY, isGoalkeeper)
    self.gridX = gridX
    self.gridY = gridY
    self.isGoalkeeper = isGoalkeeper
    if self.isGoalkeeper then
        -- TODO goalkeeper in goal
        self.x = 32
        self.y = 32
    else
        self.x = gridX * 6 * 8 - 22
        self.y = gridY * 6 * 8 - 22
    end
    self.isRunning = false
    self.direction = DIRECTIONS.S
    self.frame = 0
    printh(self.x)
    printh(self.y)
    bumpWorld:add(self, self.x, self.y, 5, 5)
end

function Player:updatePassive()
    --
end

function Player:moveFilter(other)
    if other:is(Wall) then
        return 'slide'
    end
    return 'cross'
end

function Player:updateActive()
    -- TODO ball doesn't move if kicked while standing still
    self.isRunning = false
    local velX, velY = 0, 0
    if btn(0) then
        self.isRunning = true
        self.direction = DIRECTIONS.W
        velX = -1
    elseif btn(1) then
        self.isRunning = true
        self.direction = DIRECTIONS.E
        velX = 1
    end
    if btn(2) then
        self.isRunning = true
        self.direction = DIRECTIONS.N
        velY = -1
    elseif btn(3) then
        self.isRunning = true
        self.direction = DIRECTIONS.S
        velY = 1
    end

    local magnitude = sqrt(velX * velX + velY * velY)
    if magnitude > 1 then
        velX = velX / magnitude
        velY = velY / magnitude
    end

    self.x, self.y, collisions, _ = bumpWorld:move(self, self.x + velX, self.y + velY, self.moveFilter)
    for collision in all(collisions) do
        if collision.other:is(Ball) then
            collision.other.controllingPlayer = self
        end
    end

    if ball.controllingPlayer == self then
        if btnp(4) then
            ball:pass(velX, velY)
        elseif btnp(5) then
            ball:shoot(velX, velY)
        else
            local xOffset = Player.DIRECTION_DATA[self.direction].ballXOffset
            local yOffset = Player.DIRECTION_DATA[self.direction].ballYOffset
            ball:move(self.x + xOffset, self.y + yOffset)
        end
    end

    if self.isRunning then
        self.frame = self.frame + 1
    else
        self.frame = 0
    end
    self.frame = self.frame % 16
end

function Player:draw()
    spr(
        Player.DIRECTION_DATA[self.direction].spriteIndex + flr(self.frame / 4),
        self.x - 2,
        self.y - 3,
        1, 1,
        Player.DIRECTION_DATA[self.direction].xFlip
    )
end

Team = Object:extend()

function Team:new(teamId)
    self.teamData = TEAMS[teamId]
    self.players = {
        Player(self, 2, 1, false),
        Player(self, 4, 1, false),
    }
    self.selectedPlayerIndex = 1
end

function Team:update()
    for i, player in ipairs(self.players) do
        if i == self.selectedPlayerIndex then
            player:updateActive()
        else
            player:updatePassive()
        end
        if ball.controllingPlayer == player then
            self.selectedPlayerIndex = i
        end
    end
end

function Team:draw()
    setPalette(self.teamData.palette)
    for player in all(self.players) do
        player:draw()
    end
    resetPalette()
end

-- START MAIN

FIELD_COLORS = { 3, 11 }
FIELD_STRIPE_HEIGHT = 2
WIDTH_18_YARD = 12
HEIGHT_18_YARD = 6
WIDTH_6_YARD = 6
HEIGHT_6_YARD = 2
GOAL_WIDTH = 4
function drawField()
    for y = -FIELD_BUFFER, FIELD_HEIGHT + FIELD_BUFFER - 1, FIELD_STRIPE_HEIGHT do
        rectfill(
            -FIELD_BUFFER * 8,
            y * 8,
            8 * (FIELD_WIDTH + FIELD_BUFFER - 1),
            (y + FIELD_STRIPE_HEIGHT) * 8 - 1,
            FIELD_COLORS[flr(y/2) % 2 + 1]
        )
    end
    rect(0, 0, FIELD_WIDTH * 8 - 1, FIELD_HEIGHT * 8 - 1, 7)
    -- 18 yards
    local x18Yards = (FIELD_WIDTH - WIDTH_18_YARD)/2
    rect(
        x18Yards * 8,
        0,
        (x18Yards + WIDTH_18_YARD) * 8 - 1,
        8 * HEIGHT_18_YARD - 1,
        7
    )
    rect(
        x18Yards * 8,
        (FIELD_HEIGHT - HEIGHT_18_YARD) * 8,
        (x18Yards + WIDTH_18_YARD) * 8 - 1,
        FIELD_HEIGHT * 8 - 1,
        7
    )
    -- 6 yards
    local x6Yards = (FIELD_WIDTH - WIDTH_6_YARD)/2
    rect(
        x6Yards * 8,
        0,
        (x6Yards + WIDTH_6_YARD) * 8 - 1,
        8 * HEIGHT_6_YARD - 1,
        7
    )
    rect(
        x6Yards * 8,
        (FIELD_HEIGHT - HEIGHT_6_YARD) * 8,
        (x6Yards + WIDTH_6_YARD) * 8 - 1,
        FIELD_HEIGHT * 8 - 1,
        7
    )
    -- penalty spots
    local xPenalty = (FIELD_WIDTH * 8 - 2)/2
    rect(
        xPenalty,
        32,
        xPenalty + 2,
        33,
        7
    )
    rect(
        xPenalty,
        FIELD_HEIGHT * 8 - 32,
        xPenalty + 2,
        FIELD_HEIGHT * 8 - 31,
        7
    )
    -- Ds
    clip(0, HEIGHT_18_YARD * 8 - cameraY, 128, (FIELD_HEIGHT - HEIGHT_18_YARD * 2) * 8)
    circ(FIELD_WIDTH * 8 / 2, 0, 7 * 8, 7)
    circ(FIELD_WIDTH * 8 / 2, FIELD_HEIGHT * 8, 7 * 8, 7)
    clip()
    -- halfway line
    line(0, FIELD_HEIGHT * 8 / 2, FIELD_WIDTH * 8 - 1, FIELD_HEIGHT * 8 / 2, 7)
    circ(FIELD_WIDTH * 8 / 2, FIELD_HEIGHT * 8 / 2, 32, 7)
end

function drawTopGoal()
    -- goals
    local goalX = (FIELD_WIDTH - GOAL_WIDTH)/2
    rect(goalX * 8, -12, (goalX + GOAL_WIDTH) * 8 - 1, 0, 7)
    fillp('0b0101101001011010.1')
    rectfill(goalX * 8, -20, (goalX + GOAL_WIDTH) * 8 - 1, -13, 5)
    fillp()
end

function drawBottomGoal()
    -- goals
    local goalX = (FIELD_WIDTH - GOAL_WIDTH)/2
    rect(goalX * 8, FIELD_HEIGHT * 8 - 12, (goalX + GOAL_WIDTH) * 8 - 1, FIELD_HEIGHT * 8, 7)
    fillp('0b0101101001011010.1')
    rectfill(goalX * 8, FIELD_HEIGHT * 8 - 12, (goalX + GOAL_WIDTH) * 8 - 1, FIELD_HEIGHT * 8 + 7, 5)
    fillp()
end

function _init()
    bumpWorld = bump.newWorld(8)
    resetPalette()
    team = Team('SCO')
    ball = Ball(32, 32)
    fieldLines = {
        FieldLine(0, 0, FIELD_WIDTH * 8, 1),
        FieldLine(0, 0, 1, FIELD_HEIGHT * 8),
        FieldLine(0, FIELD_HEIGHT * 8, FIELD_WIDTH * 8, 1),
        FieldLine(FIELD_WIDTH * 8, 0, 1, FIELD_HEIGHT * 8),
        FieldLine(8 * (FIELD_WIDTH - GOAL_WIDTH)/2, 0, GOAL_WIDTH * 8, 1, true),
        FieldLine(8 * (FIELD_WIDTH - GOAL_WIDTH)/2, FIELD_HEIGHT * 8, GOAL_WIDTH * 8, 1, true),
    }
    perimeterWalls = {
        Wall(-FIELD_BUFFER * 8 - 8, -FIELD_BUFFER * 8 - 8, (FIELD_WIDTH + FIELD_BUFFER * 2) * 8, 8),
        Wall(-FIELD_BUFFER * 8 - 8, -FIELD_BUFFER * 8 - 8, 8, (FIELD_HEIGHT + FIELD_BUFFER * 2) * 8),
        Wall((FIELD_WIDTH + FIELD_BUFFER) * 8, -FIELD_BUFFER * 8 - 8, 8, (FIELD_HEIGHT + FIELD_BUFFER * 2) * 8),
        Wall(-FIELD_BUFFER * 8 - 8, (FIELD_HEIGHT + FIELD_BUFFER) * 8, (FIELD_WIDTH + FIELD_BUFFER * 2) * 8, 8),
        GoalWall(8 * (FIELD_WIDTH - GOAL_WIDTH)/2, -20, GOAL_WIDTH * 8, 1),
        GoalWall(8 * (FIELD_WIDTH - GOAL_WIDTH)/2, FIELD_HEIGHT * 8 + 8, GOAL_WIDTH * 8, 1),
        --Side walls
        GoalWall(8 * (FIELD_WIDTH - GOAL_WIDTH)/2, -20, 1, 20),
        GoalWall(8 * (FIELD_WIDTH - GOAL_WIDTH)/2, FIELD_HEIGHT * 8, 1, 8),
        GoalWall(8 * (GOAL_WIDTH + (FIELD_WIDTH - GOAL_WIDTH)/2), -20, 1, 20),
        GoalWall(8 * (GOAL_WIDTH + (FIELD_WIDTH - GOAL_WIDTH)/2), FIELD_HEIGHT * 8, 1, 8),
    }
end

function _update60()
    team:update()
    ball:update()
end

function _draw()
    cls()
    cameraX, cameraY = ball.x - 63, ball.y - 63
    if ball.controllingPlayer then
        cameraX, cameraY = ball.controllingPlayer.x - 61, ball.controllingPlayer.y - 61
    end
    camera(cameraX, cameraY)
    drawField()
    drawTopGoal()
    ball:draw()
    team:draw()
    drawBottomGoal()
end
-- END MAIN
