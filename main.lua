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

function getDistance(x1, y1, x2, y2)
    local dx = (x1 - x2)/8
    local dy = (y1 - y2)/8
    return 8 * sqrt(
        dx * dx + dy * dy
    )
end

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


function FieldLine:new(x, y, width, height, isGoal, attackingTeam)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.isGoal = isGoal
    self.attackingTeam = attackingTeam
    bumpWorld:add(self, self.x, self.y, self.width, self.height)
end

Ball = Object:extend()
Ball.FRICTION = 0.98
Ball.PASS_SPEED = 2
Ball.SHOOT_SPEED = 4
Ball.SHOOT_TIMER_MAX = 60
Ball.SHOT_INVICIBILITY = 30

function Ball:new(x, y)
    self.x = x
    self.y = y
    self.velX = 0
    self.velY = 0
    self.controllingPlayer = nil
    self.shootTimer = 0
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

    if self.shootTimer > 0 then
        self.shootTimer = self.shootTimer - 1
    end
end

function Ball:isInvincible()
    -- Brief period while shooting where ball cannot be blocked.
    return (self.shootTimer < Ball.SHOT_INVICIBILITY and self.shootTimer > 0)
end

function Ball:move(x, y)
    self.x, self.y, collisions, _ = bumpWorld:move(self, x, y, self.moveFilter)
    for collision in all(collisions) do
        if collision.other:is(FieldLine) then
            if collision.other.isGoal and goalTimer == 0 then
                goalTimer = GOAL_TIMER_MAX
                collision.other.attackingTeam.goals = collision.other.attackingTeam.goals + 1
            elseif ballOutTimer == 0 then
                ballOutTimer = BALL_OUT_TIMER_MAX
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
        elseif collision.other:is(Player) and not self:isInvincible() and collision.other.ballLostTimer == 0 then
            collision.other.ballLostTimer = Player.BALL_LOST_TIMER_MAX
            self.controllingPlayer = collision.other
        end
    end
end

function Ball:setPosition(x, y)
    self.x = x
    self.y = y
    bumpWorld:update(self, self.x, self.y, 2, 2)
end

function Ball:pass(velX, velY)
    self.controllingPlayer = nil
    self.velX = Ball.PASS_SPEED * velX
    self.velY = Ball.PASS_SPEED * velY
end

function Ball:shoot(velX, velY)
    self.shootTimer = Ball.SHOOT_TIMER_MAX
    self.controllingPlayer = nil
    self.velX = Ball.SHOOT_SPEED * velX
    self.velY = Ball.SHOOT_SPEED * velY
end

function Ball:draw()
    circfill(self.x + 1, self.y + 1, 1.5, 7)
end

Player = Object:extend()
Player.DIRECTION_DATA = {
    N = { spriteIndex = 16, xFlip = false, velX = 0, velY = -1, ballXOffset = 2, ballYOffset = -3 },
    S = { spriteIndex = 0, xFlip = false, velX = 0, velY = 1, ballXOffset = 2, ballYOffset = 8 },
    E = { spriteIndex = 32, xFlip = true, velX = 1, velY = 0, ballXOffset = 8, ballYOffset = 0 },
    W = { spriteIndex = 32, xFlip = false, velX = -1, velY = 0, ballXOffset = -3, ballYOffset = 0 },
}
-- If player loses the ball, they can't reclaim it for a short period
-- prevents players trading the ball over and over.
Player.BALL_LOST_TIMER_MAX = 60

