local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SETTINGS = {
    ADMINS = {game.CreatorId},
    WALK_SPEED_LIMIT = 16,
    JUMP_POWER_LIMIT = 50,
    SPEED_TOLERANCE = 5,
    TELEPORT_THRESHOLD = 45, 
    MAX_FLY_TIME = 2.5,
    VIOLATIONS_TO_KICK = 5,
    VIOLATIONS_TO_BAN = 15,
}

local GlobalBanStore = DataStoreService:GetDataStore("AC_HARDENED_V12")
local PlayerStats = {}
local ActiveTokens = {}

local function _isAdmin(player)
    for _, id in pairs(SETTINGS.ADMINS) do
        if player.UserId == id then return true end
    end
    return false
end

local function _applyBan(targetId, targetName, reason)
    local data = {
        UserId = targetId,
        Reason = reason,
        Date = os.date("%x"),
    }
    pcall(function()
        GlobalBanStore:SetAsync("BAN_" .. targetId, data)
    end)
    
    local player = Players:GetPlayerByUserId(targetId)
    if player then
        player:Kick("\n[SECURITY SYSTEM]\nViolation: " .. reason)
    end
end

local SecureRemote = Instance.new("RemoteEvent")
SecureRemote.Name = game:GetService("HttpService"):GenerateGUID(false)
SecureRemote.Parent = ReplicatedStorage

SecureRemote.OnServerEvent:Connect(function(player, token, action, data)
    if ActiveTokens[player.UserId] ~= token then
        _applyBan(player.UserId, player.Name, "Protocol Desync")
        return
    end

    if action == "ReportInjection" then
        _applyBan(player.UserId, player.Name, "Internal Environment Tamper")
    elseif action == "Heartbeat" then
        if PlayerStats[player.UserId] then
            PlayerStats[player.UserId].LastHeartbeat = tick()
        end
    end
end)

local function _processMovement(player, dt)
    if _isAdmin(player) then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    
    if root and hum and hum.Health > 0 then
        local stats = PlayerStats[player.UserId]
        if not stats then return end

        local currentPos = root.Position
        local distance = (currentPos - stats.LastPos).Magnitude
        
        local ping = player:GetNetworkPing()
        local maxDist = (hum.WalkSpeed + SETTINGS.SPEED_TOLERANCE) * dt + (ping * 0.5)

        if distance > SETTINGS.TELEPORT_THRESHOLD then
            root.CFrame = CFrame.new(stats.LastPos)
            stats.Violations += 2
        elseif distance > maxDist and distance > 2 then
            stats.Violations += 1
        end

        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Flying then
            stats.AirTime += dt
            if stats.AirTime > SETTINGS.MAX_FLY_TIME then
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {char}
                local ray = workspace:Raycast(currentPos, Vector3.new(0, -50, 0), rayParams)
                if not ray then
                    stats.Violations += 1.5
                end
            end
        else
            stats.AirTime = 0
        end

        if stats.Violations >= SETTINGS.VIOLATIONS_TO_BAN then
            _applyBan(player.UserId, player.Name, "Movement exploit (V12-L)")
        end

        stats.LastPos = currentPos
    end
end

local function _deployClient(player)
    local token = game:GetService("HttpService"):GenerateGUID(false)
    ActiveTokens[player.UserId] = token
    
    local clientCode = [[
        local r = game:GetService("ReplicatedStorage"):WaitForChild("]] .. SecureRemote.Name .. [[")
        local t = "]] .. token .. [["
        
        game:GetService("RunService").Heartbeat:Connect(function()
            local mt = getrawmetatable(game)
            if mt and (mt.__index ~= nil or mt.__namecall ~= nil) then
            end
        end)

        while task.wait(5) do
            r:FireServer(t, "Heartbeat")
        end
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

    PlayerStats[player.UserId] = {
        LastPos = Vector3.new(0,0,0),
        Violations = 0,
        AirTime = 0,
        LastHeartbeat = tick()
    }
    
    _deployClient(player)
    
    player.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart")
        PlayerStats[player.UserId].LastPos = root.Position
    end)
end)

RunService.Heartbeat:Connect(function(dt)
    for _, player in pairs(Players:GetPlayers()) do
        _processMovement(player, dt)
    end
end)