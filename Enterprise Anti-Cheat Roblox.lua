local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local SETTINGS = {
    ADMINS = {game.CreatorId},
    WALK_SPEED_LIMIT = 16,
    JUMP_POWER_LIMIT = 50,
    SPEED_TOLERANCE = 5,
    TELEPORT_THRESHOLD = 45,
    MAX_FLY_TIME = 2.5,
    VIOLATIONS_TO_KICK = 5,
    VIOLATIONS_TO_BAN = 15,
    ALLOW_AUTO_BAN = false,
    LOG_DATASTORE_NAME = "AC_LOGS_V1",
    LOG_BUFFER_FLUSH_INTERVAL = 60,
    LOG_BUFFER_MAX = 200,
}

local GlobalBanStore = DataStoreService:GetDataStore("AC_HARDENED_V12")
local LogsStore = DataStoreService:GetDataStore(SETTINGS.LOG_DATASTORE_NAME)
local PlayerStats = {}
local ActiveTokens = {}
local LastRemoteTimes = {}
local LogBuffer = {}

local function _isAdmin(player)
    for _, id in pairs(SETTINGS.ADMINS) do
        if player.UserId == id then return true end
    end
    return false
end

local function _applyBan(targetId, targetName, reason)
    local data = {UserId = targetId, Reason = reason, Date = os.date("%x")}
    pcall(function() GlobalBanStore:SetAsync("BAN_" .. targetId, data) end)
    local player = Players:GetPlayerByUserId(targetId)
    if player then player:Kick("\n[SECURITY SYSTEM]\nViolation: " .. reason) end
end

local function _logEvent(entry)
    table.insert(LogBuffer, entry)
    if #LogBuffer > SETTINGS.LOG_BUFFER_MAX then table.remove(LogBuffer, 1) end
end

local function _flushLogs()
    if #LogBuffer == 0 then return end
    local copy = LogBuffer
    LogBuffer = {}
    pcall(function()
        local key = "LOGS_" .. tostring(os.time()) .. "_" .. tostring(math.random(1, 1000000))
        LogsStore:SetAsync(key, copy)
    end)
end

task.spawn(function()
    while true do
        task.wait(SETTINGS.LOG_BUFFER_FLUSH_INTERVAL)
        _flushLogs()
    end
end)

local SecureRemote = Instance.new("RemoteEvent")
SecureRemote.Name = HttpService:GenerateGUID(false)
SecureRemote.Parent = ReplicatedStorage

SecureRemote.OnServerEvent:Connect(function(player, token, action, data)
    if not player or not player.UserId then return end
    if ActiveTokens[player.UserId] ~= token then
        _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = action or "Unknown", Reason = "TokenMismatch"})
        return
    end
    local now = tick()
    LastRemoteTimes[player.UserId] = LastRemoteTimes[player.UserId] or 0
    if now - LastRemoteTimes[player.UserId] < 0.08 then return end
    LastRemoteTimes[player.UserId] = now
    if action == "ReportInjection" then
        _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = action, Data = data})
        return
    end
    if action == "Heartbeat" then
        local stats = PlayerStats[player.UserId]
        if stats then
            stats.LastHeartbeat = now
            if type(data) == "table" then
                stats.ClientReported = {WalkSpeed = data.WalkSpeed, JumpPower = data.JumpPower, Position = data.Position, Time = os.time()}
                local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    if stats.ClientReported.WalkSpeed and stats.ClientReported.WalkSpeed > SETTINGS.WALK_SPEED_LIMIT + SETTINGS.SPEED_TOLERANCE then
                        _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = "ClientWalkSpeedHigh", Reported = stats.ClientReported.WalkSpeed})
                    end
                    if stats.ClientReported.JumpPower and stats.ClientReported.JumpPower > SETTINGS.JUMP_POWER_LIMIT + 10 then
                        _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = "ClientJumpHigh", Reported = stats.ClientReported.JumpPower})
                    end
                end
            end
        end
    end
end)

local function _processMovement(player, dt)
    if _isAdmin(player) then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (root and hum and hum.Health > 0) then return end
    local stats = PlayerStats[player.UserId]
    if not stats then return end
    local currentPos = root.Position
    local lastPos = stats.LastPos or currentPos
    local distance = (currentPos - lastPos).Magnitude
    local ping = player:GetNetworkPing()
    local serverMax = (hum.WalkSpeed + SETTINGS.SPEED_TOLERANCE) * dt + (ping * 0.5)
    local flagged = false
    if distance > SETTINGS.TELEPORT_THRESHOLD then
        _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = "TeleportSuspect", Distance = distance, ServerMax = serverMax})
        stats.Violations = stats.Violations + 2
        flagged = true
    elseif distance > serverMax and distance > 2 then
        _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = "SpeedSuspect", Distance = distance, ServerMax = serverMax})
        stats.Violations = stats.Violations + 1
        flagged = true
    end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Flying then
        stats.AirTime = stats.AirTime + dt
        if stats.AirTime > SETTINGS.MAX_FLY_TIME then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {char}
            local ray = workspace:Raycast(currentPos, Vector3.new(0, -50, 0), rayParams)
            if not ray then
                _logEvent({Time = os.time(), UserId = player.UserId, Name = player.Name, Action = "FlySuspect", AirTime = stats.AirTime})
                stats.Violations = stats.Violations + 1.5
                flagged = true
            end
        end
    else
        stats.AirTime = 0
    end
    if flagged and stats.Violations >= SETTINGS.VIOLATIONS_TO_BAN and SETTINGS.ALLOW_AUTO_BAN then
        _applyBan(player.UserId, player.Name, "Movement exploit (auto)")
    end
    stats.LastPos = currentPos
end

local function _deployClient(player)
    local token = HttpService:GenerateGUID(false)
    ActiveTokens[player.UserId] = token
    local clientCode = [[
        local r = game:GetService("ReplicatedStorage"):WaitForChild("]] .. SecureRemote.Name .. [[")
        local t = "]] .. token .. [["
        local Run = game:GetService("RunService")
        local Players = game:GetService("Players")
        local pl = Players.LocalPlayer
        Run.Heartbeat:Connect(function()
            local data = {}
            if pl and pl.Character then
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    data.WalkSpeed = hum.WalkSpeed
                    data.JumpPower = hum.JumpPower
                end
                local root = pl.Character:FindFirstChild("HumanoidRootPart")
                if root then data.Position = root.Position end
            end
            r:FireServer(t, "Heartbeat", data)
        end)
    ]]
    local s = Instance.new("LocalScript")
    s.Name = "CoreService"
    s.Source = clientCode
    s.Parent = player:WaitForChild("PlayerGui")
end

Players.PlayerAdded:Connect(function(player)
    local banned = nil
    pcall(function() banned = GlobalBanStore:GetAsync("BAN_" .. player.UserId) end)
    if banned then player:Kick("\nBanned: " .. banned.Reason) return end
    PlayerStats[player.UserId] = {LastPos = nil, Violations = 0, AirTime = 0, LastHeartbeat = tick(), ClientReported = nil}
    _deployClient(player)
    player.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart")
        PlayerStats[player.UserId].LastPos = root.Position
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerStats[player.UserId] = nil
    ActiveTokens[player.UserId] = nil
    LastRemoteTimes[player.UserId] = nil
end)

RunService.Heartbeat:Connect(function(dt)
    for _, player in pairs(Players:GetPlayers()) do
        pcall(function() _processMovement(player, dt) end)
    end
end)
