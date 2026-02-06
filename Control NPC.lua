-- NPC CONTROL V2 - Main Script
-- GitHub: https://github.com/YOUR_USERNAME/npc-control-v2

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Configuration
local CONFIG = {
    Version = "2.0.1",
    Author = "DyronAI",
    UpdateURL = "https://github.com/YOUR_USERNAME/npc-control-v2"
}

-- Main Controller
local NPCControl = {
    Controlled = {},
    UI = nil,
    Active = true
}

-- Get player references
local Player = Players.LocalPlayer
local PlayerChar = Player.Character or Player.CharacterAdded:Wait()
local PlayerRoot = PlayerChar:WaitForChild("HumanoidRootPart")

-- Safety: Check if model is player
function NPCControl:IsPlayer(model)
    if not model then return true end
    if model == PlayerChar then return true end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character == model then return true end
    end
    return false
end

-- Find NPCs around player
function NPCControl:ScanNPCs(radius, filter)
    local npcs = {}
    local center = PlayerRoot.Position
    
    for _, model in pairs(workspace:GetChildren()) do
        if model:IsA("Model") and not self:IsPlayer(model) then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart") or 
                         model:FindFirstChild("Torso") or
                         model:FindFirstChild("UpperTorso")
            
            if humanoid and root then
                local distance = (root.Position - center).Magnitude
                
                if not radius or distance <= radius then
                    local npcName = model.Name:lower()
                    local include = true
                    
                    if filter then
                        include = npcName:find("npc") or 
                                 npcName:find("enemy") or 
                                 npcName:find("bot") or
                                 npcName:find("mob") or
                                 npcName:find("guard")
                    end
                    
                    if include then
                        table.insert(npcs, {
                            Model = model,
                            Humanoid = humanoid,
                            Root = root,
                            Distance = distance
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(npcs, function(a, b)
        return a.Distance < b.Distance
    end)
    
    return npcs
end

-- Get nearest NPC
function NPCControl:GetNearestNPC(maxDistance)
    maxDistance = maxDistance or 100
    local npcs = self:ScanNPCs(maxDistance, true)
    return npcs[1]
end

-- Control NPC function
function NPCControl:TakeControl(npcData)
    if not npcData then return nil end
    
    local humanoid = npcData.Humanoid
    local root = npcData.Root
    
    -- Save original state
    local original = {
        WalkSpeed = humanoid.WalkSpeed,
        JumpPower = humanoid.JumpPower,
        AutoRotate = humanoid.AutoRotate,
        PlatformStand = humanoid.PlatformStand
    }
    
    -- Create controller
    local controller = {
        NPC = npcData.Model,
        Humanoid = humanoid,
        Root = root,
        Original = original,
        Active = true,
        
        -- Move NPC to position
        Move = function(position)
            if not controller.Active then return false end
            return pcall(function()
                humanoid:MoveTo(position)
            end)
        end,
        
        -- Make NPC follow target
        Follow = function(target, followDistance)
            followDistance = followDistance or 8
            if not target then return nil end
            
            local following = true
            local connection
            
            connection = RunService.Heartbeat:Connect(function()
                if not controller.Active or not humanoid.Parent then
                    following = false
                    if connection then connection:Disconnect() end
                    return
                end
                
                local targetPos = target.Position
                local npcPos = root.Position
                local distance = (targetPos - npcPos).Magnitude
                
                if distance > followDistance then
                    local direction = (targetPos - npcPos).Unit
                    local movePos = npcPos + (direction * math.min(4, distance - followDistance))
                    humanoid:MoveTo(movePos)
                    humanoid.WalkSpeed = 16
                else
                    humanoid.WalkSpeed = 0
                end
            end)
            
            return {
                Stop = function()
                    following = false
                    if connection then connection:Disconnect() end
                    humanoid.WalkSpeed = 0
                end
            }
        end,
        
        -- Teleport NPC
        Teleport = function(cframe)
            if not controller.Active then return false end
            return pcall(function()
                root.CFrame = cframe
                root.Velocity = Vector3.new(0, 0, 0)
                root.RotVelocity = Vector3.new(0, 0, 0)
            end)
        end,
        
        -- Set walk speed
        SetSpeed = function(speed)
            if not controller.Active then return false end
            humanoid.WalkSpeed = speed
            return true
        end,
        
        -- Release control
        Release = function()
            controller.Active = false
            humanoid.WalkSpeed = original.WalkSpeed
            humanoid.AutoRotate = original.AutoRotate
            humanoid.JumpPower = original.JumpPower
            humanoid.PlatformStand = original.PlatformStand
            
            NPCControl.Controlled[npcData.Model] = nil
        end
    }
    
    -- Apply initial control settings
    humanoid.AutoRotate = false
    humanoid.WalkSpeed = 0
    
    -- Store controller
    self.Controlled[npcData.Model] = controller
    
    print("[NPC Control] Controlled:", npcData.Model.Name)
    return controller
end

-- Control all NPCs in radius
function NPCControl:ControlAll(radius)
    radius = radius or 100
    local npcs = self:ScanNPCs(radius, true)
    local controllers = {}
    
    for _, npc in ipairs(npcs) do
        local controller = self:TakeControl(npc)
        if controller then
            table.insert(controllers, controller)
        end
        task.wait(0.05) -- Prevent lag
    end
    
    return controllers
end

-- Create control UI
function NPCControl:CreateUI()
    -- Remove old UI if exists
    local oldUI = Player.PlayerGui:FindFirstChild("NPCControlV2UI")
    if oldUI then oldUI:Destroy() end
    
    -- Create new UI
    local gui = Instance.new("ScreenGui")
    gui.Name = "NPCControlV2UI"
    gui.ResetOnSpawn = false
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 300, 0, 380)
    main.Position = UDim2.new(0, 20, 0, 120)
    main.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    main.BackgroundTransparency = 0.15
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Text = "NPC CONTROL V2"
    title.TextColor3 = Color3.fromRGB(0, 255, 255)
    title.Size = UDim2.new(1, 0, 0, 45)
    title.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    title.Font = Enum.Font.SciFi
    title.TextSize = 22
    title.Parent = main
    
    -- Version
    local version = Instance.new("TextLabel")
    version.Text = "v" .. CONFIG.Version
    version.Size = UDim2.new(0, 60, 0, 20)
    version.Position = UDim2.new(1, -65, 0, 2)
    version.BackgroundTransparency = 1
    version.TextColor3 = Color3.fromRGB(150, 150, 150)
    version.Font = Enum.Font.Code
    version.TextSize = 12
    version.Parent = title
    
    -- Status
    local status = Instance.new("TextLabel")
    status.Text = "Status: Ready"
    status.Size = UDim2.new(1, 0, 0, 30)
    status.Position = UDim2.new(0, 0, 0, 50)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(0, 255, 0)
    status.Font = Enum.Font.Code
    status.TextSize = 14
    status.Parent = main
    
    -- Buttons container
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 270)
    container.Position = UDim2.new(0, 10, 0, 85)
    container.BackgroundTransparency = 1
    container.Parent = main
    
    -- Button template
    local function createButton(text, color, callback)
        local btn = Instance.new("TextButton")
        btn.Text = text
        btn.Size = UDim2.new(1, 0, 0, 45)
        btn.Position = UDim2.new(0, 0, 0, (#container:GetChildren() * 50))
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.AutoButtonColor = true
        
        btn.MouseButton1Click:Connect(function()
            status.Text = ">> " .. text
            task.spawn(callback)
        end)
        
        btn.Parent = container
        return btn
    end
    
    -- Control Nearest NPC Button
    createButton(Color3.fromRGB(65, 105, 225), "CONTROL NEAREST NPC", function()
        local nearest = self:GetNearestNPC(80)
        if nearest then
            local controller = self:TakeControl(nearest)
            if controller then
                controller.Follow(PlayerRoot, 10)
                
                -- Notification
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "NPC Controlled",
                    Text = "Now controlling: " .. nearest.Model.Name,
                    Duration = 3,
                    Icon = "rbxassetid://4483345998"
                })
            end
        else
            status.Text = "No NPCs found nearby"
        end
    end)
    
    -- Control All NPCs Button
    createButton(Color3.fromRGB(220, 20, 60), "CONTROL ALL NEARBY", function()
        local controllers = self:ControlAll(100)
        status.Text = "Controlling " .. #controllers .. " NPCs"
        
        -- Make all follow player
        for _, ctrl in ipairs(controllers) do
            if ctrl.Follow then
                ctrl.Follow(PlayerRoot, 15)
            end
        end
    end)
    
    -- Freeze All Button
    createButton(Color3.fromRGB(30, 144, 255), "FREEZE ALL NPCS", function()
        local npcs = self:ScanNPCs(200, true)
        for _, npc in ipairs(npcs) do
            pcall(function()
                npc.Humanoid.WalkSpeed = 0
                npc.Humanoid.JumpPower = 0
            end)
        end
        status.Text = "Frozen " .. #npcs .. " NPCs"
    end)
    
    -- Release All Button
    createButton(Color3.fromRGB(50, 205, 50), "RELEASE ALL NPCS", function()
        for _, controller in pairs(self.Controlled) do
            if controller.Release then
                controller.Release()
            end
        end
        self.Controlled = {}
        status.Text = "Released all NPCs"
    end)
    
    -- Debug Info Button
    createButton(Color3.fromRGB(255, 140, 0), "DEBUG SCAN", function()
        local npcs = self:ScanNPCs(150, false)
        status.Text = "Found " .. #npcs .. " models"
        
        print("=== NPC Control V2 Debug ===")
        for i, npc in ipairs(npcs) do
            print(string.format("%d. %s | Dist: %.1f", i, npc.Model.Name, npc.Distance))
        end
        print("=============================")
    end)
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Text = "X"
    closeBtn.Size = UDim2.new(0, 35, 0, 35)
    closeBtn.Position = UDim2.new(1, -35, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.TextColor3 = Color3.white
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    
    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
        status.Text = "UI Closed"
    end)
    
    closeBtn.Parent = main
    
    -- Toggle UI key (Right Control)
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if input.KeyCode == Enum.KeyCode.RightControl and not gameProcessed then
            main.Visible = not main.Visible
        end
    end)
    
    gui.Parent = Player.PlayerGui
    self.UI = gui
    
    return gui
