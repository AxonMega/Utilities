--scripted by AxonMega

local methods = {}
local reservedNames = {
	connection = true, comFunc = true, comEvent = true, intEvent = true, intFunc = true, mode = true, client = true,
	myScript = true, otherScript = true, send = true, sendWR = true, getVars = true, setVars = true, clearVars = true,
	getPing = true
} 

local function err(bamboozlement)
	error("A bamboozlement has occured with the communication module: " .. bamboozlement)
end

local function isScript(thing, argNum)
	if typeof(thing) ~= "Instance" or not thing:IsA("Script") then
		err("you were supposed to input a script or a local script for the " .. argNum .. " argument!")
	end
end

local function isFunc(thing, field)
	if type(thing) ~= "function" then
		err("the field '" .. field .. "' was supposed to be a function or empty!")
	end
end

local function getData(com)
	return getmetatable(com).__index
end

local function intSetVars(data, vars)
	for name, value in pairs(vars) do
		data[name] = value
	end
end

local function intClearVars(data)
	for name in pairs(data) do
		if not reservedNames[name] then
			data[name] = nil
		end
	end
end

local function onIntEventMain(data, task, ...)
	if task == "set" then
		local name, value = ...
		data[name] = value
	elseif task == "setM" then
		intSetVars(data, ...)
	elseif task == "clear" then
		intClearVars(data)
	end
end

function methods:send(...)
	if self.mode == "client" then
		self.comEvent:FireServer(...)
	elseif self.mode == "server" then
		self.comEvent:FireClient(self.client, ...)
	end
end

function methods:sendWR(...)
	if self.mode == "client" then
		return self.comFunc:InvokeServer(...)
	elseif self.mode == "server" then
		return self.comFunc:InvokeClient(self.client, ...)
	end
end

function methods:getVars()
	local filteredData = {}
	for name, value in pairs(getData(self)) do
		if not reservedNames[name] then
			filteredData[name] = value
		end
	end
	return filteredData
end

function methods:setVars(vars)
	if type(vars) ~= "table" then
		err("you were supposed to input a table!")
	end
	for name in pairs(vars) do
		if reservedNames[name] or type(name) ~= "string" then
			vars[name] = nil
		end
	end
	intSetVars(getData(self), vars)
	if self.mode == "client" then
		self.intEvent:FireServer("setM", vars)
	elseif self.mode == "server" then
		self.intEvent:FireClient(self.client, "setM", vars)
	end
end

function methods:clearVars()
	intClearVars(getData(self))
	if self.mode == "client" then
		self.intEvent:FireServer("clear")
	elseif self.mode == "server" then
		self.intEvent:FireClient(self.client, "clear")
	end
end

function methods:getPing()
	local now = elapsedTime()
	if self.mode == "client" then
		return self.intFunc:InvokeServer() - now
	elseif self.mode == "server" then
		return self.intFunc:InvokeClient(self.client) - now
	end
end

function methods:__newindex(name, value)
	if type(name) ~= "string" then
		err("all fields must be strings!")
	end
	if reservedNames[name] then
		err("the field '" .. name .. "' cannot be overwritten!")
	end
	getData(self)[name] = value
	if self.mode == "client" then
		self.intEvent:FireServer("set", name, value)
	elseif self.mode == "server" then
		self.intEvent:FireClient(self.client, "set", name, value)
	end
end

local function createCom(myScript, otherScript, funcs)
	isScript(myScript, "first")
	isScript(otherScript, "second")
	if myScript.ClassName == otherScript.ClassName then
		err("you were supposed to input one script and one local script!")
	end
	if funcs and type(funcs) ~= "table" then
		err("you were supposed to input a table or nothing for the third argument!")
	end
	local com = {}
	local data = {
		myScript = myScript, otherScript = otherScript, send = methods.send, sendWR = methods.sendWR,
		getVars = methods.getVars, setVars = methods.setVars, clearVars = methods.clearVars, getPing = methods.getPing
	}
	if myScript:IsA("LocalScript") then
		data.mode = "client"
		data.client = game.Players.LocalPlayer
		local connection = otherScript:WaitForChild("Connection")
		data.connection = connection
		data.comEvent = connection:WaitForChild("ComEvent")
		data.comFunc = connection:WaitForChild("ComFunction")
		data.intEvent = connection:WaitForChild("InternalEvent")
		data.intFunc = connection:WaitForChild("InternalFunction")
		if funcs then
			local receive = funcs.receive
			if receive then
				isFunc(receive, "receive")
				data.comEvent.OnClientEvent:Connect(receive)
			end
			local receiveWR = funcs.receiveWR
			if receiveWR then
				isFunc(receiveWR, "receiveWR")
				data.comFunc.OnClientInvoke = receiveWR
			end
		end
		local function onIntEvent(task, ...)
			onIntEventMain(data, task, ...)
		end
		data.intEvent.OnClientEvent:Connect(onIntEvent)
		data.intFunc.OnClientInvoke = elapsedTime
		data.intEvent:FireServer("connect")
		while not connection.Value do wait() end
	else
		data.mode = "server"
		local connection = Instance.new("BoolValue")
		connection.Name = "Connection"
		local comEvent = Instance.new("RemoteEvent")
		comEvent.Name = "ComEvent"
		comEvent.Parent = connection
		local comFunc = Instance.new("RemoteFunction")
		comFunc.Name = "ComFunction"
		comFunc.Parent = connection
		local intEvent = Instance.new("RemoteEvent")
		intEvent.Name = "InternalEvent"
		intEvent.Parent = connection
		local intFunc = Instance.new("RemoteFunction")
		intFunc.Name = "InternalFunction"
		intFunc.Parent = connection
		data.connection = connection
		data.comEvent = comEvent
		data.comFunc = comFunc
		data.intEvent = intEvent
		data.intFunc = intFunc
		if funcs then
			local receive = funcs.receive
			if receive then
				isFunc(receive, "receive")
				local function onEvent(_, ...)
					receive(...)
				end
				comEvent.OnServerEvent:Connect(onEvent)
			end
			local receiveWR = funcs.receiveWR
			if receiveWR then
				isFunc(receiveWR, "receiveWR")
				local function onInvoke(_, ...)
					return receiveWR(...)
				end
				comFunc.OnServerInvoke = onInvoke
			end
		end
		local function onIntEvent(player, task, ...)
			if task == "connect" then
				data.client = player
				connection.Value = true
			else
				onIntEventMain(data, task, ...)
			end
		end
		intEvent.OnServerEvent:Connect(onIntEvent)
		intFunc.OnServerInvoke = elapsedTime
		connection.Parent = myScript
		while not connection.Value do wait() end
	end
	local meta = {__index = data, __newindex = methods.__newindex}
	setmetatable(com, meta)
	return com
end

return createCom