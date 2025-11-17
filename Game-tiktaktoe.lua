--------------------------------------------------------
-- TIC TAC TOE FOR RADIOMASTER POCKET
-- AI Opponent with Minimax Algorithm
--------------------------------------------------------

local screenW = LCD_W or 128
local screenH = LCD_H or 64

-- Game states
local MENU = 0
local PLAYING = 1
local GAMEOVER = 2
local state = MENU

-- Board (0=empty, 1=player X, 2=AI O)
local board = {}
local EMPTY = 0
local PLAYER = 1
local AI = 2

-- Cursor position
local cursorX = 1
local cursorY = 1

-- Game settings
local cellSize = 18
local boardOffsetX = 10
local boardOffsetY = 5

-- Move tracking
local lastMoveTime = 0
local moveDelay = 200
local aiThinking = false
local aiMoveTime = 0
local aiDelay = 500

-- Game state
local currentPlayer = PLAYER
local winner = EMPTY
local gameMessage = ""
local blinkTime = 0

--------------------------------------------
-- INITIALIZE BOARD
--------------------------------------------
local function initBoard()
	board = {}
	for y = 1, 3 do
		board[y] = {}
		for x = 1, 3 do
			board[y][x] = EMPTY
		end
	end
	cursorX = 1
	cursorY = 1
	currentPlayer = PLAYER
	winner = EMPTY
	gameMessage = "Your turn!"
	aiThinking = false
end

--------------------------------------------
-- CHECK WINNER
--------------------------------------------
local function checkWinner()
	-- Check rows
	for y = 1, 3 do
		if board[y][1] ~= EMPTY and board[y][1] == board[y][2] and board[y][2] == board[y][3] then
			return board[y][1]
		end
	end
	
	-- Check columns
	for x = 1, 3 do
		if board[1][x] ~= EMPTY and board[1][x] == board[2][x] and board[2][x] == board[3][x] then
			return board[1][x]
		end
	end
	
	-- Check diagonals
	if board[1][1] ~= EMPTY and board[1][1] == board[2][2] and board[2][2] == board[3][3] then
		return board[1][1]
	end
	if board[1][3] ~= EMPTY and board[1][3] == board[2][2] and board[2][2] == board[3][1] then
		return board[1][3]
	end
	
	-- Check for draw
	local full = true
	for y = 1, 3 do
		for x = 1, 3 do
			if board[y][x] == EMPTY then
				full = false
				break
			end
		end
	end
	if full then return -1 end  -- Draw
	
	return EMPTY  -- Game continues
end

--------------------------------------------
-- MINIMAX AI ALGORITHM
--------------------------------------------
local function minimax(depth, isMaximizing)
	local result = checkWinner()
	
	-- Terminal states
	if result == AI then return 10 - depth end
	if result == PLAYER then return depth - 10 end
	if result == -1 then return 0 end  -- Draw
	
	if isMaximizing then
		local bestScore = -1000
		for y = 1, 3 do
			for x = 1, 3 do
				if board[y][x] == EMPTY then
					board[y][x] = AI
					local score = minimax(depth + 1, false)
					board[y][x] = EMPTY
					if score > bestScore then
						bestScore = score
					end
				end
			end
		end
		return bestScore
	else
		local bestScore = 1000
		for y = 1, 3 do
			for x = 1, 3 do
				if board[y][x] == EMPTY then
					board[y][x] = PLAYER
					local score = minimax(depth + 1, true)
					board[y][x] = EMPTY
					if score < bestScore then
						bestScore = score
					end
				end
			end
		end
		return bestScore
	end
end

--------------------------------------------
-- AI MAKE MOVE
--------------------------------------------
local function aiMove()
	local bestScore = -1000
	local bestX = 1
	local bestY = 1
	
	for y = 1, 3 do
		for x = 1, 3 do
			if board[y][x] == EMPTY then
				board[y][x] = AI
				local score = minimax(0, false)
				board[y][x] = EMPTY
				if score > bestScore then
					bestScore = score
					bestX = x
					bestY = y
				end
			end
		end
	end
	
	board[bestY][bestX] = AI
	aiThinking = false
	currentPlayer = PLAYER
	
	local w = checkWinner()
	if w ~= EMPTY then
		winner = w
		state = GAMEOVER
		if w == AI then
			gameMessage = "AI WINS!"
		elseif w == -1 then
			gameMessage = "DRAW!"
		end
	else
		gameMessage = "Your turn!"
	end
end

--------------------------------------------
-- PLAYER MAKE MOVE
--------------------------------------------
local function playerMove()
	if board[cursorY][cursorX] == EMPTY then
		board[cursorY][cursorX] = PLAYER
		currentPlayer = AI
		
		local w = checkWinner()
		if w ~= EMPTY then
			winner = w
			state = GAMEOVER
			if w == PLAYER then
				gameMessage = "YOU WIN!"
			elseif w == -1 then
				gameMessage = "DRAW!"
			end
		else
			gameMessage = "AI thinking..."
			aiThinking = true
			aiMoveTime = getTime()
		end
	end
end

