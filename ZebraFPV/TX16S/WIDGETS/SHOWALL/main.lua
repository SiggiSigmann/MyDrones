local WGTNAME = "showal" .. "0.9"  -- max 9 characters

--[[
HISTORY
=======
Author Mike Shellim http://www.rc-soar.com/opentx/lua
2019-11-23  v0.9 	First release

Displays basic info about active model.
At startup looks for output channel named 'armed'.
If found, flashes 'motor armed' when channel value > 0.

INSTRUCTIONS FOR USER
=====================
Please read the instructions before use. These are included in
the zip package, or they can be downloaded from this link:
https://rc-soar.com/opentx/lua/showitall/ShowItAll_09.pdf


DISCLAIMER
==========
IT IS THE USER'S RESPONSIBILITY TO CHECK FOR CORRECT OPERATION
BEFORE USE. IF IN DOUBT DO NOT FLY!!
--]]

-----------------------
-- USER SETTABLE PARAMS
-----------------------
-- maximum number of logical switches to display
-- 20 is recommended for good performance in general use
-- If you don't use other scripts, you can try increasing this value
-- to a max of 32
local MAX_LS = 20
------------------------------
-- END OF USER SETTABLE PARAMS
------------------------------

-- Field ids for getValue()
local idSA
local idTmr1
local idLS1
local idTxV
local idEle
local idAil
local idRud
local idThr
local idchArmed
local idCh1

-- item counts
local nLS
local nTmr

-----------------
-- OPTIONS
-----------------
local defaultOptions = {
	{"Use dflt clrs", BOOL, 1},
	{"BackColor", COLOR, WHITE},
	{"ForeColor", COLOR, BLACK},
	}

-- define a nominal grid
local X0 = 3	-- col 1
local X0A = 6
local X1 = 138	-- col 2
local X2 = 284	-- col 3
local Y1 = 36	-- row 2
local Y2 = 105	-- row 3

local blocks = {}
blocks ['modelname'] = 	{x=X0, y=0,  font=MIDSIZE, dy=10}
blocks ['switches'] = 	{x=X0A,y=Y1, font=SMLSIZE, dy=12, colsep=40}
blocks ['centreblock']=	{x=X1, y=Y1, font=0, dy=18}
blocks ['fm'] = 		{x=X1, y=Y2, font=MIDSIZE}
blocks ['ls'] = 		{x=X2, y=Y1+3, font=MIDSIZE, dx=8, dy=9, colsep = 12}
blocks ['timers']=		{x=X2, y=Y2, font=SMLSIZE, dy=13}
blocks ['stickvals']=	{x=X0A,y=Y2+5, dy=12, hBar=5, side=35}
blocks ['channels']=	{x=X0A+56, y=Y2, dy=8, hBar=5, side=18}
blocks ['alerts']=		{x=X2, y=0,  font=MIDSIZE}

local sticks = {}


-- This function determines the number of items in a field
local function getNumItems (field, maxitems)
	local i = 1
	while true do
		if i > maxitems or not getFieldInfo(field ..i) then
			break
		end
		i = i + 1
	end
	return i-1
end


--------------------------------------------------
-- CREATE is called by OpenTX to create the widget
--------------------------------------------------
local function create(zone, options)

	-- stash field id's (efficiency)
	idSA = getFieldInfo('sa').id
	idLS1 = getFieldInfo('ls1').id
	idTmr1 = getFieldInfo('timer1').id
	idTxV = getFieldInfo('tx-voltage').id
	idEle= getFieldInfo('ele').id
	idAil= getFieldInfo('ail').id
	idRud= getFieldInfo('rud').id
	idThr= getFieldInfo('thr').id
	idCh1 = getFieldInfo('ch1').id

	-- Limit LS count to avoid possible performance
	-- hit especially with mixer scripts.
	nLS = getNumItems ('ls', MAX_LS)
	nTmr = getNumItems ('timer',3)

	-- look for output channel named 'armed'
	idchArmed = nil
	local i = 0
	while true do
		local o = model.getOutput (i)
		if not o then break end
		if string.lower (string.sub (o.name, 1,5)) == "armed" then
			idchArmed = getFieldInfo ("ch".. (i+1)).id
			break
		end
		i = i + 1
	end

	sticks={
		{name='A', id=idAil},
		{name='E', id=idEle},
		{name='T', id=idThr},
		{name='R', id=idRud}
		}

	return {zone=zone, options=options}
