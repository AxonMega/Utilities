--scripted by AxonMega

local methods = {}
local reservedNames = {
	connection = true, comFunc = true, comEvent = true, intEvent = true, intFunc = true, mode = true, client = true,
	myScript = true, otherScript = true, send = true, sendWR = true, getVars = true, setVars = true, clearVars = true,
	setReceive = true, setReceiveWR = true, setOnVarChanged = true, getPing = true, receiveCon = true, onVarChanged = true
} 

local function getData(com)
	return getmetatable(com).__index
end

local function intSetVars(data, vars)
	local onVarChanged = data.onVarChanged
	for name, value in pairs(vars) do
		data[name] = value
		if onVarChanged then
			onVarChanged(name)
		end
	end
end

local function intClearVars(data)
	local onVarChanged = data.onVarChanged
	for name in pairs(data) do
		if not reservedNames[name] then
			data[name] = nil
			if onVarChanged then
				onVarChanged(name)
			end
		end
	end
end

local function onIntEventMain(data, task, ...)
	if task == "set" then
		local name, value = ...
		data[name] = value
		if data.onVarChanged then
			data.onVarChanged(name, value)
		end
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
	assert(type(vars) == "table", "you were supposed to input a table!")
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

function methods:setReceive(func)
	assert(type(func) == "function", "you were supposed to input a function!")
	local data = getData(self)
	if data.receiveCon then
		data.receiveCon:Disconnect()
	end
	if self.mode == "client" then
		data.receiveCon = self.comEvent.OnClientEvent:Connect(func)
	elseif self.mode == "server" then
		local function onEvent(_, ...)
			func(...)
		end
		data.receiveCon = self.comEvent.OnServerEvent:Connect(onEvent)
	end
end

function methods:setReceiveWR(func)
	assert(type(func) == "function", "you were supposed to input a function!")
	if self.mode == "client" then
		self.comFunc.OnClientInvoke = func
	elseif self.mode == "server" then
		local function onInvoke(_, ...)
			return func(...)
		end
		self.comFunc.OnServerInvoke = onInvoke
	end
end

function methods:setOnVarChanged(func)
	assert(type(func) == "function", "you were supposed to input a function!")
	getData(self).onVarChanged = func
end

function methods:getPing()
	if self.mode == "client" then
		return elapsedTime() - self.intFunc:InvokeServer()
	elseif self.mode == "server" then
		return elapsedTime() - self.intFunc:InvokeClient(self.client)
	end
end

function methods:__newindex(name, value)
	assert(type(name) == "string", "all field names must be strings!")
	assert(not reservedNames[name], "the field '" .. name .."' cannot be overwritten!")
	getData(self)[name] = value
	if self.mode == "client" then
		self.intEvent:FireServer("set", name, value)
	elseif self.mode == "server" then
		self.intEvent:FireClient(self.client, "set", name, value)
	end
end

local function createCom(myScript, otherScript, funcs)
	assert(typeof(myScript) == "Instance" and myScript:IsA("Script"), 
		"you were supposed to input a script for the first argument!")
	assert(typeof(otherScript) == "Instance" and otherScript:IsA("Script"), 
		"you were supposed to input a script for the second argument!")
	assert(myScript.ClassName ~= otherScript.ClassName, "You were supposed to input one script and one local script!")
	assert(not funcs or type(funcs) == "table", "you were supposed to input a table or nothing for the third argument!")
	local com = {}
	local data = {myScript = myScript, otherScript = otherScript}
	for name, method in pairs(methods) do
		if name ~= "__newindex" then
			data[name] = method
		end
	end
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
				assert(type(receive) == "function", "the field 'receive' was supposed to be a function or empty!")
				data.receiveCon = data.comEvent.OnClientEvent:Connect(receive)
			end
			local receiveWR = funcs.receiveWR
			if receiveWR then
				assert(type(receiveWR) == "function", "the field 'receiveWR' was supposed to be a function or empty!")
				data.comFunc.OnClientInvoke = receiveWR
			end
			local onVarChanged = funcs.onVarChanged
			if onVarChanged then
				assert(type(onVarChanged) == "function", "the field 'receive' was supposed to be a function or empty!")
				 data.onVarChanged = onVarChanged
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
				assert(type(receive) == "function", "the field 'receive' was supposed to be a function or empty!")
				local function onEvent(_, ...)
					receive(...)
				end
				data.receiveCon = comEvent.OnServerEvent:Connect(onEvent)
			end
			local receiveWR = funcs.receiveWR
			if receiveWR then
				assert(type(receiveWR) == "function", "the field 'receiveWR' was supposed to be a function or empty!")
				local function onInvoke(_, ...)
					return receiveWR(...)
				end
				comFunc.OnServerInvoke = onInvoke
			end
			local onVarChanged = funcs.onVarChanged
			if onVarChanged then
				assert(type(onVarChanged) == "function", "the field 'receive' was supposed to be a function or empty!")
				data.onVarChanged = onVarChanged
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