--------------------------------------------
-- DRAW BOARD
--------------------------------------------
local function drawBoard()
	-- Draw grid
	for i = 1, 2 do
		-- Vertical lines
		lcd.drawLine(boardOffsetX + i * cellSize, boardOffsetY, 
		             boardOffsetX + i * cellSize, boardOffsetY + cellSize * 3, SOLID, 0)
		-- Horizontal lines
		lcd.drawLine(boardOffsetX, boardOffsetY + i * cellSize, 
		             boardOffsetX + cellSize * 3, boardOffsetY + i * cellSize, SOLID, 0)
	end
	
	-- Draw X's and O's
	for y = 1, 3 do
		for x = 1, 3 do
			local px = boardOffsetX + (x - 1) * cellSize
			local py = boardOffsetY + (y - 1) * cellSize
			
			if board[y][x] == PLAYER then
				-- Draw X
				lcd.drawLine(px + 3, py + 3, px + cellSize - 3, py + cellSize - 3, SOLID, 0)
				lcd.drawLine(px + cellSize - 3, py + 3, px + 3, py + cellSize - 3, SOLID, 0)
			elseif board[y][x] == AI then
				-- Draw O
				local cx = px + cellSize / 2
				local cy = py + cellSize / 2
				local r = cellSize / 2 - 4
				-- Draw circle using lines (approximation)
				for angle = 0, 360, 30 do
					local x1 = cx + r * math.cos(math.rad(angle))
					local y1 = cy + r * math.sin(math.rad(angle))
					local x2 = cx + r * math.cos(math.rad(angle + 30))
					local y2 = cy + r * math.sin(math.rad(angle + 30))
					lcd.drawLine(x1, y1, x2, y2, SOLID, 0)
				end
			end
		end
	end
	
	-- Draw cursor (blinking)
	if currentPlayer == PLAYER and getTime() % 50 < 25 then
		local px = boardOffsetX + (cursorX - 1) * cellSize
		local py = boardOffsetY + (cursorY - 1) * cellSize
		lcd.drawRectangle(px + 1, py + 1, cellSize - 2, cellSize - 2)
	end
end

--------------------------------------------
-- HANDLE INPUT
--------------------------------------------
local function handleInput(event)
	local now = getTime()
	
	if now - lastMoveTime < moveDelay then
		return
	end
	
	local ailVal = getValue("ail")
	local eleVal = getValue("ele")
	
	-- Move cursor with sticks
	if ailVal > 500 then
		cursorX = cursorX + 1
		if cursorX > 3 then cursorX = 1 end
		lastMoveTime = now
	elseif ailVal < -500 then
		cursorX = cursorX - 1
		if cursorX < 1 then cursorX = 3 end
		lastMoveTime = now
	end
	
	if eleVal > 500 then
		cursorY = cursorY - 1
		if cursorY < 1 then cursorY = 3 end
		lastMoveTime = now
	elseif eleVal < -500 then
		cursorY = cursorY + 1
		if cursorY > 3 then cursorY = 3 end
		lastMoveTime = now
	end
	
	-- Make move with Enter (aileron center click on some radios)
	if event == EVT_ENTER_BREAK or event == EVT_ENTER_FIRST then
		playerMove()
		lastMoveTime = now
	end
end

--------------------------------------------
-- INIT
--------------------------------------------
local function init()
	lcd.clear()
	initBoard()
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
		lcd.drawText(15, 10, "TIC TAC TOE", MIDSIZE)
		lcd.drawText(20, 30, "You: X", SMLSIZE)
		lcd.drawText(20, 40, "AI:  O", SMLSIZE)
		lcd.drawText(5, screenH - 10, "ENTER to start", SMLSIZE)
		
		if event == EVT_ENTER_BREAK then
			initBoard()
			state = PLAYING
		end
	
	-- PLAYING STATE
	elseif state == PLAYING then
		drawBoard()
		
		-- Status message
		lcd.drawText(70, 8, gameMessage, SMLSIZE)
		lcd.drawText(70, 20, "Ail/Ele:", SMLSIZE)
		lcd.drawText(70, 28, "Move", SMLSIZE)
		lcd.drawText(70, 38, "Enter:", SMLSIZE)
		lcd.drawText(70, 46, "Select", SMLSIZE)
		
		-- Handle AI turn
		if aiThinking and getTime() - aiMoveTime > aiDelay then
			aiMove()
		end
		
		-- Handle player input
		if currentPlayer == PLAYER and not aiThinking then
			handleInput(event)
		end
	
	-- GAME OVER STATE
	elseif state == GAMEOVER then
		drawBoard()
		
		-- Display result
		local msgX = screenW / 2 - (#gameMessage * 5 / 2)
		if getTime() % 100 < 50 then
			lcd.drawFilledRectangle(msgX - 2, screenH - 13, #gameMessage * 5 + 4, 11)
			lcd.drawText(msgX, screenH - 11, gameMessage, SMLSIZE + INVERS)
		else
			lcd.drawText(msgX, screenH - 11, gameMessage, SMLSIZE)
		end
		
		lcd.drawText(68, 25, "ENTER:", SMLSIZE)
		lcd.drawText(68, 33, "Play", SMLSIZE)
		lcd.drawText(68, 41, "Again", SMLSIZE)
		
		if event == EVT_ENTER_BREAK then
			initBoard()
			state = PLAYING
		end
	end
	
	return 0
end

return {init=init, run=run}