function Player:new(team, gridX, gridY, joypadId, isGoalkeeper)
    self.team = team
    self.gridX = gridX
    self.gridY = gridY
    self.joypadId = joypadId
    self.isGoalkeeper = isGoalkeeper
    
    self.ballLostTimer = 0
    self.width = 7
    self.height = 7

    if self.isGoalkeeper then
        -- TODO separate Goalkeeper class
        self.width = 11
        self.height = 11
        self.defendingHomeX = (FIELD_WIDTH * 8 - 8)/2
        if self.team.playingUp then
            self.defendingHomeY = FIELD_HEIGHT * 8 - 4
        else
            self.defendingHomeY = 4
        end
        self.attackingHomeX = self.defendingHomeX
        self.attackingHomeY = self.defendingHomeY
    else
        if self.team.playingUp then
            self.defendingHomeX = (5 - gridX) * 6 * 8 - 22
            self.defendingHomeY = (9 - gridY) * 6 * 8 - 22
            self.attackingHomeX = self.defendingHomeX
            self.attackingHomeY = self.defendingHomeY - 15 * 8
        else
            self.defendingHomeX = gridX * 6 * 8 - 22
            self.defendingHomeY = gridY * 6 * 8 - 22
            self.attackingHomeX = self.defendingHomeX
            self.attackingHomeY = self.defendingHomeY + 15 * 8
        end
    end
    self.x = self.defendingHomeX
    self.y = self.defendingHomeY
    self.isRunning = false
    self.direction = DIRECTIONS.S
    self.isDefending = true
    -- chosen by Team
    self.isChasingBall = false
    if team.playingUp then
        self.direction = DIRECTIONS.N
    end
    self.frame = 0

    bumpWorld:add(self, self.x, self.y, self.width, self.height)
end


function Player:moveFilter(other)
    if other:is(Wall) then
        return 'slide'
    end
    return 'cross'
end


function Player:findClosestPlayer(sameTeam, minAngle, maxAngle)
    if minAngle == nil then
        minAngle = 0
    end
    if maxAngle == nil then
        maxAngle = 1
    end

    local teamToCheck = nil
    if not sameTeam then
        for team in all(teams) do
            if team ~= self.team then
                teamToCheck = team
            end
        end
    else
        teamToCheck = self.team
    end

    local closestPlayer, distance = 0, 9999
    for player in all(teamToCheck.players) do
        -- local angleToPlayer = atan2(self.x - player.x, self.y - player.y)
        local playerDistance = getDistance(self.x, self.y, player.x, player.y)
        if self ~= player and playerDistance < distance then
            closestPlayer = player
            distance = playerDistance
        end
    end
    
    return closestPlayer, distance
end


function Player:updatePassive()
    local velX, velY = 0, 0
    local goalY = 0
    local goalX = FIELD_WIDTH * 8 / 2
    if not self.team.playingUp then
        goalY = FIELD_HEIGHT * 8
    end
    local distanceToGoal = getDistance(self.x, self.y, goalX, goalY)
    local angleToGoal = atan2(
        self.x - goalX,
        self.y - goalY
    )
    
    if self.isGoalkeeper then
        if ball.controllingPlayer == self then
            -- lump it clear
            ball:shoot(-cos(angleToGoal + rnd(0.4) - 0.2), -sin(angleToGoal + rnd(0.4) - 0.2))
        else
            velX = ball.x - self.x
        end
    else
        if ball.controllingPlayer == self then
            -- Check for shooting opportunity
            if distanceToGoal < 128 and rnd(distanceToGoal) > 16 then
                ball:shoot(-cos(angleToGoal + rnd(0.2) - 0.1), -sin(angleToGoal + rnd(0.2) - 0.1))
            else
                -- Check for pass
                local closestOpposingPlayer, distance = self:findClosestPlayer(
                    false
                )
                local angleToPlayer = atan2(
                    self.x - closestOpposingPlayer.x,
                    self.y - closestOpposingPlayer.y
                )
                if distance < 32 and ((angleToGoal - angleToPlayer + 0.5) % 1 - 0.5) < 0.2 then
                    -- get closed down, pass
                    local closestSameTeamPlayer, _ = self:findClosestPlayer(
                        true
                    )
                    local passAngle = atan2(
                        self.x - closestSameTeamPlayer.x,
                        self.y - closestSameTeamPlayer.y
                    ) + rnd(0.1) - 0.05
                    ball:pass(-cos(passAngle), -sin(passAngle))
                end
            end
            velY = -sin(angleToGoal)
            velX = -cos(angleToGoal)
        else
            -- Move towards defending or attacking position.
            if ball.controllingPlayer ~= nil then
                if ball.controllingPlayer.team == self.team then
                    self.isDefending = false
                else
                    self.isDefending = true
                end
            end
            
            local targetX, targetY = self.x, self.y
            local angleToBall = atan2(
                self.x - ball.x,
                self.y - ball.y
            )
            if self.isDefending then
                if self.isChasingBall then
                    -- Ball is close, go to ball!
                    targetX = ball.x
                    targetY = ball.y
                else
                    targetX = self.defendingHomeX - 16 * cos(angleToBall)
                    targetY = self.defendingHomeY - 16 * sin(angleToBall)
                end
            else
                if ball.controllingPlayer == nil and self.isChasingBall then
                    -- Ball is close, go to ball!
                    targetX = ball.x
                    targetY = ball.y
                else
                    targetX = self.attackingHomeX - 16 * cos(angleToBall)
                    targetY = self.attackingHomeY - 16 * sin(angleToBall)
                end
            end

            -- move() will scale this properly
            velX = targetX - self.x
            velY = targetY - self.y
        end
        self.isRunning = true
    end

    if abs(velX) > abs(velY) then
        if velX < 0 then
            self.direction = DIRECTIONS.W
        else
            self.direction = DIRECTIONS.E
        end
    else
        if velY < 0 then
            self.direction = DIRECTIONS.N
        else
            self.direction = DIRECTIONS.S
        end
    end

    self:move(velX, velY)