end


---------------------------------------------
-- UPDATE is called by OpenTX on registration
-- and at change of settings
---------------------------------------------
local function update(wgt, newOptions)
    wgt.options = newOptions
end

--------------------------------
-- BACKGROUND
-- PERIODICALLY CALLED FUNCTION
--------------------------------
local function background(wgt)
end


-- this function converts seconds to a string in hh:mm:ss format
local function hms (secs)
	local ss = secs % 60
	local hh = math.floor (secs/3600)
	local mm = (secs - hh*3600 - ss) / 60
	return string.format ("%02d:%02d:%02d",hh,mm,ss)
end

-- this function draws a symobol representing switch state up/middle/down
local function drawSwitchSymbol (x,y,w,h,val, flags)
	local weight = 2
	if val==0 then
		lcd.drawFilledRectangle (x, y+h/2, w,1, flags)
	elseif val > 0 then
		lcd.drawFilledRectangle (x+ w/2, y+h/2-1, 1,h/2+1,flags)
		lcd.drawFilledRectangle (x, y+h, w,weight,flags)
	else
		lcd.drawFilledRectangle (x+ w/2, y, 1,h/2+2,flags)
		lcd.drawFilledRectangle (x, y, w,weight,flags)
	end
end


------------------------------------
-- REFRESH
-- This is run when the Widget is being displayed
------------------------------------
local function refresh(wgt)
	local x
	local y
	local flagsColor
	local xOffset
	local yTxtOff
	local getv

	-- Colour option
	-- Check for LS bit (Github #7059)
	if bit32.btest (wgt.options["Use dflt clrs"], 1) then
		flagsColor = 0
	else
		lcd.setColor (CUSTOM_COLOR, wgt.options.BackColor)
		flagsColor = CUSTOM_COLOR
		lcd.drawFilledRectangle (
			wgt.zone.x,
			wgt.zone.y,
			wgt.zone.w,
			wgt.zone.h,
			flagsColor)
	end

	lcd.setColor (CUSTOM_COLOR, wgt.options.ForeColor)

	-- error if not full screen
	if wgt.zone.w < 390 or wgt.zone.h < 172  then
		lcd.drawText (wgt.zone.x, wgt.zone.y, WGTNAME .. ":pane too small", SMLSIZE + flagsColor)
		return
	end

	-------------------------------
	-- Model name
	-------------------------------
	local bl = blocks['modelname']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	lcd.drawText (x, y, model.getInfo().name, bl.font + flagsColor)

	-------------------------------
	-- Switches
	-------------------------------
	bl = blocks ['switches']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	for i = 0, 7 do
		local getv = getValue (idSA+i)
		lcd.drawText (x, y, "S".. string.char(string.byte('A')+i), bl.font + flagsColor)
		drawSwitchSymbol (x+22, y+4, 5, 8, getv, flagsColor)
		y = y + bl.dy
		if i==3 then
			x = x + bl.colsep
			y = wgt.zone.y + bl.y
		end
	end

	-------------------------------
	-- Flight mode
	-------------------------------
	bl = blocks ['fm']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	local fmno, fmname = getFlightMode()
	if fmname == "" then
		fmname = "FM".. fmno
	end
	lcd.drawText (x, y, fmname, bl.font + flagsColor)



	-------------------------------
	-- RSSI, battery voltages
	-------------------------------
	bl = blocks ['centreblock']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y -2
	xOffset = 60

	getv = getValue(idTxV)
	lcd.drawText (x, y, "TxBatt", bl.font + flagsColor)
	lcd.drawText (x + xOffset, y, (getv and getv>0)  and string.format ("%.1f", getv) or "---", bl.font  + flagsColor)
	y = y + bl.dy

	getv = getValue("RxBt")
	lcd.drawText (x, y, "RxBatt", bl.font+ flagsColor)
	lcd.drawText (x + xOffset, y, (getv and getv>0)  and string.format ("%.1f", getv) or "---", bl.font  + flagsColor)
	y = y + bl.dy

	getv = getValue("RSSI")
	lcd.drawText (x, y, "RSSI", bl.font + flagsColor)
	lcd.drawText (x + xOffset, y, (getv and getv>0)  and getv  or "---", bl.font  + flagsColor)


	-------------------------------
	-- timers
	-------------------------------
	bl = blocks ['timers']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y +2
	for i = 0, nTmr-1 do
		lcd.drawText (x, y + i*bl.dy, "T" .. (i+1) .. ":", bl.font + flagsColor)
		lcd.drawText (x+85, y + i*bl.dy, hms(getValue(idTmr1+i)), bl.font + flagsColor + RIGHT)
	end

	-------------------------------
	-- Logical switches
	-------------------------------
	bl = blocks ['ls']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	local wBlob = bl.dx - 2
	local hBlob = bl.dy - 2
	local i = 0
	while i < nLS do
		getv = getValue (idLS1 + i)
		if getv then
			if getv == 0 then
				lcd.drawFilledRectangle (x+wBlob/2, y+hBlob/2,1,1,flagsColor)
			elseif getv > 0 then
				lcd.drawFilledRectangle (x,y,wBlob,hBlob, flagsColor)
			else
				lcd.drawRectangle (x,y,wBlob,hBlob, flagsColor)
			end
		end
		i = i + 1
		if i%10 == 0 then
			x = wgt.zone.x + bl.x
			y = y + bl.dy
		elseif i%5 == 0 then
			x = x + bl.colsep
		else
			x = x + bl.dx
		end
	end
	lcd.drawText (x, y-4, "LS 01-"..nLS, SMLSIZE + flagsColor)

	-------------------------------
	-- Sticks (R E T A raw values)
	-------------------------------
	bl = blocks ['stickvals']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	xOffset = 10
	yTxtOff = -5
	for _, st in ipairs (sticks) do
		lcd.drawText (
			x,
			y + yTxtOff,
			st.name .. ":" .. math.floor (0.5 + getValue(st.id)/10.24),
			SMLSIZE + flagsColor
			)
		y = y + bl.dy
	end

	---------------
	-- Channels 1-7
	---------------
	bl = blocks ['channels']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	x = x + 5
	yTxtOff = -5
	local chars = {[0]="1","","3","","5","","7"}
	for i = 0, 6 do
		lcd.drawText (x-3, y + yTxtOff, chars[i], SMLSIZE + flagsColor + RIGHT)
		lcd.drawRectangle (x, y, 2*bl.side, bl.hBar, flagsColor)
		getv = (getValue(idCh1 + i) + 1024)/2048
		local wBar = 4
		if getv < 0 then
			getv = 0
		elseif getv > 1 then
			getv = 1
		else
			wBar = 2
		end
		local xBar = getv*2*bl.side - wBar/2
		lcd.drawFilledRectangle (x + xBar, y, wBar, bl.hBar, flagsColor)
		y = y + bl.dy
	end

	-----------------------------
	-- Alerts
	-----------------------------
	bl = blocks ['alerts']
	x = wgt.zone.x + bl.x
	y = wgt.zone.y + bl.y
	if idchArmed and getValue (idchArmed) > 0 then
		lcd.drawText (wgt.zone.x + wgt.zone.w - 5, y, "motor armed!", RIGHT + bl.font +  BLINK + INVERS)
	end

end

return { name=WGTNAME, options=defaultOptions, create=create, update=update, refresh=refresh, background=background }
