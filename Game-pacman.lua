--------------------------------------------------------
-- PAC-MAN FOR RADIOMASTER POCKET
-- Classic arcade action on EdgeTX!
--------------------------------------------------------

local screenW = LCD_W or 128
local screenH = LCD_H or 64

-- Game states
local MENU = 0
local PLAYING = 1
local GAMEOVER = 2
local LEVELCOMPLETE = 3
local state = MENU

-- Maze (0=empty, 1=wall, 2=dot, 3=power pellet)
local maze = {}
local mazeW = 19
local mazeH = 11
local cellSize = 6

-- Pac-Man
local pacman = {
	x = 9,
	y = 8,
	dir = 0,  -- 0=right, 1=down, 2=left, 3=up
	nextDir = 0,
	speed = 15,
	lastMove = 0,
	mouthOpen = true,
	animTime = 0,
	lives = 3
}

-- Ghosts
local ghosts = {}
local ghostColors = {0, 0, 0, 0}  -- All same on monochrome
local powerMode = false
local powerTime = 0
local powerDuration = 400  -- 4 seconds

-- Game stats
local score = 0
local level = 1
local dotsLeft = 0
local highScore = 0

-- Maze template (11x19)
local mazeTemplate = {
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
	{1,2,2,2,2,2,2,2,2,1,2,2,2,2,2,2,2,2,1},
	{1,3,1,1,2,1,1,1,2,1,2,1,1,1,2,1,1,3,1},
	{1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1},
	{1,2,1,1,2,1,2,1,1,1,1,1,2,1,2,1,1,2,1},
	{1,2,2,2,2,1,2,2,2,1,2,2,2,1,2,2,2,2,1},
	{1,1,1,1,2,1,1,1,0,1,0,1,1,1,2,1,1,1,1},
	{1,2,2,2,2,1,2,2,2,2,2,2,2,1,2,2,2,2,1},
	{1,2,1,1,2,1,2,1,1,0,1,1,2,1,2,1,1,2,1},
	{1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1},
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

--------------------------------------------
-- INITIALIZE GAME
--------------------------------------------
local function initGame()
	-- Copy maze template
	maze = {}
	dotsLeft = 0
	for y = 1, mazeH do
		maze[y] = {}
		for x = 1, mazeW do
			maze[y][x] = mazeTemplate[y][x]
			if maze[y][x] == 2 then
				dotsLeft = dotsLeft + 1
			elseif maze[y][x] == 3 then
				dotsLeft = dotsLeft + 1
			end
		end
	end
	
	-- Reset Pac-Man
	pacman.x = 9
	pacman.y = 8
	pacman.dir = 0
	pacman.nextDir = 0
	pacman.lastMove = getTime()
	pacman.animTime = getTime()
	
	-- Initialize ghosts
	ghosts = {
		{x = 8,  y = 6, dir = 0, startX = 8,  startY = 6, mode = "chase"},
		{x = 9,  y = 6, dir = 2, startX = 9,  startY = 6, mode = "chase"},
		{x = 10, y = 6, dir = 0, startX = 10, startY = 6, mode = "chase"},
		{x = 11, y = 6, dir = 2, startX = 11, startY = 6, mode = "chase"}
	}
	
	powerMode = false
	state = PLAYING
end

local function initLevel()
	pacman.lives = 3
	level = 1
	score = 0
	initGame()
end

--------------------------------------------
-- CHECK IF MOVE IS VALID
--------------------------------------------
local function canMove(x, y)
	if x < 1 or x > mazeW or y < 1 or y > mazeH then
		return false
	end
	return maze[y][x] ~= 1
end

--------------------------------------------
-- UPDATE PAC-MAN
--------------------------------------------
local function updatePacman()
	local now = getTime()
	
	-- Animation
	if now - pacman.animTime > 10 then
		pacman.mouthOpen = not pacman.mouthOpen
		pacman.animTime = now
	end
	
	-- Movement
	if now - pacman.lastMove > pacman.speed then
		-- Try to change direction
		local nx, ny = pacman.x, pacman.y
		if pacman.nextDir == 0 then nx = nx + 1
		elseif pacman.nextDir == 1 then ny = ny + 1
		elseif pacman.nextDir == 2 then nx = nx - 1
		elseif pacman.nextDir == 3 then ny = ny - 1
		end
		
		if canMove(nx, ny) then
			pacman.dir = pacman.nextDir
		end
		
		-- Move in current direction
		nx, ny = pacman.x, pacman.y
		if pacman.dir == 0 then nx = nx + 1
		elseif pacman.dir == 1 then ny = ny + 1
		elseif pacman.dir == 2 then nx = nx - 1
		elseif pacman.dir == 3 then ny = ny - 1
		end
		
		if canMove(nx, ny) then
			pacman.x = nx
			pacman.y = ny
			
			-- Wrap around
			if pacman.x < 1 then pacman.x = mazeW end
			if pacman.x > mazeW then pacman.x = 1 end
			
			-- Collect dot
			if maze[pacman.y][pacman.x] == 2 then
				maze[pacman.y][pacman.x] = 0
				score = score + 10
				dotsLeft = dotsLeft - 1
			elseif maze[pacman.y][pacman.x] == 3 then
				maze[pacman.y][pacman.x] = 0
				score = score + 50
				dotsLeft = dotsLeft - 1
				powerMode = true
				powerTime = now
				-- Reverse ghosts
				for i = 1, #ghosts do
					ghosts[i].dir = (ghosts[i].dir + 2) % 4
				end
			end
			
			-- Check level complete
			if dotsLeft == 0 then
				state = LEVELCOMPLETE
				if score > highScore then highScore = score end
			end
		end
		
		pacman.lastMove = now
	end
	
	-- Check power mode timeout
	if powerMode and now - powerTime > powerDuration then
		powerMode = false
	end
end

--------------------------------------------
-- SIMPLE GHOST AI
--------------------------------------------
local function updateGhosts()
	local now = getTime()
	
	for i = 1, #ghosts do
		local g = ghosts[i]
		
		if now - (g.lastMove or 0) > 35 then
			-- Simple AI: random movement with slight bias toward pacman
			local possibleDirs = {}
			
			for dir = 0, 3 do
				local nx, ny = g.x, g.y
				if dir == 0 then nx = nx + 1
				elseif dir == 1 then ny = ny + 1
				elseif dir == 2 then nx = nx - 1
				elseif dir == 3 then ny = ny - 1
				end
				
				if canMove(nx, ny) and dir ~= (g.dir + 2) % 4 then
					possibleDirs[#possibleDirs + 1] = dir
				end
			end
			
			if #possibleDirs > 0 then
				-- Bias toward pacman 30% of the time
				if not powerMode and math.random(100) < 30 then
					local bestDir = possibleDirs[1]
					local bestDist = 999
					for j = 1, #possibleDirs do
						local dir = possibleDirs[j]
						local nx, ny = g.x, g.y
						if dir == 0 then nx = nx + 1
						elseif dir == 1 then ny = ny + 1
						elseif dir == 2 then nx = nx - 1
						elseif dir == 3 then ny = ny - 1
						end
						local dist = math.abs(nx - pacman.x) + math.abs(ny - pacman.y)
						if dist < bestDist then
							bestDist = dist
							bestDir = dir
						end
					end
					g.dir = bestDir
				else
					g.dir = possibleDirs[math.random(#possibleDirs)]
				end
			end
			
			-- Move ghost
			local nx, ny = g.x, g.y
			if g.dir == 0 then nx = nx + 1
			elseif g.dir == 1 then ny = ny + 1
			elseif g.dir == 2 then nx = nx - 1
			elseif g.dir == 3 then ny = ny - 1
			end
			
			if canMove(nx, ny) then
				g.x = nx
				g.y = ny
			end
			
			g.lastMove = now
		end
		
		-- Check collision with pacman
		if g.x == pacman.x and g.y == pacman.y then
			if powerMode then
				-- Eat ghost
				score = score + 200
				g.x = g.startX
				g.y = g.startY
			else
				-- Lose life
				pacman.lives = pacman.lives - 1
				if pacman.lives <= 0 then
					state = GAMEOVER
					if score > highScore then highScore = score end
				else
					-- Reset positions
					pacman.x = 9
					pacman.y = 8
					for j = 1, #ghosts do
						ghosts[j].x = ghosts[j].startX
						ghosts[j].y = ghosts[j].startY
					end
				end
			end
		end
	end
end

--------------------------------------------
-- DRAW GAME
--------------------------------------------
local function drawGame()
	-- Draw maze
	for y = 1, mazeH do
		for x = 1, mazeW do
			local px = (x - 1) * cellSize
			local py = (y - 1) * cellSize
			
			if maze[y][x] == 1 then
				-- Wall
				lcd.drawFilledRectangle(px, py, cellSize, cellSize)
			elseif maze[y][x] == 2 then
				-- Dot
				lcd.drawPoint(px + cellSize/2, py + cellSize/2)
			elseif maze[y][x] == 3 then
				-- Power pellet (blinking)
				if getTime() % 50 < 25 then
					lcd.drawFilledRectangle(px + cellSize/2 - 1, py + cellSize/2 - 1, 2, 2)
				end
			end
		end
	end
	
	-- Draw ghosts
	for i = 1, #ghosts do
		local g = ghosts[i]
		local px = (g.x - 1) * cellSize + cellSize/2
		local py = (g.y - 1) * cellSize + cellSize/2
		
		if powerMode and getTime() % 20 < 10 then
			-- Scared ghost (flashing)
			lcd.drawRectangle(px - 2, py - 2, 4, 4)
		else
			-- Normal ghost
			lcd.drawFilledRectangle(px - 2, py - 2, 4, 4)
			lcd.drawPoint(px - 1, py - 1)
			lcd.drawPoint(px + 1, py - 1)
		end
	end
	
	-- Draw Pac-Man
	local px = (pacman.x - 1) * cellSize + cellSize/2
	local py = (pacman.y - 1) * cellSize + cellSize/2
	
	if pacman.mouthOpen then
		-- Open mouth
		lcd.drawFilledRectangle(px - 2, py - 2, 4, 4)
		if pacman.dir == 0 then
			lcd.drawPoint(px + 2, py)
		elseif pacman.dir == 1 then
			lcd.drawPoint(px, py + 2)
		elseif pacman.dir == 2 then
			lcd.drawPoint(px - 2, py)
		else
			lcd.drawPoint(px, py - 2)
		end
	else
		-- Closed mouth
		lcd.drawFilledRectangle(px - 2, py - 2, 4, 4)
	end
	
	-- Draw HUD at bottom
	lcd.drawText(1, screenH - 7, "SC:" .. score, SMLSIZE)
	lcd.drawText(50, screenH - 7, "LV:" .. level, SMLSIZE)
	lcd.drawText(85, screenH - 7, "L:" .. pacman.lives, SMLSIZE)
	
	-- Power mode indicator
	if powerMode then
		lcd.drawText(110, 1, "PWR", SMLSIZE)
	end
end

--------------------------------------------
-- HANDLE INPUT
--------------------------------------------
local function handleInput()
	local ailVal = getValue("ail")
	local eleVal = getValue("ele")
	
	if ailVal > 500 then
		pacman.nextDir = 0  -- Right
	elseif ailVal < -500 then
		pacman.nextDir = 2  -- Left
	end
	
	if eleVal > 500 then
		pacman.nextDir = 3  -- Up
	elseif eleVal < -500 then
		pacman.nextDir = 1  -- Down
	end
end

--------------------------------------------
-- INIT
--------------------------------------------
local function init()
	lcd.clear()
	math.randomseed(getTime())
end

--------------------------------------------
-- RUN
--------------------------------------------
local function run(event)
	lcd.clear()
	
	-- Handle exit
	if event == EVT_EXIT_BREAK then
		return 2
	end
	
	-- MENU STATE
	if state == MENU then
		lcd.drawText(30, 5, "PAC-MAN", MIDSIZE)
		lcd.drawText(25, 25, "Classic Arcade", SMLSIZE)
		lcd.drawText(25, 35, "Action!", SMLSIZE)
		if highScore > 0 then
			lcd.drawText(20, 45, "Best:" .. highScore, SMLSIZE)
		end
		lcd.drawText(15, screenH - 9, "ENTER to start", SMLSIZE)
		
		if event == EVT_ENTER_BREAK then
			initLevel()
		end
	
	-- PLAYING STATE
	elseif state == PLAYING then
		handleInput()
		updatePacman()
		updateGhosts()
		drawGame()
	
	-- LEVEL COMPLETE STATE
	elseif state == LEVELCOMPLETE then
		lcd.drawText(20, screenH/2 - 10, "LEVEL CLEAR!", MIDSIZE)
		lcd.drawText(25, screenH/2 + 5, "Score:" .. score, SMLSIZE)
		lcd.drawText(15, screenH - 9, "ENTER continue", SMLSIZE)
		
		if event == EVT_ENTER_BREAK then
			level = level + 1
			pacman.speed = pacman.speed - 1
			if pacman.speed < 8 then pacman.speed = 8 end
			initGame()
		end
	
	-- GAME OVER STATE
	elseif state == GAMEOVER then
		lcd.drawText(25, 10, "GAME OVER", MIDSIZE)
		lcd.drawText(30, 30, "Score:" .. score, SMLSIZE)
		lcd.drawText(30, 40, "Level:" .. level, SMLSIZE)
		lcd.drawText(15, screenH - 9, "ENTER to retry", SMLSIZE)
		
		if event == EVT_ENTER_BREAK then
			initLevel()
		end
	end
	
	return 0
end

return {init=init, run=run}