end

function Player:updateActive()
    self.isRunning = false
    local velX, velY = 0, 0
    local goalY = 0
    local goalX = FIELD_WIDTH * 8 / 2
    if not self.team.playingUp then
        goalY = FIELD_HEIGHT * 8
    end
    local angleToGoal = atan2(
        self.x - goalX,
        self.y - goalY
    )
    if btn(0, self.joypadId) then
        self.isRunning = true
        self.direction = DIRECTIONS.W
        velX = -1
    elseif btn(1, self.joypadId) then
        self.isRunning = true
        self.direction = DIRECTIONS.E
        velX = 1
    end
    if btn(2, self.joypadId) then
        self.isRunning = true
        self.direction = DIRECTIONS.N
        velY = -1
    elseif btn(3, self.joypadId) then
        self.isRunning = true
        self.direction = DIRECTIONS.S
        velY = 1
    end

    self:move(velX, velY)

    if ball.controllingPlayer == self then
        if velX == 0 and velY == 0 then
            velX = Player.DIRECTION_DATA[self.direction].velX
            velY = Player.DIRECTION_DATA[self.direction].velY
        end

        if btnp(4, self.joypadId) then
            ball:pass(velX, velY)
        elseif btnp(5, self.joypadId) then
            ball:shoot(-cos(angleToGoal + rnd(0.1) - 0.05), -sin(angleToGoal + rnd(0.1) - 0.05))
        end
    end
end


function Player:move(velX, velY)
    if self.ballLostTimer > 0 and ball.controllingPlayer ~= self then
        velX = 0
        velY = 0
    end

    local magnitude = 8 * sqrt(velX/8 * velX/8 + velY/8 * velY/8)
    if magnitude > 1 then
        velX = velX / magnitude
        velY = velY / magnitude
    end

    -- Players are marginally faster closer to their own goal.
    if ball.controllingPlayer == self then
        velX = velX * 0.8
        velY = velY * 0.8
    end

    local targetX, targetY = self.x + velX, self.y + velY
    if self.isGoalkeeper then
        if targetX < 8 * (FIELD_WIDTH - GOAL_WIDTH)/2 then
            targetX = 8 * (FIELD_WIDTH - GOAL_WIDTH)/2
        elseif targetX > 8 * (FIELD_WIDTH/2 + GOAL_WIDTH/2) - self.width then
            targetX = 8 * (FIELD_WIDTH/2 + GOAL_WIDTH/2) - self.width 
        end
    end

    self.x, self.y, collisions, _ = bumpWorld:move(self, targetX, targetY, self.moveFilter)
    for collision in all(collisions) do
        if collision.other:is(Ball) and not collision.other:isInvincible() and self.ballLostTimer == 0 then
            self.ballLostTimer = Player.BALL_LOST_TIMER_MAX
            collision.other.controllingPlayer = self
        end
    end

    if ball.controllingPlayer == self then
        local xOffset = Player.DIRECTION_DATA[self.direction].ballXOffset
        local yOffset = Player.DIRECTION_DATA[self.direction].ballYOffset
        ball:move(self.x + xOffset, self.y + yOffset)
    elseif self.ballLostTimer > 0 then
        self.ballLostTimer = self.ballLostTimer - 1
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
        self.x - 1,
        self.y - 3,
        1, 1,
        Player.DIRECTION_DATA[self.direction].xFlip
    )
end

Goalkeeper = Player:extend()

Goalkeeper.PALETTE = {
    -- Shirt
    [10] = 2,
    -- Shorts
    [12] = 0,
}

