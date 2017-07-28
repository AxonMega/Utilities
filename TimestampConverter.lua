--scripted by AxonMega

--[[

This module returns the table Converter containing the following functions:

table time(int timestamp = time())

	Returns a table containing the following fields:
	-hour: an integer 0 or more
	-min: an integer 0-59
	-sec: an integer 0-59
	-time: a string with the format hour:min:sec

table date(int timestamp = os.time(), bool isdst = false)

	Returns a table containing the following fields:
	-year: an integer 1970 or more
	-month: an integer 1-12
	-day: an integer 1-31
	-dotw: an integer 1-7
	-hour: an integer 0-23
	-min: an integer 0-59
	-sec: an integer 0-59
	-date: a string with the format month/day/year
	-time: a string with the format hour:min:sec
	-isdst: the boolean you inputted as the second argument for this function
	If isdst is true, then the timestamp will be shifted forward by an hour.
	
]]

local Converter = {}

local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

local function strWith0(number)
	local str = tostring(number)
	if #str == 1 then
		return "0" .. str
	else
		return str
	end
end

local function daysThisYear(year)
	if year%4 == 0 and (year%100 ~= 0 or year%400 == 0) then
		return 366
	else
		return 365
	end
end

local function combine(t1, t2)
	local new = {}
	for key, value in pairs(t1) do
		new[key] = value
	end
	for key, value in pairs(t2) do
		new[key] = value
	end
	return new
end

function Converter.time(timestamp)
	timestamp = timestamp or time()
	assert(type(timestamp) == "number" and timestamp >= 0, "You were supposed to input a positive integer for converter.time!")
	timestamp = math.floor(timestamp)
	if timestamp == 0 then
		return {time = "00:00:00", hour = 0, min = 0, sec = 0}
	end
	local hour = math.floor(timestamp/3600)
	local min = math.floor(timestamp/60%60)
	local sec = math.floor(timestamp%60)
	local time = strWith0(hour) .. ":" .. strWith0(min) .. ":" .. strWith0(sec)
	return {time = time, hour = hour, min = min, sec = sec}
end

function Converter.date(timestamp, isdst)
	timestamp = timestamp or os.time()
	assert(type(timestamp) == "number" and timestamp >= 0,
		"You were supposed to input a positive integer for the first argument of converter.date!")
	assert(type(isdst) == "boolean" or not isdst,
		"You were supposed to input a boolean for the second argument of converter.date!")
	timestamp = math.floor(timestamp)
	if isdst then
		timestamp = timestamp + 3600
	else
		isdst = false
	end
	if timestamp == 0 then
		return combine({date = "1/1/70", month = 1, day = 1, year = 1970, dotw = 5, isdst = false}, Converter.time(0))
	end
	local year = 1970
	local totalDays = math.ceil(timestamp/86400)
	local day = totalDays
	local month = 0	
    while day >= daysThisYear(year) do
		day = day - daysThisYear(year)
		year = year + 1
	end
	for i, daysThisMonth in ipairs(daysPerMonth) do
			if i == 2 and daysThisYear(year) == 366 then
			daysThisMonth = 29
		end
		if day - daysThisMonth <= 0 then
			month = i
			break
		end
		day = day - daysThisMonth
	end
	if day == 0 then
		year = year - 1
		day = 31
		month = 12
	end
	local date = tostring(month) .. "/" .. tostring(day) .. "/" .. tostring(year):sub(3)
	local dotw= (totalDays + 3)%7 + 1
	local time = Converter.time(timestamp%86400)
	return combine({date = date, month = month, day = day, year = year, dotw = dotw, isdst = isdst}, time)
end

return Converter
