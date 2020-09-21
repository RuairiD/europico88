STATES = {
    MAIN_MENU = 'MAIN_MENU',
    GAME = 'GAME',
}

TEAMS = {
    URS = {
        palette = split("8, 7, 7, 8"),
        flags = split("80, 96"),
    },
    FRG = {
        palette = split("7, 0, 3, 7"),
        flags = split("83, 128"),
    },
    DEN = {
        palette = split("8, 7, 7, 8"),
        flags = split("81, 99"),
    },
    NED = {
        palette = split("9, 7, 7, 9"),
        flags = split("82, 102"),
        skinSwap = split("3, 10"),
    },
    IRL = {
        palette = split("3, 7, 7, 3"),
        flags = split("85, 134"),
        skinSwap = split("5, 8")
    },
    ENG = {
        palette = split("7, 1, 8, 7"),
        flags = split("87, 163"),
        skinSwap = split("9"),
    },
    ITA = {
        palette = split("12, 7, 7, 12"),
        flags = split("84, 131"),
    },
    ESP = {
        palette = split("8, 1, 12, 7"),
        flags = split("86, 160"),
    },
}

DIRECTIONS = {
    S = 'S',
    N = 'N',
    E = 'E',
    W = 'W',
}

-- Field dimensions
-- FIELD_BUFFER = 4
-- FIELD_WIDTH = 24
-- FIELD_HEIGHT = 48