function Goalkeeper:draw()
    setPalette(Goalkeeper.PALETTE)
    spr(
        Player.DIRECTION_DATA[self.direction].spriteIndex + flr(self.frame / 4),
        self.x,
        self.y + 1,
        1, 1,
        Player.DIRECTION_DATA[self.direction].xFlip
    )
    setPalette(self.team.teamData.palette)
end

Team = Object:extend()

function Team:new(teamId, joypadId, playingUp)
    self.teamId = teamId
    self.teamData = TEAMS[teamId]
    self.playingUp = playingUp
    self.joypadId = joypadId
    self.players = {
        -- GK
        Goalkeeper(self, 1, 1, joypadId, true),
        -- Defence
        Player(self, 1, 2, joypadId, false),
        Player(self, 2, 1, joypadId, false),
        Player(self, 3, 1, joypadId, false),
        Player(self, 4, 2, joypadId, false),
        -- Midfield
        Player(self, 1, 4, joypadId, false),
        Player(self, 2, 2, joypadId, false),
        Player(self, 3, 3, joypadId, false),
        Player(self, 4, 4, joypadId, false),
        -- Forwards
        Player(self, 2, 5, joypadId, false),
        Player(self, 3, 5, joypadId, false),
    }
    self.selectedPlayerIndex = 1
    self.goals = 0
end

function Team:findPlayerClosestToBall(excludePlayerId)
    -- Find the player closest to the ball (for switching player control)
    -- *excluding* the currently controlled player; the user is switching,
    -- so they obviously don't want them.
    local closestPlayerIndex, distance = excludePlayerId, 9999
    for i, player in ipairs(self.players) do
        if i ~= excludePlayerId and not player.isGoalkeeper then
            local candidateDistance = getDistance(
                ball.x, ball.y,
                player.x, player.y
            )
            if candidateDistance < distance then
                closestPlayerIndex, distance = i, candidateDistance
            end
        end
    end
    return closestPlayerIndex
end

function Team:update()
    -- Switch players only if team doesn't currently have the ball
    if
        self.joypadId ~= nil and btnp(4, self.joypadId) and
        (ball.controllingPlayer == nil or ball.controllingPlayer.team ~= self)
    then
        self.selectedPlayerIndex = self:findPlayerClosestToBall(self.selectedPlayerIndex)
    end

    for i, player in ipairs(self.players) do
        if self.joypadId ~= nil and i == self.selectedPlayerIndex then
            player:updateActive()
        else
            player:updatePassive()
        end
        if ball.controllingPlayer == player then
            self.selectedPlayerIndex = i
        end
        player.isChasingBall = false
    end

    -- Set one player as the ball chaser if they're closest to the ball.
    self.players[self:findPlayerClosestToBall()].isChasingBall = true
end

Team.CURSOR_COLORS = { 8, 12 }
function Team:draw()
    setPalette(self.teamData.palette)
    for i, player in ipairs(self.players) do
        if self.joypadId ~= nil and i == self.selectedPlayerIndex then
            circ(player.x + 3, player.y + 4, 4, Team.CURSOR_COLORS[self.joypadId + 1])
        end
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
            8 * (FIELD_WIDTH + 2 * FIELD_BUFFER),
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
    -- stands
    -- north
    setPalette(teams[1].teamData.palette)
    map(0, 0, - 8 * (3 * FIELD_BUFFER), - 8 * FIELD_BUFFER - 8 * 8, 48, 8)
    map(48, 0, - 8 * FIELD_BUFFER - 8 * 8,  - 8 * FIELD_BUFFER, 8, 28)
    map(48, 0, 8 * (FIELD_WIDTH + FIELD_BUFFER),  - 8 * FIELD_BUFFER, 8, 28)
    -- south
    setPalette(teams[2].teamData.palette)
    map(0, 8, - 8 * (3 * FIELD_BUFFER), 8 * (FIELD_HEIGHT + FIELD_BUFFER), 48, 8)
    map(56, 0, - 8 * FIELD_BUFFER - 8 * 8, 8 * FIELD_HEIGHT/2, 8, 28)
    map(56, 0, 8 * (FIELD_WIDTH + FIELD_BUFFER), 8 * FIELD_HEIGHT/2, 8, 28)
    resetPalette()
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

