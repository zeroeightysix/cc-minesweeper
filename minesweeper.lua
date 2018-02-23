local function sp(x,y) return term.setCursorPos(x,y) end
local function bg(col) return term.setBackgroundColor(col) end
local function tc(col) return term.setTextColor(col) end

local sW,sH = term.getSize()
local fW,fH = sW-2,sH-2
local mines = -1 -- to be calculated later
local grid = {} -- -2 = untouched mine, -1 = untouched non-mine, 0 = discovered, 1,2,3,4,5,6,7,8 = number indicators, 9 = flag
local failed = false
local backgroundColour = colours.black

local isMonitor = term.getSize()~=51
local flagMode = false -- Monitor-only
local timeCache = ""

local tileColours = {
  ["untouched"] = colours.lightGrey,
  ["mine"] = colours.black,
  ["flag"] = colours.red,
  ["disc"] = colours.grey -- discovered
}

local function getc(n) return tileColours[n] end
local function mapc(n) return (failed and (n==-2 and getc("mine") or (n==9 and getc("flag") or getc("disc")))) or (n<0 and getc("untouched") or ((n>=0 and n<9) and getc("disc") or getc("flag"))) end

local mineMap = {}

if ... then
  local t = {...}
  if #t > 4 or #t < 2 then
    printError("Expected two arguments: width, height, [mines]")
    return
  end

  fW = tonumber(t[1])
  fH = tonumber(t[2])

  if t[3] then
    mines = tonumber(t[3])
    if not mines or mines < 0 or mines > (fW*fH) then
      printError("Mines must be numerical | mines cannot < 0 | you can't have more mines than tiles on the screen")
    end
  end

  if not fW or not fH then
    printError("Expected numerical arguments")
    return
  end
end

if mines==-1 then
  mines = (fW*fH)*.15
end
mines=math.floor(mines)

local function createField()
  timeCache = ""
  grid={}
  for col=1,fW do
    local c = {}
    for row=1,fH do
      table.insert(c,-1)
    end
    table.insert(grid, c)
  end
  
  local minesPlaced = 0
  while minesPlaced < mines do
    local x = math.random(1,fW)
    local y = math.random(1,fH)
    if grid[x][y] ~= -2 then
      minesPlaced = minesPlaced + 1
      grid[x][y] = -2
    end
  end
end
createField()

local doTable = {}
local function on(event, f) doTable[event]=f end -- Just a fancy function so code looks nice

local startX = math.floor(sW/2-(fW/2)) -- -1 because FUCKING arrays start at ONE
local startY = math.floor(sH/2-(fH/2))

local sh = 2^math.ceil(math.log10(fH))
local function toSingle(x,y)
  return bit32.lshift(x,sh) + y -- holy shit
end

local function fromSingle(s)
  local x = bit32.rshift(s,sh)
  local y = bit32.band(s,(2^sh)-1)
  return x, y
end

local function drawTile(x, y)
  local tile = grid[x][y]
  bg(mapc(tile))
  sp(startX+x,startY+y)
  local s = " "
  if tile > 0 and tile < 9 then
  	tc(colours.white)
    s = tostring(tile)
  end
  write(s)
end