function printShadowCentre(text, y, color)
    printShadow(text, (128 - #text * 4)/2, y, color)
end

function printShadow(text, x, y, color)
    if not color then
        color = 7
    end
    print(text, x, y + 1, 0)
    print(text, x, y, color)
end

function getDistance(x1, y1, x2, y2)
    local dx = (x1 - x2)/8
    local dy = (y1 - y2)/8
    return 8 * sqrt(
        dx * dx + dy * dy
    )
end

KIT_PALETTE = { 10, 12 }
SKIN_SWAP_PALETTE = { [15] = 4, [4] = 0 }
function setPalette(palette, offset, isAway, skinSwap)
    if not offset then
        offset = 0
    end
    fixedOffset = 0
    if isAway then
        fixedOffset = 2
    end
    
    for i, original in ipairs(KIT_PALETTE) do
        pal(
            original,
            palette[fixedOffset + (i + offset - 1) % 2 + 1]
        )
    end

    if skinSwap then
        for original, replacement in pairs(SKIN_SWAP_PALETTE) do
            pal(
                original,
                replacement
            )
        end
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
Ball.SHOOT_SPEED = 5
Ball.SHOOT_TIMER_MAX = 60
Ball.SHOT_INVICIBILITY = 30

function Ball:new(x, y)
    self.x = x
    self.y = y
    self.velX = 0
    self.velY = 0
    self.controllingPlayer = nil
    self.lastControllingPlayer = nil
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
        self.lastControllingPlayer = self.controllingPlayer
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

function Ball:move(x, y)
    self.x, self.y, collisions, _ = bumpWorld:move(self, x, y, self.moveFilter)
    for collision in all(collisions) do
        if collision.other:is(FieldLine) and ballOutTimer == 0 and goalTimer == 0 then
            if collision.other.isGoal then
                goalTimer = GOAL_TIMER_MAX
                collision.other.attackingTeam.goals = collision.other.attackingTeam.goals + 1
                goalScoringTeam = collision.other.attackingTeam
                isFreeKick = false
                isKickOff = true
                setKickOffTeam(collision.other.attackingTeam)
                music(2)
            else
                ballOutTimer = BALL_OUT_TIMER_MAX
                isFreeKick = true
                setKickOffTeam(self.lastControllingPlayer.team)
                local x, y
                if collision.other.attackingTeam then
                    -- Corner or goal kick
                    if collision.other.attackingTeam == kickOffTeam then
                        -- corner
                        if collision.touch.x < 96 then
                            x = 8
                        else
                            x = 185
                        end
                        if collision.touch.y < 192 then
                            y = 8
                        else
                            y = 377
                        end
                    else
                        -- goal kick
                        -- hacky way to check which end ball is at
                        x = 96
                        if collision.touch.y < 16 then
                            y = 16
                        else
                            y = 368
                        end
                    end
                    ballOutReset = (function()
                        ball:setPosition(x, y)
                    end)
                else
                    -- Kick in
                    x, y = collision.touch.x, collision.touch.y
                    if x < 96 then
                        x = x + 8
                    else
                        x = x - 8
                    end
                    ballOutReset = (function()
                        ball:setPosition(x, y)
                    end)
                end
            end
        elseif collision.other:is(Wall) then
            local elasticity = -1
            if collision.other:is(GoalWall) then
                elasticity = -0.25
            else
                sfx(5)
            end
            if collision.normal.x ~= 0 then
                self.velX = self.velX * elasticity
            elseif collision.normal.y ~= 0 then
                self.velY = self.velY * elasticity
            end
        elseif
            collision.other:is(Player) and
            collision.other:canTakeBall(self)
        then
            collision.other:takeBall(self)
        end
    end
end

function Ball:getSpeed()
    return sqrt(self.velX * self.velX + self.velY * self.velY)
end

function Ball:setPosition(x, y)
    self.x = x
    self.y = y
    bumpWorld:update(self, self.x, self.y, 2, 2)
    self.controllingPlayer = nil
end

function Ball:pass(velX, velY)
    self.controllingPlayer.ballLostTimer = Player.BALL_LOST_BY_KICKING_TIMER_MAX 
    self.controllingPlayer = nil
    local scale = (0.9 + rnd(0.2))
    self.velX = scale * Ball.PASS_SPEED * velX
    self.velY = scale * Ball.PASS_SPEED * velY
    isFreeKick = false
    isKickOff = false
    sfx(3)
end

function Ball:shoot(velX, velY)
    self.controllingPlayer.ballLostTimer = Player.BALL_LOST_BY_KICKING_TIMER_MAX 
    self.shootTimer = Ball.SHOOT_TIMER_MAX
    self.controllingPlayer = nil
    local scale = (0.8 + rnd(0.4))
    self.velX = scale * Ball.SHOOT_SPEED * velX 
    self.velY = scale * Ball.SHOOT_SPEED * velY
    isFreeKick = false
    isKickOff = false
    sfx(4)
end

function Ball:draw()
    spr(58, self.x - 1, self.y - 1)
end

Player = Object:extend()
Player.DIRECTION_DATA = {
    N = { spriteIndex = 16, xFlip = false, velX = 0, velY = -1, ballXOffset = 2, ballYOffset = -2 },
    S = { spriteIndex = 0, xFlip = false, velX = 0, velY = 1, ballXOffset = 2, ballYOffset = 7 },
    E = { spriteIndex = 32, xFlip = true, velX = 1, velY = 0, ballXOffset = 7, ballYOffset = 0 },
    W = { spriteIndex = 32, xFlip = false, velX = -1, velY = 0, ballXOffset = -2, ballYOffset = 0 },
}
-- If player loses the ball by tackle, they can't reclaim it for a short period.
-- Prevents players trading the ball over and over.
Player.BALL_LOST_TIMER_MAX = 60
Player.BALL_LOST_BY_KICKING_TIMER_MAX = 20
-- Computer will delay after receiving ball before attempting a pass or shot.
Player.BALL_RECEIVED_TIMER_MAX = 30

function Player:new(team, gridX, gridY, joypadId, isGoalkeeper)
    self.team = team
    self.gridX = gridX
    self.gridY = gridY
    self.joypadId = joypadId
    self.isGoalkeeper = isGoalkeeper
    
    self.ballLostTimer = 0
    self.ballReceivedTimer = 0
    self.width = 7
    self.height = 7
    bumpWorld:add(self, 0, 0, self.width, self.height)

    self.isRunning = false
    self.direction = DIRECTIONS.S
    self.isDefending = true
    -- chosen by Team
    self.isChasingBall = false
    if team.playingUp then
        self.direction = DIRECTIONS.N
    end
    self.frame = 0

end

function Player:resetPosition(isKickOff, targetX, targetY)
    if self.isGoalkeeper then
        -- TODO separate Goalkeeper class
        self.width = 9
        self.height = 9
        self.defendingHomeX = 92
        if self.team.playingUp then
            self.defendingHomeY = 376
        else
            self.defendingHomeY = 0
        end
        self.attackingHomeX = self.defendingHomeX
        self.attackingHomeY = self.defendingHomeY
    else
        if self.team.playingUp then
            self.defendingHomeX = (5 - self.gridX) * 48 - 24
            self.defendingHomeY = (9 - self.gridY) * 48 - 24
            self.attackingHomeX = self.defendingHomeX
            self.attackingHomeY = self.defendingHomeY - 12 * 8
        else
            self.defendingHomeX = self.gridX * 48 - 24
            self.defendingHomeY = self.gridY * 48 - 24
            self.attackingHomeX = self.defendingHomeX
            self.attackingHomeY = self.defendingHomeY + 12 * 8
        end
    end
    self:updateIsDefending()
    local x, y
    if self.isDefending then
        x, y = self.defendingHomeX, self.defendingHomeY
    else
        x, y = self.attackingHomeX, self.attackingHomeY
    end
    if self.team == kickOffTeam and not self.isGoalkeeper and targetX and targetY then
        local angle = atan2(x - targetX, y - targetY)
        x = x - 16 * cos(angle)
        y = y - 16 * sin(angle)
    end

    local halfway = 192
    if isKickOff then
        if self.team.playingUp and y < halfway then
            y = halfway + 16
        elseif not self.team.playingUp and y > halfway then
            y = halfway - 16
        end
    end
    self:setPosition(x, y)
end

function Player:setPosition(x, y)
    self.x = x
    self.y = y
    bumpWorld:update(self, self.x, self.y, self.width, self.height)
end

function Player:moveFilter(other)
    if other:is(Wall) then
        return 'slide'
    elseif other:is(Player) then
        return nil
    end
    return 'cross'
end


function Player:findClosestPlayer(sameTeam, weightFunction)
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
        -- A weighting function can be used to apply some kind of bias e.g.
        -- prefer players further up the field or within a better angle.
        if weightFunction then
            weightFunction(playerDistance, player)
        end
        if self ~= player and playerDistance < distance then
            closestPlayer = player
            distance = playerDistance
        end
    end
    
    return closestPlayer, distance
end


function Player:updateIsDefending()
    if ball and ball.controllingPlayer ~= nil then
        if ball.controllingPlayer.team == self.team then
            self.isDefending = false
        else
            self.isDefending = true
        end
    end
end


function Player:updatePassive()
    local velX, velY = 0, 0
    local centreX, centreY = self.x + 2, self.y + 2
    local goalY = 0
    local goalX = 96
    if not self.team.playingUp then
        goalY = 48 * 8
    end
    local distanceToGoal = getDistance(centreX, centreY + 2, goalX, goalY)
    local angleToGoal = atan2(
        centreX - goalX,
        centreY - goalY
    )
    
    if goalTimer == 0 then
        if self.isGoalkeeper then
            if ball.controllingPlayer == self then
                -- lump it clear
                ball:shoot(-cos(angleToGoal + rnd(0.3) - 0.15), -sin(angleToGoal + rnd(0.3) - 0.15))
            else
                velX = ball.x - (self.x + 2)
            end
        else
            if ball.controllingPlayer == self then
                -- Check for shooting opportunity
                -- Less concerned about rapid passes here, so ballReceivedTimer is ignored
                local closestSameTeamPlayer, distance = self:findClosestPlayer(
                    true,
                    -- Prefer players closer to goal
                    (function (distance, player)
                        return distance * 0.1 * abs(player.y - goalY)
                    end)
                )
                local passAngle = atan2(
                    centreX - closestSameTeamPlayer.x,
                    centreY - closestSameTeamPlayer.y
                ) + rnd(0.1) - 0.05

                if isFreeKick or isKickOff then
                    -- Add some random delay to kick being taken
                    -- so computer doesn't take it straight away.
                    if kickOffDelay == 0 then
                        if distance < 48 then
                            ball:pass(-cos(passAngle), -sin(passAngle))
                        else
                            ball:shoot(-cos(angleToGoal + rnd(0.1) - 0.05), -sin(angleToGoal + rnd(0.1) - 0.05))
                        end
                    end
                elseif rnd(distanceToGoal) < 0.5 then
                    -- Computer shots are less accurate than player shots for balance
                    ball:shoot(-cos(angleToGoal + rnd(0.15) - 0.075), -sin(angleToGoal + rnd(0.15) - 0.075))
                else
                    -- Check for pass
                    local closestOpposingPlayer, distance = self:findClosestPlayer(
                        false
                    )
                    local angleToPlayer = atan2(
                        centreX - closestOpposingPlayer.x,
                        centreY - closestOpposingPlayer.y
                    )
                    if
                        distance < 32 and (rnd() > 0.7 or abs((angleToGoal - angleToPlayer + 0.5) % 1 - 0.5) < 0.2)
                    then
                        -- If player is being closed down, either clear the ball (if far from
                        -- goal), shoot (if close to goal) or attempt to pass it to a teammate.
                        if distanceToGoal > 256 or distanceToGoal < 64 then
                            -- Wild shot/clearance
                            ball:shoot(-cos(angleToGoal + rnd(0.3) - 0.15), -sin(angleToGoal + rnd(0.3) - 0.15))
                        elseif self.ballReceivedTimer == 0 then
                            ball:pass(-cos(passAngle), -sin(passAngle))
                        end
                    end
                end
                velY = -sin(angleToGoal)
                velX = -cos(angleToGoal)
            else
                -- Move towards defending or attacking position.
                self:updateIsDefending()
                
                local targetX, targetY = self.x, self.y
                local angleToBall = atan2(
                    centreX - ball.x,
                    centreY - ball.y
                )
                if self.isDefending then
                    targetX = self.defendingHomeX - 16 * cos(angleToBall)
                    targetY = self.defendingHomeY - 16 * sin(angleToBall)
                    if self.isChasingBall then
                        -- Ball is close, go to ball!
                        targetX = ball.x
                        targetY = ball.y
                    end
                else
                    targetX = self.attackingHomeX - 16 * cos(angleToBall)
                    targetY = self.attackingHomeY - 16 * sin(angleToBall)
                    if ball.controllingPlayer == nil and self.isChasingBall then
                        -- Ball is close, go to ball!
                        targetX = ball.x
                        targetY = ball.y
                    end
                end

                -- move() will scale this properly
                velX = targetX - centreX
                velY = targetY - centreY
            end
            self.isRunning = true
        end
    else
        -- Goal scored. Run towards scorer!
        self.isRunning = false
        if goalScoringTeam == self.team then
            if ball.lastControllingPlayer ~= self then
                velX = (ball.lastControllingPlayer.x + rnd(16) - 8) - self.x
                velY = (ball.lastControllingPlayer.y + rnd(16) - 8) - self.y
                self.isRunning = true
            else
                -- Run to nearest corner!
                local targetX = 0
                local targetY = 0
                if self.x > 96 then
                    targetX = 192
                end
                if self.y > 192 then
                    targetY = 384
                end
                velX = targetX - self.x
                velY = targetY - self.y
                self.isRunning = true
            end
        end
    end

    if self.isGoalkeeper then
        if self.team.playingUp then
            self.direction = DIRECTIONS.N
        else
            self.direction = DIRECTIONS.S
        end
    elseif abs(velX) > abs(velY) then
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
    local goalX = 96
    if not self.team.playingUp then
        goalY = 384
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
    if
        isFreeKick or (isKickOff and goalTimer == 0) or
        (self.ballLostTimer > Player.BALL_LOST_TIMER_MAX/2 and ball.controllingPlayer ~= self)
    then
        velX = 0
        velY = 0
    end

    local magnitude = 8 * sqrt(velX/8 * velX/8 + velY/8 * velY/8)
    if magnitude > 1 then
        velX = velX / magnitude
        velY = velY / magnitude
    end

    -- Players are marginally slower with the ball.
    if ball.controllingPlayer == self then
        velX = velX * 0.9
        velY = velY * 0.9
    end

    -- Goalkeepers move slightly slower so they're less superhuman
    if isGoalkeeper then
        velX = velX * 0.8
        velY = velY * 0.8
    end

    -- Move slowly after losing the ball
    if self.ballLostTimer > 0 and self.ballLostTimer <= Player.BALL_LOST_TIMER_MAX/2 then
        velX = velX * 0.5
        velY = velY * 0.5
    end

    local targetX, targetY = self.x + velX, self.y + velY
    if self.isGoalkeeper then
        if targetX < 8 * (24 - GOAL_WIDTH)/2 then
            targetX = 8 * (24 - GOAL_WIDTH)/2
        elseif targetX > 8 * (12 + GOAL_WIDTH/2) - self.width then
            targetX = 8 * (12 + GOAL_WIDTH/2) - self.width 
        end
    end

    self.x, self.y, collisions, _ = bumpWorld:move(self, targetX, targetY, self.moveFilter)
    for collision in all(collisions) do
        if
            collision.other:is(Ball) and
            self:canTakeBall(collision.other)
        then
            self:takeBall(collision.other)
        end
    end

    if ball.controllingPlayer == self then
        local xOffset = Player.DIRECTION_DATA[self.direction].ballXOffset
        local yOffset = Player.DIRECTION_DATA[self.direction].ballYOffset
        ball:move(self.x + xOffset, self.y + yOffset)
    elseif self.ballLostTimer > 0 then
        self.ballLostTimer = self.ballLostTimer - 1
    end

    if self.ballReceivedTimer > 0 then
        self.ballReceivedTimer = self.ballReceivedTimer - 1
    end

    if self.isRunning then
        self.frame = self.frame + 1
    else
        self.frame = 0
    end
    self.frame = self.frame % 16
end

function Player:canTakeBall(ball)
    local speedFactor = rnd(ball:getSpeed())
    -- Goalkeeper should have a better chance of saving ball
    local speedLimit = 0.25
    if self.isGoalkeeper then
        speedLimit = 0.5
    end

    return (
        -- player doesn't already have ball
        ball.controllingPlayer ~= self and
        -- Harder to take ball if player already has ball.
        (not ball.controllingPlayer or rnd() > 0.75) and
        ballOutTimer == 0 and
        goalTimer == 0 and
        self.ballLostTimer == 0 and
        -- based on the speed of the ball, there's a chance the ball just passes straight through
        -- too hot to handle!
        speedFactor < speedLimit
    )
end

function Player:takeBall(ball)
    if ball.controllingPlayer and ball.controllingPlayer ~= self then
        ball.controllingPlayer.ballLostTimer = Player.BALL_LOST_TIMER_MAX 
    end
    ball.controllingPlayer = self
    self.ballReceivedTimer = Player.BALL_RECEIVED_TIMER_MAX 
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

Goalkeeper.PALETTE = { 2,  0 }

function Goalkeeper:draw()
    setPalette(Goalkeeper.PALETTE)
    spr(
        Player.DIRECTION_DATA[self.direction].spriteIndex + flr(self.frame / 4),
        self.x,
        self.y - 1,
        1, 1,
        Player.DIRECTION_DATA[self.direction].xFlip
    )
    setPalette(self.team.palette, 0, self.team.isAway)
end

Team = Object:extend()

Team.GRID_POSITIONS = {
        -- Defence
    "1, 2", -- RB
    "2, 2", -- CB
    "3, 2", -- CB
    "4, 2", -- LB
    -- Midfield
    "1, 4", -- RW
    "2.5, 3", -- CDM
    "3.5, 4", -- CAM
    "4, 4", -- LW
    -- Forwards
    "2, 5", -- SC
    "3, 5", -- SC
}
function Team:new(teamId, joypadId, playingUp, isAway)
    self.teamId = teamId
    self.teamData = TEAMS[teamId]
    self.palette = self.teamData.palette
    self.playingUp = playingUp
    self.isAway = isAway
    self.joypadId = joypadId
    self.players = {
        -- GK
        Goalkeeper(self, 1, 1, joypadId, true),
    }
    for pos in all(Team.GRID_POSITIONS) do
        local splitPos = split(pos)
        add(self.players, Player(
            self,
            tonum(splitPos[1]),
            tonum(splitPos[2]),
            joypadId,
            false
        ))
    end
    self.selectedPlayerIndex = 1
    self.goals = 0
end

function Team:resetPosition(isKickOff, targetX, targetY)
    for player in all(self.players) do
        player:resetPosition(isKickOff, targetX, targetY)
    end
end

function Team:findPlayerClosestToBall(excludePlayerId)
    -- Find the player closest to the ball (for switching player control)
    -- *excluding* the currently controlled player; the user is switching,
    -- so they obviously don't want them.
    -- Ball speed is taken into account to make it a true "who will get there first"
    local closestPlayerIndex, timeToBall = excludePlayerId, 9999
    for i, player in ipairs(self.players) do
        if i ~= excludePlayerId and not player.isGoalkeeper then
            local candidateDistance = getDistance(
                abs(player.x - ball.x) * (1 - ball.velX),
                abs(player.y - ball.y) * (1 - ball.velY),
                0, 0
            )
            if candidateDistance < timeToBall then
                closestPlayerIndex, timeToBall = i, candidateDistance
            end
        end
    end
    return closestPlayerIndex
end

function Team:update()
    -- Switch players if team doesn't currently have the ball
    if
        (
            (self.joypadId ~= nil and btnp(4, self.joypadId)) or
            -- Automatically switch when player is too far from ball.
            (goalTimer == 0 and getDistance(
                self.players[self.selectedPlayerIndex].x,
                self.players[self.selectedPlayerIndex].y,
                ball.x,
                ball.y
            ) > 80)
        ) and
        (ball.controllingPlayer == nil or ball.controllingPlayer.team ~= self)
    then
        self.selectedPlayerIndex = self:findPlayerClosestToBall(self.selectedPlayerIndex)
    end

    for i, player in ipairs(self.players) do
        -- If human is playing and player has ball, that player is always the selected player.
        -- Player never controls the goalkeeper.
        if ball.controllingPlayer == player and not player.isGoalkeeper then
            self.selectedPlayerIndex = i
        end

        if self.joypadId ~= nil and i == self.selectedPlayerIndex and not player.isGoalkeeper then
            player:updateActive()
        else
            player:updatePassive()
        end
        player.isChasingBall = false
    end

    -- Set one player as the ball chaser if they're closest to the ball.
    self.players[self:findPlayerClosestToBall()].isChasingBall = true
end

Team.CURSOR_COLORS = { 8, 12 }
function Team:draw()
    for i, player in ipairs(self.players) do
        resetPalette()
        if self.joypadId ~= nil and i == self.selectedPlayerIndex then
            circ(player.x + 3, player.y + 4, 3, Team.CURSOR_COLORS[self.joypadId + 1])
        end
        local swap = false
        for c in all(self.teamData.skinSwap) do
            if c == i then
                swap = true
            end
        end
        setPalette(self.palette, 0, self.isAway, swap)
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
    for y = -4, 51, FIELD_STRIPE_HEIGHT do
        rectfill(
            -32,
            y * 8,
            256,
            (y + FIELD_STRIPE_HEIGHT) * 8 - 1,
            FIELD_COLORS[flr(y/2) % 2 + 1]
        )
    end
    rect(0, 0, 191, 383, 7)
    -- 18 yards
    local x18Yards = (24 - WIDTH_18_YARD)/2
    rect(
        x18Yards * 8,
        0,
        (x18Yards + WIDTH_18_YARD) * 8 - 1,
        8 * HEIGHT_18_YARD - 1,
        7
    )
    rect(
        x18Yards * 8,
        (48 - HEIGHT_18_YARD) * 8,
        (x18Yards + WIDTH_18_YARD) * 8 - 1,
        383,
        7
    )
    -- 6 yards
    local x6Yards = (24 - WIDTH_6_YARD)/2
    rect(
        x6Yards * 8,
        0,
        (x6Yards + WIDTH_6_YARD) * 8 - 1,
        8 * HEIGHT_6_YARD - 1,
        7
    )
    rect(
        x6Yards * 8,
        (48 - HEIGHT_6_YARD) * 8,
        (x6Yards + WIDTH_6_YARD) * 8 - 1,
        383,
        7
    )
    -- penalty spots
    -- commented out to save tokens since there aren't actually
    -- penalties in the game. ideally we can uncomment this eventually
    -- local xPenalty = (24 * 8 - 2)/2
    -- rect(
    --     xPenalty,
    --     32,
    --     xPenalty + 2,
    --     33,
    --     7
    -- )
    -- rect(
    --     xPenalty,
    --     48 * 8 - 32,
    --     xPenalty + 2,
    --     48 * 8 - 31,
    --     7
    -- )
    -- Ds
    spr(59, 76, HEIGHT_18_YARD * 8, 5, 1)
    spr(75, 76, (48 - HEIGHT_18_YARD) * 8 - 8, 5, 1)
    -- halfway line
    line(0, 192, 191, 192, 7)
    circ(96, 192, 32, 7)
    -- corners
    spr(56, 0, 0, 1, 1)
    spr(57, 184, 0, 1, 1)
    spr(72, 0, 376, 1, 1)
    spr(73, 184, 376, 1, 1)
    -- stands
    if teams then
        -- north
        setPalette(teams[1].palette)
        map(0, 0, -96, -96, 48, 8)
        map(48, 0, -96, -32, 8, 28)
        map(48, 0, 224, -32, 8, 28)
        -- south
        setPalette(teams[2].palette)
        map(0, 8, -96, 416, 48, 8)
        map(56, 0, -96, 192, 8, 28)
        map(56, 0, 224, 192, 28)
        resetPalette()
    end
end

GOAL_TIMER_MAX = 300
BALL_OUT_TIMER_MAX = 180
HALF_LENGTH = 120
GAME_TIME_SCALE = 2700 -- 45 * 60
HALF_TIME_TIMER_MAX = 300

FIELD_LINE_OFFSET = 4
function initGame(team1, team2, joypadIds)
    bumpWorld = bump.newWorld(8)
    resetPalette()
    ball = Ball(0, 0)
    local isAway = false
    if TEAMS[team2].palette[1] == TEAMS[team1].palette[1] then
        isAway = true
    end
    teams = {
        Team(team1, joypadIds[1], false, false),
        Team(team2, joypadIds[2], true, isAway),
    }
    fieldLines = {
        -- Top left touchline
        FieldLine(
            -FIELD_LINE_OFFSET,
            -FIELD_LINE_OFFSET,
            (24 - GOAL_WIDTH)/2 * 8 + FIELD_LINE_OFFSET,
            1,
            false,
            teams[2]
        ),
        -- Top right touchline
        FieldLine(
            8 * (24/2 + GOAL_WIDTH/2),
            -FIELD_LINE_OFFSET,
            (24 - GOAL_WIDTH)/2 * 8 + FIELD_LINE_OFFSET,
            1,
            false,
            teams[2]
        ),
        -- Bottom left touchline
        FieldLine(
            -FIELD_LINE_OFFSET,
            48 * 8 + FIELD_LINE_OFFSET,
            (24 - GOAL_WIDTH)/2 * 8 + FIELD_LINE_OFFSET,
            1,
            false,
            teams[1]
        ),
        -- Bottom right touchline
        FieldLine(
            8 * (24/2 + GOAL_WIDTH/2),
            48 * 8 + FIELD_LINE_OFFSET,
            (24 - GOAL_WIDTH)/2 * 8 + FIELD_LINE_OFFSET,
            1,
            false,
            teams[1]
        ),
        -- Left long line
        FieldLine(-FIELD_LINE_OFFSET, -FIELD_LINE_OFFSET, 1, 48 * 8 + FIELD_LINE_OFFSET * 2),
        -- Right long line
        FieldLine(24 * 8 + 2, -FIELD_LINE_OFFSET, 1, 48 * 8 + FIELD_LINE_OFFSET * 2),
        -- Goal lines are slightly behind the field lines
        FieldLine(8 * (24 - GOAL_WIDTH)/2 + 2, -FIELD_LINE_OFFSET, GOAL_WIDTH * 8 - 4, 1, true, teams[2]),
        FieldLine(8 * (24 - GOAL_WIDTH)/2 + 2, 48 * 8 + FIELD_LINE_OFFSET, GOAL_WIDTH * 8 - 4, 1, true, teams[1]),
    }
    perimeterWalls = {
        Wall(-40, -40, 256, 8),
        Wall(-40, -40, 8, 448),
        Wall((24 + 4) * 8, -40, 8, 512),
        Wall(-40, 416, 256, 8),
        GoalWall(8 * (24 - GOAL_WIDTH)/2, -20, GOAL_WIDTH * 8, 1),
        GoalWall(8 * (24 - GOAL_WIDTH)/2, 48 * 8 + 8, GOAL_WIDTH * 8, 1),
        --Side walls
        GoalWall(8 * (24 - GOAL_WIDTH)/2, -20, 1, 20),
        GoalWall(8 * (24 - GOAL_WIDTH)/2, 48 * 8, 1, 8),
        GoalWall(8 * (GOAL_WIDTH + (24 - GOAL_WIDTH)/2), -20, 1, 20),
        GoalWall(8 * (GOAL_WIDTH + (24 - GOAL_WIDTH)/2), 48 * 8, 1, 8),
    }
    goalTimer = 0
    ballOutTimer = 0
    gameTimer = 0
    halfTimeTimer = 0
    isKickOff = true
    kickOffTeam = teams[1]

    resetKickOff()
end

function setKickOffTeam(nonKickOffTeam)
    kickOffDelay = 30 + flr(rnd(60))
    kickOffTeam = teams[1]
    if nonKickOffTeam == teams[1] then
        kickOffTeam = teams[2]
    end
end

function isFullTime()
    return gameTimer >= 2 * HALF_LENGTH * 60
end

function resetKickOff()
    kickOffDelay = 60
    ball:setPosition(96, 192)
    isKickOff = true
    resetPositions(true)
    music(0)
end

function resetPositions(isKickOff)
    local targetX, targetY
    if isFreeKick then
        targetX, targetY = ball.x, ball.y
    end
    for team in all(teams) do
        team:resetPosition(isKickOff, targetX, targetY)
    end

    -- Find player closest to ball to take free kick.
    local nearestPlayer, distance = nil, 9999
    for player in all(kickOffTeam.players) do
        local candidateDistance = getDistance(
            player.x, player.y, ball.x, ball.y
        )
        if not player.isGoalkeeper and candidateDistance < distance then
            nearestPlayer = player
            distance = candidateDistance
        end
    end
    ball.controllingPlayer = nearestPlayer
    nearestPlayer:setPosition(ball.x, ball.y)
end

function updateGame()
    if
        ballOutTimer == 0 and
        halfTimeTimer == 0 and
        not isFullTime()
    then
        -- Update teams in a random order
        -- If teams are always updated in the same order,
        -- the team that's updated last has a significant advantage
        -- (e.g. wins basically every 1-on-1 and is very hard to disposess)
        local updatedTeams = {}
        while #updatedTeams < 2 do
            local i = flr(rnd(2)) + 1
            if count(updatedTeams, i) == 0 then
                teams[i]:update()
                add(updatedTeams, i)
            end
        end
        if goalTimer == 0 and not isFreeKick and not isKickOff then
            gameTimer = gameTimer + 1
            if gameTimer == HALF_LENGTH * 60 then
                halfTimeTimer = HALF_TIME_TIMER_MAX
            end
        end
    end

    if goalTimer > 0 then
        ballOutTimer = 0
        goalTimer = goalTimer - 1
        if goalTimer == 0 then
            resetKickOff()
            isFreeKick = false
        end
    end

    if ballOutTimer > 0 then
        ballOutTimer = ballOutTimer - 1
        if ballOutTimer == 0 then
            -- This function is set depending on which field line was crossed
            ballOutReset()
            resetPositions()
        end
    elseif kickOffDelay > 0 then
        kickOffDelay = kickOffDelay - 1
    end

    if halfTimeTimer > 0 then
        halfTimeTimer = halfTimeTimer - 1
        if halfTimeTimer == 0 then
            for team in all(teams) do
                -- Change ends!
                team.playingUp = not team.playingUp
                fieldLines[1].attackingTeam = teams[1]
                fieldLines[2].attackingTeam = teams[1]
                fieldLines[3].attackingTeam = teams[2]
                fieldLines[4].attackingTeam = teams[2]
                fieldLines[7].attackingTeam = teams[1]
                fieldLines[8].attackingTeam = teams[2]
            end
            kickOffTeam = teams[2]
            resetKickOff()
        end
    end

    if halfTimeTimer == 0 and not isFullTime() then
        ball:update()
    end

    if isFullTime() and btpn(4) then
        state = STATES.MAIN_MENU
        initMainMenu()
    end
end

function drawScoreDisplay()
    for i, team in ipairs(teams) do
        setPalette(team.palette, 0, team.isAway)
        spr(88, 8, i * 8)
        resetPalette()
        spr(team.teamData.flags[1], 14, i * 8)
        printShadow(team.goals, 24, i * 8 + 2)
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
    printShadow(mins..':'..secs, 8, 26)
end

function drawGame()
    cls()
    cameraTargetX, cameraTargetY = ball.x - 63, ball.y - 63
    if goalTimer > 0 and ball.lastControllingPlayer then
        cameraTargetX, cameraTargetY = ball.lastControllingPlayer.x - 61, ball.lastControllingPlayer.y - 61
    elseif ball.controllingPlayer then
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

    local goalX = (24 - GOAL_WIDTH)/2
    spr(7, goalX * 8, -24, 4, 3)
    ball:draw()
    for team in all(teams) do team:draw() end
    spr(11, goalX * 8, 48 * 8 - 12, 4, 3)
    camera()

    if goalTimer > 0 then
        -- GOOOOAAALLLL
        setPalette(
            goalScoringTeam.palette,
            flr(goalTimer/4) % 2,
            goalScoringTeam.isAway
        )
        for i=0,7,2 do
            spr(i + 48, 32 + i * 8, 56, 2, 2)
        end
        resetPalette()
    end

    if halfTimeTimer > 0 or isFullTime() then
        fillp('0b0101101001011010.1')
        rectfill(0, 0, 127, 127, 0)
        fillp()
        rectfill(40, 57, 87, 67, 0)
        if isFullTime() then
            print('full time', 46, 60, 7)
        else
            print('half time', 46, 60, 7)
        end
        -- TODO show score under banner instead of
        -- in normal corner display
    end
    drawScoreDisplay()
end

SELECT_WIDTH = 4
SELECT_HEIGHT = 2
TEAM_GRID = {
    { 'FRG', 'ITA', 'DEN', 'ESP' },
    { 'ENG', 'IRL', 'NED', 'URS' },
}
MATCH_MODES = {
    -- P1 vs P2
    { 0, 1, 'P1 vs P2' },
    -- P1 vs CPU
    { 0, nil, 'P1 vs CPU' },
    -- CPI vs CPU
    { nil, nil, 'CPU vs CPU' },
}
MENU_STATES = {
    MODE = 'MODE',
    TEAMS = 'TEAMS',
}
function initMainMenu()
    menuState = MENU_STATES.MODE
    modeCursorPosition = 0
    p1Cursor = {
        x = 0,
        y = 0,
        -- Commented out for brevity
        -- selected = false,
    }
    p2Cursor = {
        x = 0,
        y = 0,
        -- Commented out for brevity
        -- selected = false,
    }
end

function updateCursor(cursor)
    if btnp(4) then
        cursor.selected = true
        sfx(6)
    elseif btnp(0) then
        cursor.x = cursor.x - 1
    elseif btnp(1) then
        cursor.x = cursor.x + 1
    elseif btnp(2) then
        cursor.y = cursor.y - 1
    elseif btnp(3) then
        cursor.y = cursor.y + 1
    end

    cursor.x = cursor.x % 4
    cursor.y = cursor.y % 2
end

function updateMainMenu()
    if menuState == MENU_STATES.MODE then
        if btnp(2) then
            modeCursorPosition = modeCursorPosition - 1
        elseif btnp(3) then
            modeCursorPosition = modeCursorPosition + 1
        end
        modeCursorPosition = modeCursorPosition % 3

        if btnp(4) then
            selectedMatchMode = MATCH_MODES[modeCursorPosition + 1]
            menuState = MENU_STATES.TEAMS
            sfx(6)
        end
    else
        if p2Cursor.selected then
            if btnp(4) then
                state = STATES.GAME
                initGame(
                    p1Team,
                    p2Team,
                    selectedMatchMode
                )
                sfx(6)
            elseif btnp(5) then
                p2Cursor.selected = false
            end
        elseif p1Cursor.selected then
            if btnp(5) then
                p1Cursor.selected = false
            else
                updateCursor(p2Cursor)
                if btnp(4) then
                    p2Team = TEAM_GRID[p2Cursor.y + 1][p2Cursor.x + 1]
                end
            end
        else
            if btnp(5) then
                menuState = MENU_STATES.MODE
            else
                updateCursor(p1Cursor)
                if btnp(4) then
                    p1Team = TEAM_GRID[p1Cursor.y + 1][p1Cursor.x + 1]
                end
            end
        end
    end
end

function drawMainMenu()
    cls()
    camera(32, 128)
    drawField()
    camera()

    if menuState == MENU_STATES.TEAMS then
        printShadowCentre(selectedMatchMode[3], 8)
        for y, row in ipairs(TEAM_GRID) do
            for x, team in ipairs(row) do
                local px, py = 11 + (x - 1) * 27, 32 + (y - 1) * 19
                spr(TEAMS[team].flags[2], px, py, 3, 2)
                rect(px - 1, py - 1, px + 24, py + 16, 0)
            end
        end

        palt(0, false)
        if p1Cursor.selected then
            local cursorX, cursorY = 11 + p2Cursor.x * 27, 32 + p2Cursor.y * 19
            if selectedMatchMode[3] == 'P1 vs P2' then
                spr(195, cursorX, cursorY, 3, 2)
            else
                spr(224, cursorX, cursorY, 3, 2)
            end
        else
            local cursorX, cursorY = 11 + p1Cursor.x * 27, 32 + p1Cursor.y * 19
            if selectedMatchMode[3] == 'CPU vs CPU' then
                spr(224, cursorX, cursorY, 3, 2)
            else
                spr(192, cursorX, cursorY, 3, 2)
            end
        end

        if p1Cursor.selected then
            spr(TEAMS[p1Team].flags[2], 28, 72, 3, 2)
        end
        rect(27, 71, 52, 88, 0)

        if p2Cursor.selected then
            spr(TEAMS[p2Team].flags[2], 76, 72, 3, 2)
        end
        rect(75, 71, 100, 88, 0)

        printShadowCentre('vs', 78)

        if p1Cursor.selected and p2Cursor.selected then
            printShadowCentre('ready?', 96)
        end
    elseif menuState == MENU_STATES.MODE then
        spr(182, 40, 16, 6, 5)
        for i, matchMode in ipairs(MATCH_MODES) do
            local color = 5
            if i - 1 == modeCursorPosition then
                color = 7
            end
            printShadowCentre(matchMode[3], 64 + 8 * i, color)
        end
    end
    printShadowCentre('\x8e accept - \x97 back', 120)
    resetPalette()
end

function _init()
    state = STATES.MAIN_MENU
    initMainMenu()
end

UPDATES = {
    GAME = updateGame,
    MAIN_MENU = updateMainMenu,
}
function _update60()
    UPDATES[state]()
end

DRAWS = {
    GAME = drawGame,
    MAIN_MENU = drawMainMenu,
}
function _draw()
    DRAWS[state]()
end
-- END MAIN