GOAL_TIMER_MAX = 240
BALL_OUT_TIMER_MAX = 180
HALF_LENGTH = 120
GAME_TIME_SCALE = 45 * 60
HALF_TIME_TIMER_MAX = 300
function _init()
    bumpWorld = bump.newWorld(8)
    resetPalette()
    teams = {
        Team('GER', 0, false),
        Team('DEN', nil, true),
    }
    ball = Ball(FIELD_WIDTH * 8 /2, FIELD_HEIGHT * 8 /2)
    fieldLines = {
        FieldLine(0, 0, FIELD_WIDTH * 8, 1),
        FieldLine(0, 0, 1, FIELD_HEIGHT * 8),
        FieldLine(0, FIELD_HEIGHT * 8, FIELD_WIDTH * 8, 1),
        FieldLine(FIELD_WIDTH * 8, 0, 1, FIELD_HEIGHT * 8),
        -- Goal lines are slightly behind the field lines
        FieldLine(8 * (FIELD_WIDTH - GOAL_WIDTH)/2 + 2, -2, GOAL_WIDTH * 8 - 4, 1, true, teams[2]),
        FieldLine(8 * (FIELD_WIDTH - GOAL_WIDTH)/2 + 2, FIELD_HEIGHT * 8 + 2, GOAL_WIDTH * 8 - 4, 1, true, teams[1]),
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
    goalTimer = 0
    ballOutTimer = 0
    gameTimer = 0
    halfTimeTimer = 0
end

function _update60()
    if goalTimer == 0 and ballOutTimer == 0 and halfTimeTimer == 0 then
        for team in all(teams) do team:update() end
        gameTimer = gameTimer + 1
        if gameTimer == HALF_LENGTH * 60 then
            halfTimeTimer = HALF_TIME_TIMER_MAX
        end
    end

    if goalTimer > 0 then
        ballOutTimer = 0
        goalTimer = goalTimer - 1
        if goalTimer == 0 then
            ball:setPosition(FIELD_WIDTH * 8 /2, FIELD_HEIGHT * 8 /2)
        end
    end

    if ballOutTimer > 0 then
        ballOutTimer = ballOutTimer - 1
        if ballOutTimer == 0 then
            ball:setPosition(FIELD_WIDTH * 8 /2, FIELD_HEIGHT * 8 /2)
        end
    end

    if halfTimeTimer > 0 then
        halfTimeTimer = halfTimeTimer - 1
        if halfTimeTimer == 0 then
            ball:setPosition(FIELD_WIDTH * 8 /2, FIELD_HEIGHT * 8 /2)
        end
    end

    ball:update()
end

function _draw()
    cls()
    cameraTargetX, cameraTargetY = ball.x - 63, ball.y - 63
    if ball.controllingPlayer then
        cameraTargetX, cameraTargetY = ball.controllingPlayer.x - 61, ball.controllingPlayer.y - 61
    end
    if not cameraX or not cameraY then
        cameraX, cameraY = cameraTargetX, cameraTargetY
    else
        cameraX = cameraX + (cameraTargetX - cameraX)/8
        cameraY = cameraY + (cameraTargetY - cameraY)/8
    end
    camera(cameraX, cameraY)
    drawField()
    drawTopGoal()
    ball:draw()
    for team in all(teams) do team:draw() end
    drawBottomGoal()
    camera()
    for i, team in ipairs(teams) do
        print(team.teamId.." "..tostr(team.goals), 8, i * 8 + 1, 0)
        print(team.teamId.." "..tostr(team.goals), 8, i * 8, 7)
    end
    local scaledGameTimer = (gameTimer / (60 * HALF_LENGTH)) * GAME_TIME_SCALE
    local mins = tostr(flr(scaledGameTimer / 60))
    local secs = tostr(flr(scaledGameTimer % 60))
    if #mins < 2 then
        mins = '0'..mins
    end
    if #secs < 2 then
        secs = '0'..secs
    end
    print(mins..':'..secs, 8, 25, 0)
    print(mins..':'..secs, 8, 24, 7)
    if goalTimer > 0 then
        print('goal!', 54, 60, flr(rnd(16)))
    end

    if halfTimeTimer > 0 then
        fillp('0b0101101001011010.1')
        rectfill(0, 0, 127, 127, 0)
        fillp()
        print('half time', 46, 60, 7)
    end
end
-- END MAIN