end

-- Initialize system
function NPCControl:Init()
    -- Wait for game to load
    repeat task.wait() until game:IsLoaded()
    task.wait(1)
    
    -- Re-get player references
    Player = Players.LocalPlayer
    PlayerChar = Player.Character or Player.CharacterAdded:Wait()
    PlayerRoot = PlayerChar:WaitForChild("HumanoidRootPart")
    
    -- Print welcome message
    print("\n" .. string.rep("=", 50))
    print("    NPC CONTROL V2 - ACTIVATED")
    print("    Version: " .. CONFIG.Version)
    print("    Player: " .. Player.Name)
    print(string.rep("=", 50))
    
    -- Create UI
    self:CreateUI()
    
    -- Setup keybinds
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- F = Control nearest NPC
        if input.KeyCode == Enum.KeyCode.F then
            local nearest = self:GetNearestNPC(60)
            if nearest then
                local ctrl = self:TakeControl(nearest)
                if ctrl then
                    ctrl.Follow(PlayerRoot, 8)
                    print("[Keybind] Controlling:", nearest.Model.Name)
                end
            end
        end
        
        -- G = Release all NPCs
        if input.KeyCode == Enum.KeyCode.G then
            for _, ctrl in pairs(self.Controlled) do
                if ctrl.Release then ctrl.Release() end
            end
            self.Controlled = {}
            print("[Keybind] Released all NPCs")
        end
        
        -- V = Freeze nearest NPC
        if input.KeyCode == Enum.KeyCode.V then
            local nearest = self:GetNearestNPC(60)
            if nearest then
                nearest.Humanoid.WalkSpeed = 0
                print("[Keybind] Frozen:", nearest.Model.Name)
            end
        end
    end)
    
    -- Auto-scan and display info
    task.spawn(function()
        while task.wait(10) do
            if self.Active then
                local npcs = self:ScanNPCs(100, true)
                if #npcs > 0 and self.UI and self.UI.Parent then
                    local status = self.UI:FindFirstChild("NPCControlV2UI")
                    if status then
                        -- Update status with NPC count
                        local label = status:FindFirstChild("StatusLabel")
                        if label then
                            label.Text = "Nearby NPCs: " .. #npcs
                        end
                    end
                end
            end
        end
    end)
    
    return self
end

-- Auto-start
NPCControl:Init()

-- Make globally accessible
getgenv().NPCControlV2 = NPCControl

-- Return controller
return NPCControl