local function redraw()
  backgroundColour = (math.random(0,1)==0) and (2^math.random(1,6)) or (2^math.random(9,15))
  bg(backgroundColour)
  term.clear()

  local bc = colours.purple
  if backgroundColour==colours.purple then bc = colours.yellow end

  local str = " Retry "
  sp(math.ceil(sW/2-#str/2),1)
  bg(bc)
  tc(colours.white)
  write(str)

  if isMonitor then
    bg(backgroundColour)
    tc(flagMode and colours.red or colours.black)
    sp(math.floor( sW/2+#" Retry "/2+3 ),1)
    write((flagMode and "F" or "B"))
  end

  bg(getc("untouched"))
  for x=1,fW do
    for y=1,fH do
      drawTile(x,y)
    end
  end
end
redraw()

local function isValid(x,y) return x >= 1 and x <= fW and y >= 1 and y <= fH end
local function findMinesAround(x, y)
  local function isMine(x,y) 
    if isValid(x,y) then
      local t = grid[x][y]
      if t == -2 then
      	return 1
      else
      	if t == 9 then return ((mineMap[tostring(toSingle(x, y))]==-2) and 1 or 0) end
        return 0
      end
    end
    return 0
  end
  local m = 0
  -- sorry
  m = m + isMine(x-1,y-1)
  m = m + isMine(x-1,y)
  m = m + isMine(x-1,y+1)
  m = m + isMine(x,y-1)
  m = m + isMine(x,y+1)
  m = m + isMine(x+1,y-1)
  m = m + isMine(x+1,y)
  m = m + isMine(x+1,y+1)
  return m
end

local function discover(x,y)
  if not isValid(x,y) or grid[x][y] >= 0 then return end
  local surrounding = findMinesAround(x,y)
  grid[x][y]=surrounding
  drawTile(x,y)
  if surrounding == 0 then
    -- sorry again
    discover(x-1,y-1)
    discover(x-1,y)
    discover(x-1,y+1)
    discover(x,y-1)
    discover(x,y+1)
    discover(x+1,y-1)
    discover(x+1,y)
    discover(x+1,y+1)
  end
end

on("terminate", function(ev)
  bg(colours.black)
  tc(colours.white)
  term.clear()
  sp(1,1)
  return true
end)

on("mouse_click", function(ev, btn, x, y) 
  if x<=startX or x>startX+fW or y<=startY or y>startY+fH then
  	if y==1 then
  	  if x >= sW/2-#" Retry "/2 and x <= sW/2+#" Retry "/2 then
        failed = false
        createField()
        redraw()
  	  elseif isMonitor and x == math.floor( sW/2+#" Retry "/2+3 ) then
  	  	 flagMode = not flagMode

       sp(math.floor( sW/2+#" Retry "/2+3 ),1)
       bg(backgroundColour)
       tc(flagMode and colours.red or colours.black)
       write(flagMode and "F" or "B")
  	  end
  	else
      redraw()
    end
  else
    local tX = x-startX
    local tY = y-startY
    local tile = grid[tX][tY]
    local flag1 = isMonitor and flagMode or btn==2

    if flag1 and (tile<0) then
      mineMap[tostring(toSingle(tX,tY))]=tile
      grid[tX][tY] = 9 -- 9=flag
      drawTile(tX,tY)
    elseif tile == -2 then
      failed = true
      timeStarted = nil

      for x=1,fW do
        for y=1,fH do
          if grid[x][y]==-1 then
            discover(x,y)
          end
        end
      end

      redraw()
    elseif tile == -1 then
      if not timeStarted then
        timeStarted = os.epoch("utc")
      end
      discover(tX, tY)
    elseif tile == 9 and flag1 then
      local single = tostring(toSingle(tX, tY))
      grid[tX][tY] = mineMap[single]
      table.remove(mineMap, single)
      drawTile(tX,tY)
    end
  end
end)

local function eventLoop()
  while true do
    local ev = {os.pullEventRaw()}
    if doTable[ev[1]] and doTable[ev[1]](unpack(ev)) then
      return
    end
  end
end

local function infoLoop()
  while true do
  	local timeSpent = 0
  	if timeStarted then
      timeCache = " " .. math.floor((os.epoch("utc")-timeStarted)/1000)
  	end
  	sp(sW - #timeCache,1)
  	bg(backgroundColour)
  	tc(backgroundColour==colours.red and colours.black or colours.red)
  	write(timeCache)

  	sp(2,1)
  	write(mines-#mineMap)
  	sleep(1)
  end
end

parallel.waitForAny(eventLoop, infoLoop)