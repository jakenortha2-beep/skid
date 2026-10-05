local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local StarterPlayer = game:GetService("StarterPlayer")
local VRService = game:GetService("VRService")
local TextChatService = game:GetService("TextChatService")

local h2o = {
        Name = "h2o",
        Version = "1.2.0",
        Author = "h2o",
        Toggles = {},
        Options = {},
        Modules = {},
        Maid = {},
        DamageListeners = {},
}

local LocalPlayer = Players.LocalPlayer

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local loaded, Library, ThemeManager, SaveManager = pcall(function()
        local function fetch(path)
                local chunk = loadstring(game:HttpGet(repo .. path))
                assert(chunk, "failed to compile: " .. path)
                return chunk()
        end
        return fetch("Library.lua"), fetch("addons/ThemeManager.lua"), fetch("addons/SaveManager.lua")
end)

if not loaded then
        return
end

Library.ShowToggleFrameInKeybinds = true

local Toggles = Library.Toggles
local Options = Library.Options

do
        local startupState = { rerun = false, silent = false, url = "", path = "" }
        h2o.StartupState = startupState
        local writeFileFn = typeof(writefile) == "function" and writefile or nil
        local readFileFn = typeof(readfile) == "function" and readfile or nil
        local isFileFn = typeof(isfile) == "function" and isfile or nil
        local isFolderFn = typeof(isfolder) == "function" and isfolder or nil
        local makeFolderFn = typeof(makefolder) == "function" and makefolder or nil
        local queueTeleportFn = (typeof(queue_on_teleport) == "function" and queue_on_teleport)
                or (typeof(queueonteleport) == "function" and queueonteleport)
                or nil
        h2o.QueueTeleport = queueTeleportFn and function(code)
                pcall(queueTeleportFn, code)
        end or nil
        pcall(function()
                if not makeFolderFn then
                        return
                end
                if isFolderFn then
                        if not isFolderFn("h2o") then
                                makeFolderFn("h2o")
                        end
                        if not isFolderFn("h2o/main") then
                                makeFolderFn("h2o/main")
                        end
                else
                        makeFolderFn("h2o/main")
                end
        end)
        pcall(function()
                if not readFileFn then
                        return
                end
                if isFileFn and not isFileFn("h2o/main/startup.json") then
                        return
                end
                local decoded = HttpService:JSONDecode(readFileFn("h2o/main/startup.json"))
                if type(decoded) ~= "table" then
                        return
                end
                if type(decoded.rerun) == "boolean" then
                        startupState.rerun = decoded.rerun
                end
                if type(decoded.silent) == "boolean" then
                        startupState.silent = decoded.silent
                end
                if type(decoded.url) == "string" then
                        startupState.url = decoded.url
                end
                if type(decoded.path) == "string" then
                        startupState.path = decoded.path
                end
        end)
        pcall(function()
                local forced = getgenv and getgenv().H2O_SOURCE_URL
                if type(forced) == "string" and #forced > 8 then
                        startupState.url = forced
                end
        end)
        h2o.SourceCached = false
        local sourceSignature = "h2o/main/source.lua"
        local function captureSource()
                local candidates = {}
                pcall(function()
                        if typeof(getcallingscript) == "function" then
                                local sc = getcallingscript()
                                if sc then
                                        candidates[#candidates + 1] = sc
                                end
                        end
                end)
                pcall(function()
                        if typeof(script) == "Instance" then
                                candidates[#candidates + 1] = script
                        end
                end)
                pcall(function()
                        local listFn = typeof(getloadedscripts) == "function" and getloadedscripts
                                or (typeof(getscripts) == "function" and getscripts or nil)
                        if listFn then
                                local list = listFn()
                                if type(list) == "table" then
                                        for i, sc in ipairs(list) do
                                                if i > 200 then
                                                        break
                                                end
                                                candidates[#candidates + 1] = sc
                                        end
                                end
                        end
                end)
                for _, sc in ipairs(candidates) do
                        pcall(function()
                                if h2o.SourceCached or not writeFileFn then
                                        return
                                end
                                local src = sc.Source
                                if type(src) == "string" and #src > 1000 and src:find(sourceSignature, 1, true) then
                                        writeFileFn(sourceSignature, src)
                                        h2o.SourceCached = true
                                end
                        end)
                        if h2o.SourceCached then
                                break
                        end
                end
                return h2o.SourceCached
        end
        h2o.CaptureSource = captureSource
        captureSource()
        local function saveStartupState()
                if not writeFileFn then
                        return
                end
                pcall(function()
                        writeFileFn("h2o/main/startup.json", HttpService:JSONEncode(startupState))
                end)
        end
        h2o.SaveStartupState = saveStartupState
        local function buildRerunBootstrap()
                local parts = {}
                local path = startupState.path
                local url = startupState.url
                if type(path) == "string" and #path > 0 then
                        local safe = path:gsub("['%\\]", "")
                        parts[#parts + 1] = ("pcall(function() if type(isfile)~='function' or isfile('%s') then src=(readfile('%s')) end end"):format(safe, safe)
                end
                if type(url) == "string" and #url > 8 then
                        local safe = url:gsub("['%\\]", "")
                        parts[#parts + 1] = ("pcall(function() if not src then src=(game:HttpGet('%s')) end end"):format(safe)
                end
                parts[#parts + 1] = ("if not src and type(readfile)=='function' then pcall(function() local c=readfile('%s') if type(c)=='string' and #c>50 then src=c end end) end"):format(sourceSignature)
                parts[#parts + 1] = "if src and #src>50 then local f=loadstring(src) if f then f() end end"
                return "pcall(function() local src=nil " .. table.concat(parts, " ") .. " end)"
        end
        local function isLikelyH2oSource(body)
                return type(body) == "string" and #body > 100
                        and (body:find(sourceSignature, 1, true) ~= nil or body:find("loadstring", 1, true) ~= nil)
        end
        local function setRerunSource(text)
                text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                local status
                if text == "" then
                        startupState.path = ""
                        startupState.url = ""
                        status = "rerun source cleared"
                elseif text:sub(1, 4):lower() == "http" then
                        local ok, body = pcall(function()
                                return game:HttpGet(text)
                        end)
                        if ok and isLikelyH2oSource(body) then
                                startupState.url = text
                                startupState.path = ""
                                if writeFileFn then
                                        pcall(writeFileFn, sourceSignature, body)
                                        h2o.SourceCached = true
                                end
                                status = "rerun source set - url (" .. #body .. " chars)"
                        else
                                status = "url fetch failed or does not look like h2o"
                        end
                elseif readFileFn and (not isFileFn or isFileFn(text)) then
                        local ok, body = pcall(readFileFn, text)
                        if ok and isLikelyH2oSource(body) then
                                startupState.path = text
                                startupState.url = ""
                                if writeFileFn then
                                        pcall(writeFileFn, sourceSignature, body)
                                        h2o.SourceCached = true
                                end
                                status = "rerun source set - file (" .. #body .. " chars)"
                        else
                                status = "file exists but does not look like h2o"
                        end
                else
                        status = "file not found - check the path"
                end
                saveStartupState()
                return status
        end
        h2o.SetRerunSource = setRerunSource
        pcall(function()
                if typeof(LocalPlayer) ~= "Instance" then
                        return
                end
                local conn = LocalPlayer.OnTeleport:Connect(function(state)
                        if h2o.Unloaded then
                                return
                        end
                        if state == Enum.TeleportState.Started and startupState.rerun and h2o.QueueTeleport then
                                h2o.QueueTeleport(buildRerunBootstrap())
                        end
                end)
                table.insert(h2o.Maid, conn)
        end)
end

local Window = Library:CreateWindow({
        Title = h2o.Name,
        Footer = ("h2o | v%s"):format(h2o.Version),
        NotifySide = "Right",
        ShowCustomCursor = true,
        Center = true,
        AutoShow = not h2o.StartupState.silent,
})

h2o.Tabs = {
        combat = Window:AddTab("combat", "crosshair"),
        world = Window:AddTab("world", "globe"),
        esp = Window:AddTab("esp", "eye"),
        visuals = Window:AddTab("visuals", "sparkles"),
        character = Window:AddTab("character", "person-standing"),
        misc = Window:AddTab("misc", "puzzle"),
        settings = Window:AddTab("settings", "settings"),
}

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind", "startup_rerun", "startup_silent", "startup_source" })
ThemeManager:SetFolder(h2o.Name)
SaveManager:SetFolder(h2o.Name .. "/main")
SaveManager:BuildConfigSection(h2o.Tabs.settings)
ThemeManager:ApplyToTab(h2o.Tabs.settings)

Library:OnUnload(function()
        h2o.Unloaded = true
        for _, item in ipairs(h2o.Maid) do
                pcall(function()
                        if typeof(item) == "RBXScriptConnection" then
                                item:Disconnect()
                        elseif type(item) == "function" then
                                item()
                        elseif typeof(item) == "Instance" then
                                item:Destroy()
                        end
                end)
        end
        table.clear(h2o.Maid)
end)

local remoteCache = {}
local function remote(...)
        local nodes = { ... }
        local path = table.concat(nodes, "/")
        local cached = remoteCache[path]
        if cached and cached.Parent then
                return cached
        end
        local node = game:GetService("ReplicatedStorage")
        for _, name in ipairs(nodes) do
                node = node and node:FindFirstChild(name)
                if not node then
                        return nil
                end
        end
        remoteCache[path] = node
        return node
end

local function maid(item)
        table.insert(h2o.Maid, item)
end

local function notify(text, time)
        Library:Notify({ Title = h2o.Name, Description = tostring(text), Time = time or 5 })
end

local function getRoot()
        local char = LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
        local char = LocalPlayer.Character
        return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive()
        local hum = getHumanoid()
        return hum ~= nil and hum.Health > 0 and getRoot() ~= nil
end

local function getClosestTargetPart(maxDist)
        local camera = workspace.CurrentCamera
        if not camera then
                return nil
        end
        local center = camera.ViewportSize / 2
        local best, bestDist = nil, maxDist or math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                        local part = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        if part and hum and hum.Health > 0 then
                                local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                                if onScreen then
                                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                                        if dist < bestDist then
                                                best, bestDist = part, dist
                                        end
                                end
                        end
                end
        end
        return best
end

local function getNearestEnemyRoot(range)
        local root = getRoot()
        if not root then
                return nil
        end
        local best, bestDist = nil, range or math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then
                        local r = plr.Character:FindFirstChild("HumanoidRootPart")
                        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                        if r and hum and hum.Health > 0 then
                                local d = (r.Position - root.Position).Magnitude
                                if d < bestDist then
                                        best, bestDist = r, d
                                end
                        end
                end
        end
        return best
end

local materialList = {}
for _, item in ipairs(Enum.Material:GetEnumItems()) do
        if item.Name ~= "Air" then
                table.insert(materialList, item.Name)
        end
end
table.sort(materialList)

local worldEffects = {}
local worldOriginals = {}
local function getWorldEffect(className, name)
        local key = className .. ":" .. name
        local cached = worldEffects[key]
        if cached and cached.Parent then
                return cached
        end
        local existing = Lighting:FindFirstChild(name)
        if existing and existing:IsA(className) then
                worldEffects[key] = existing
                return existing
        end
        local inst = Instance.new(className)
        inst.Name = name
        worldEffects[key] = inst
        return inst
end

local function saveWorldProp(obj, prop)
        worldOriginals[obj] = worldOriginals[obj] or {}
        if worldOriginals[obj][prop] == nil then
                worldOriginals[obj][prop] = obj[prop]
        end
end

local function restoreWorldProp(obj, prop)
        if worldOriginals[obj] and worldOriginals[obj][prop] ~= nil then
                pcall(function()
                        obj[prop] = worldOriginals[obj][prop]
                end)
        end
end

local soundIds = {
        neverlose = "rbxassetid://6607204501",
        gamesense = "rbxassetid://4817809188",
        skeet = "rbxassetid://5447626464",
        rust = "rbxassetid://5043539486",
        bell = "rbxassetid://6534947240",
        bubble = "rbxassetid://6534947588",
        minecraft = "rbxassetid://4018616850",
        osu = "rbxassetid://7149255551",
        tf2 = "rbxassetid://2868331684",
}

local function playCustomSound(id, volume, speed, startPosition)
        if not id or id == "" then
                return
        end
        local sound = Instance.new("Sound")
        sound:SetAttribute("h2oCustomSound", true)
        sound.SoundId = id
        sound.Volume = math.clamp(tonumber(volume) or 0.5, 0, 10)
        sound.PlaybackSpeed = math.clamp(tonumber(speed) or 1, 0.1, 5)
        sound.TimePosition = math.max(tonumber(startPosition) or 0, 0)
        sound.Parent = SoundService
        sound:Play()
        Debris:AddItem(sound, 5)
end

local function normalizeSoundId(name, customId)
        if name == "custom" then
                local digits = tostring(customId or ""):match("%d+")
                return digits and ("rbxassetid://" .. digits) or ""
        end
        return soundIds[name] or ""
end

local damageHookReady = false
local function ensureDamageHook()
        if damageHookReady then
                return
        end
        task.spawn(function()
                while not damageHookReady and not h2o.Unloaded do
                        pcall(function()
                                local fighterController = require(LocalPlayer.PlayerScripts.Controllers.FighterController)
                                local fighter = fighterController.LocalFighter
                                        or (fighterController.GetFighter and fighterController:GetFighter(LocalPlayer))
                                local mt = fighter and getmetatable(fighter)
                                local fighterClass = mt and mt.__index
                                if fighterClass and type(fighterClass._DamageNumberEffect) == "function" and not fighterClass.__h2oDamageHook then
                                        local original = fighterClass._DamageNumberEffect
                                        fighterClass.__h2oDamageHook = original
                                        fighterClass._DamageNumberEffect = function(self, ...)
                                                local args = { ... }
                                                if h2o.Unloaded or not next(h2o.DamageListeners) then
                                                        return original(self, unpack(args))
                                                end
                                                local info = args[1]
                                                local damage, source = 0, nil
                                                if type(info) == "table" then
                                                        damage = tonumber(info[utf8.char(0)] or info.Damage or info.damage or info.Amount or info.amount) or 0
                                                        source = info[utf8.char(2)] or info.Source or info.Position or info.HitPart
                                                end
                                                local blocked = false
                                                for _, listener in pairs(h2o.DamageListeners) do
                                                        if listener(source, damage) then
                                                                blocked = true
                                                        end
                                                end
                                                if blocked then
                                                        return
                                                end
                                                return original(self, unpack(args))
                                        end
                                        damageHookReady = true
                                elseif fighterClass and fighterClass.__h2oDamageHook then
                                        damageHookReady = true
                                end
                        end)
                        task.wait(1)
                end
        end)
end

local function getLocalFighter()
        local ok, controller = pcall(function()
                return require(LocalPlayer.PlayerScripts.Controllers.FighterController)
        end)
        if ok and type(controller) == "table" then
                return controller.LocalFighter
        end
        return nil
end

local function getLocalWeaponName()
        local fighter = getLocalFighter()
        if not fighter then
                return "weapon"
        end
        local item = fighter.EquippedItem
        if not item then
                return "weapon"
        end
        local ok, name = pcall(function()
                return item.Name or (item.Get and item:Get("Name")) or tostring(item)
        end)
        return ok and tostring(name) or "weapon"
end

do
        local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
        local weapons = {}

        pcall(function()
                local folder = StarterPlayerScripts.Assets.ViewModels.Weapons
                for _, model in ipairs(folder:GetChildren()) do
                        if model:IsA("Model") then
                                table.insert(weapons, model.Name)
                        end
                end
                for _, model in ipairs(folder.Unobtainable:GetChildren()) do
                        if model:IsA("Model") then
                                table.insert(weapons, model.Name)
                        end
                end
        end)
        if #weapons == 0 then
                weapons = { "Assault Rifle", "Handgun", "Fists", "Grenade" }
        end
        table.sort(weapons)

        local function pickLoadout()
                local pickWeapons = remote("Remotes", "Replication", "Fighter", "PickWeapons")
                if not pickWeapons then
                        return
                end
                pickWeapons:FireServer({
                        Options.loadout_primary.Value,
                        Options.loadout_secondary.Value,
                        Options.loadout_melee.Value,
                        Options.loadout_utility.Value,
                })
        end

        local function pickSafe()
                pcall(pickLoadout)
        end

        local loadoutGeneration = 0
        local function sync()
                if not (Toggles.loadout_auto and Toggles.loadout_auto.Value) then
                        return
                end
                loadoutGeneration += 1
                local myGeneration = loadoutGeneration
                task.spawn(function()
                        while Toggles.loadout_auto.Value and not h2o.Unloaded and loadoutGeneration == myGeneration do
                                if not Toggles.loadout_silent.Value then
                                        pickSafe()
                                end
                                task.wait(0.5)
                        end
                end)
                if Toggles.loadout_silent.Value then
                        pickSafe()
                end
        end

        local LoadoutGroup = h2o.Tabs.misc:AddLeftGroupbox("loadout", "package")

        LoadoutGroup:AddToggle("loadout_auto", {
                Text = "auto loadout",
                Default = false,
                Tooltip = "keeps your chosen weapons equipped",
        })
        LoadoutGroup:AddToggle("loadout_silent", {
                Text = "silent mode",
                Default = false,
                Tooltip = "equips once per spawn instead of repeating the remote",
        })

        LoadoutGroup:AddDivider()

        local slots = {
                { id = "loadout_primary", text = "primary", default = "Assault Rifle" },
                { id = "loadout_secondary", text = "secondary", default = "Handgun" },
                { id = "loadout_melee", text = "melee", default = "Fists" },
                { id = "loadout_utility", text = "utility", default = "Grenade" },
        }
        for _, slot in ipairs(slots) do
                LoadoutGroup:AddDropdown(slot.id, {
                        Values = weapons,
                        Default = table.find(weapons, slot.default) and slot.default or weapons[1],
                        Text = slot.text,
                        Searchable = true,
                        Tooltip = "weapon slot - " .. slot.text,
                })
        end

        Toggles.loadout_auto:OnChanged(sync)
        Toggles.loadout_silent:OnChanged(function()
                if Toggles.loadout_auto.Value then
                        pickSafe()
                end
        end)
        for _, slot in ipairs(slots) do
                Options[slot.id]:OnChanged(function()
                        if Toggles.loadout_auto.Value then
                                task.delay(0.1, pickSafe)
                        end
                end)
        end
        maid(LocalPlayer.CharacterAdded:Connect(function()
                if Toggles.loadout_auto.Value then
                        task.delay(0.75, pickSafe)
                end
        end))
end

do
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local queueLookup = {}

        local function buildQueueList()
                local list = {}
                local ok, duelLibrary = pcall(function()
                        return require(ReplicatedStorage.Modules.DuelLibrary)
                end)
                if ok and type(duelLibrary) == "table" then
                        for _, name in ipairs(duelLibrary.MatchmakingQueueOrder or {}) do
                                local info = duelLibrary.MatchmakingQueues and duelLibrary.MatchmakingQueues[name]
                                local display = (info and info.DisplayName) or name
                                queueLookup[display] = name
                                table.insert(list, display)
                        end
                end
                if #list == 0 then
                        list = { "1v1", "2v2_beginner" }
                        queueLookup["1v1"] = "1v1"
                        queueLookup["2v2_beginner"] = "2v2_beginner"
                end
                return list
        end

        local function queueIntoSelected()
                local wanted = Options.autoqueue_mode.Value
                local queueName = queueLookup[wanted] or wanted or "1v1"

                local ok, controller = pcall(function()
                        return require(LocalPlayer.PlayerScripts.Controllers.MatchmakingController)
                end)
                if ok and type(controller) == "table" and controller.QueueInto then
                        task.spawn(pcall, function()
                                controller:QueueInto(queueName)
                        end)
                        return
                end

                local joinQueue = remote("Remotes", "Matchmaking", "JoinQueue")
                if joinQueue then
                        task.spawn(function()
                                pcall(joinQueue.InvokeServer, joinQueue, queueName)
                        end)
                end
        end

        local function leaveQueue()
                local leaveQueueRemote = remote("Remotes", "Matchmaking", "LeaveQueue")
                if leaveQueueRemote then
                        pcall(leaveQueueRemote.FireServer, leaveQueueRemote)
                end
        end

        local QueueGroup = h2o.Tabs.misc:AddLeftGroupbox("auto queue", "clock")

        QueueGroup:AddToggle("autoqueue_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "keeps queueing until a match starts",
        })
        QueueGroup:AddDropdown("autoqueue_mode", {
                Values = buildQueueList(),
                Default = "1v1",
                Text = "game mode",
                Searchable = true,
        })

        local queueGeneration = 0
        Toggles.autoqueue_enabled:OnChanged(function()
                queueGeneration += 1
                local myGeneration = queueGeneration
                if Toggles.autoqueue_enabled.Value then
                        queueIntoSelected()
                        task.spawn(function()
                                while Toggles.autoqueue_enabled.Value and not h2o.Unloaded and queueGeneration == myGeneration do
                                        task.wait(5)
                                        if not (Toggles.autoqueue_enabled.Value and not h2o.Unloaded) then
                                                break
                                        end
                                        pcall(queueIntoSelected)
                                end
                        end)
                else
                        leaveQueue()
                end
        end)
        Options.autoqueue_mode:OnChanged(function()
                if Toggles.autoqueue_enabled.Value then
                        queueIntoSelected()
                end
        end)
        maid(function()
                if Toggles.autoqueue_enabled.Value then
                        leaveQueue()
                end
        end)
end

do
        local DEVICE_MODES = { "Touch", "Gamepad", "MouseKeyboard", "VR" }

        local function getCurrentDevice()
                if VRService.VREnabled then
                        return "VR"
                end
                if UserInputService.TouchEnabled then
                        return "Touch"
                end
                if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
                        return "Gamepad"
                end
                return "MouseKeyboard"
        end

        local function setDevice(mode)
                local setControls = remote("Remotes", "Replication", "Fighter", "SetControls")
                if setControls then
                        pcall(setControls.FireServer, setControls, mode)
                end
        end

        local realDevice = nil

        local SpooferGroup = h2o.Tabs.misc:AddRightGroupbox("spoofers", "user-cog")

        SpooferGroup:AddToggle("spoof_device", {
                Text = "spoof device",
                Default = false,
                Tooltip = "reports a different input device to the server",
        })
        SpooferGroup:AddDropdown("spoof_device_mode", {
                Values = DEVICE_MODES,
                Default = "MouseKeyboard",
                Text = "device",
                Tooltip = "device reported while spoofing",
        })

        Toggles.spoof_device:OnChanged(function()
                if Toggles.spoof_device.Value then
                        realDevice = getCurrentDevice()
                        setDevice(Options.spoof_device_mode.Value)
                elseif realDevice then
                        setDevice(realDevice)
                        realDevice = nil
                end
        end)
        Options.spoof_device_mode:OnChanged(function()
                if Toggles.spoof_device.Value then
                        setDevice(Options.spoof_device_mode.Value)
                end
        end)
        maid(LocalPlayer.CharacterAdded:Connect(function()
                if Toggles.spoof_device.Value then
                        task.delay(0.5, setDevice, Options.spoof_device_mode.Value)
                end
        end))
        maid(function()
                if realDevice then
                        setDevice(realDevice)
                        realDevice = nil
                end
        end)
end

do
        local modeMessages = {
                custom = {},
                smol = { "tiny wins still count", "small text big result", "smol but locked in" },
                corny = {
                        "that round was nacho average duel",
                        "you just got served with extra cheese",
                        "corny line, clean win",
                },
                wholesome = { "good fight", "nice shot", "well played" },
                ["auto ban"] = { "ban phase handled", "voting the loadout", "random ban locked" },
        }

        local customPresets = { "...", "message...", "good fight", "nice shot", "well played" }
        local modeIndex = {}

        local function sendChat(text)
                text = tostring(text or "")
                if text == "" then
                        return
                end
                local ok = pcall(function()
                        local channels = TextChatService:FindFirstChild("TextChannels")
                        local channel = channels and (channels:FindFirstChild("RBXGeneral") or channels:FindFirstChild("RBXSystem"))
                        if channel and channel.SendAsync then
                                channel:SendAsync(text)
                        else
                                error("TextChannel unavailable")
                        end
                end)
                if not ok then
                        pcall(function()
                                game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(text, "All")
                        end)
                end
        end

        local function getNextMessage()
                local mode = Options.chatspam_mode.Value or "custom"
                if mode == "custom" then
                        local text = Options.chatspam_custom.Value or ""
                        if text == "" or text == "message..." then
                                return Options.chatspam_random.Value or "..."
                        end
                        return text
                end
                local messages = modeMessages[mode] or modeMessages.custom
                if #messages == 0 then
                        return Options.chatspam_custom.Value or "..."
                end
                if Toggles.chatspam_order.Value then
                        local nextIndex = (modeIndex[mode] or 0) + 1
                        if nextIndex > #messages then
                                nextIndex = 1
                        end
                        modeIndex[mode] = nextIndex
                        return messages[nextIndex]
                end
                return messages[math.random(1, #messages)]
        end

        local ChatGroup = h2o.Tabs.misc:AddLeftGroupbox("chat spam", "message-square")

        ChatGroup:AddToggle("chatspam_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "sends a chat message every 1.5 seconds",
        })
        ChatGroup:AddToggle("chatspam_order", { Text = "in order", Default = false })
        ChatGroup:AddDropdown("chatspam_mode", {
                Values = { "custom", "smol", "corny", "wholesome", "auto ban" },
                Default = "custom",
                Text = "chat mode",
        })
        ChatGroup:AddDropdown("chatspam_random", {
                Values = customPresets,
                Default = "...",
                Text = "random custom text",
        })
        ChatGroup:AddInput("chatspam_custom", {
                Default = "message...",
                Text = "add custom text",
                Placeholder = "message...",
        })
        ChatGroup:AddButton({
                Text = "refresh modes",
                Func = function()
                        table.clear(modeIndex)
                end,
        })

        Toggles.chatspam_enabled:OnChanged(function()
                if Toggles.chatspam_enabled.Value then
                        task.spawn(function()
                                while Toggles.chatspam_enabled.Value and not h2o.Unloaded do
                                        pcall(sendChat, getNextMessage())
                                        task.wait(1.5)
                                end
                        end)
                end
        end)
end

do
        local weaponList = { "None" }
        pcall(function()
                local folder = StarterPlayer.StarterPlayerScripts.Assets.ViewModels.Weapons
                for _, model in ipairs(folder:GetChildren()) do
                        if model:IsA("Model") then
                                table.insert(weaponList, model.Name)
                        end
                end
                for _, model in ipairs(folder.Unobtainable:GetChildren()) do
                        if model:IsA("Model") then
                                table.insert(weaponList, model.Name)
                        end
                end
        end)
        table.sort(weaponList, function(a, b)
                if a == "None" then
                        return true
                end
                if b == "None" then
                        return false
                end
                return a < b
        end)

        local function buildMapList()
                local maps = {}
                pcall(function()
                        local duelLibrary = require(game:GetService("ReplicatedStorage").Modules.DuelLibrary)
                        for _, name in pairs(duelLibrary.MapOrder or {}) do
                                if duelLibrary.Maps and duelLibrary.Maps[name] and not duelLibrary.Maps[name].IsHidden then
                                        table.insert(maps, name)
                                end
                        end
                        if #maps == 0 then
                                for name, data in pairs(duelLibrary.Maps or {}) do
                                        if not data.IsHidden then
                                                table.insert(maps, name)
                                        end
                                end
                        end
                end)
                table.sort(maps)
                return maps
        end

        local AutoBanGroup = h2o.Tabs.misc:AddRightGroupbox("auto ban", "gavel")

        AutoBanGroup:AddToggle("autoban_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "auto votes during the ban phase",
        })
        AutoBanGroup:AddToggle("autoban_random_map", { Text = "ban random map", Default = false })
        AutoBanGroup:AddSlider("autoban_map_delay", {
                Text = "map ban delay",
                Min = 0,
                Max = 10,
                Default = 0,
                Rounding = 1,
                Suffix = "s",
        })
        AutoBanGroup:AddToggle("autoban_weapons", { Text = "ban weapons", Default = true })
        AutoBanGroup:AddSlider("autoban_first_delay", {
                Text = "first ban delay",
                Min = 0,
                Max = 10,
                Default = 0,
                Rounding = 1,
                Suffix = "s",
        })
        AutoBanGroup:AddSlider("autoban_second_delay", {
                Text = "second ban delay",
                Min = 0,
                Max = 10,
                Default = 0,
                Rounding = 1,
                Suffix = "s",
        })
        AutoBanGroup:AddDropdown("autoban_first", {
                Values = weaponList,
                Default = table.find(weaponList, "Riot Shield") and "Riot Shield" or weaponList[2] or "None",
                Text = "first ban",
                Searchable = true,
        })
        AutoBanGroup:AddDropdown("autoban_second", {
                Values = weaponList,
                Default = table.find(weaponList, "Katana") and "Katana" or weaponList[3] or "None",
                Text = "second ban",
                Searchable = true,
        })

        local banGeneration = 0
        Toggles.autoban_enabled:OnChanged(function()
                banGeneration += 1
                local myGeneration = banGeneration
                if Toggles.autoban_enabled.Value then
                        task.spawn(function()
                                local index = 1
                                local rng = Random.new()
                                while Toggles.autoban_enabled.Value and not h2o.Unloaded and banGeneration == myGeneration do
                                        if Toggles.autoban_weapons.Value then
                                                local votes = {}
                                                if Options.autoban_first.Value ~= "None" then
                                                        table.insert(votes, { name = Options.autoban_first.Value, delay = Options.autoban_first_delay.Value })
                                                end
                                                if Options.autoban_second.Value ~= "None" then
                                                        table.insert(votes, { name = Options.autoban_second.Value, delay = Options.autoban_second_delay.Value })
                                                end
                                                if #votes > 0 then
                                                        local vote = votes[index]
                                                        task.wait(math.max(vote.delay, 0))
                                                        local voteRemote = remote("Remotes", "Duels", "Vote")
                                                        if voteRemote then
                                                                pcall(voteRemote.FireServer, voteRemote, vote.name)
                                                        end
                                                        index = index % #votes + 1
                                                end
                                        end
                                        if Toggles.autoban_random_map.Value then
                                                local maps = buildMapList()
                                                if #maps > 0 then
                                                        task.wait(math.max(Options.autoban_map_delay.Value, 0))
                                                        local voteRemote = remote("Remotes", "Duels", "Vote")
                                                        if voteRemote then
                                                                pcall(voteRemote.FireServer, voteRemote, maps[rng:NextInteger(1, #maps)])
                                                        end
                                                end
                                        end
                                        task.wait(1)
                                end
                        end)
                end
        end)
end

do
        local originalName = LocalPlayer.Name
        local originalDisplayName = LocalPlayer.DisplayName
        local replaced = {}

        local function replaceInLabel(label, spoof)
                local text = label.Text
                if text == "" then
                        return
                end
                local newText = text
                        :gsub(originalDisplayName, spoof)
                        :gsub("@" .. originalName, "@" .. spoof)
                        :gsub(originalName, spoof)
                if newText ~= text then
                        if replaced[label] == nil then
                                replaced[label] = text
                        end
                        label.Text = newText
                end
        end

        local function restoreAll()
                for label, text in pairs(replaced) do
                        pcall(function()
                                label.Text = text
                        end)
                end
                table.clear(replaced)
        end

        local SpooferGroup = h2o.Tabs.misc:AddRightGroupbox("name spoofer", "venetian-mask")

        SpooferGroup:AddToggle("spoof_name", {
                Text = "spoof name",
                Default = false,
                Tooltip = "replaces your name in client-side text",
        })
        SpooferGroup:AddInput("spoof_name_text", {
                Default = "",
                Text = "name",
                Placeholder = "nosniy...",
        })

        Toggles.spoof_name:OnChanged(function()
                if not Toggles.spoof_name.Value then
                        restoreAll()
                end
        end)
        task.spawn(function()
                while not h2o.Unloaded do
                        task.wait(1)
                        if Toggles.spoof_name.Value then
                                local spoof = Options.spoof_name_text.Value
                                if spoof and spoof ~= "" then
                                        pcall(function()
                                                local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                                                if gui then
                                                        for _, label in ipairs(gui:GetDescendants()) do
                                                                if label:IsA("TextLabel") and not replaced[label] then
                                                                        replaceInLabel(label, spoof)
                                                                end
                                                        end
                                                end
                                                for _, plr in ipairs(Players:GetPlayers()) do
                                                        local char = plr.Character
                                                        if char then
                                                                for _, desc in ipairs(char:GetDescendants()) do
                                                                        if desc:IsA("TextLabel") then
                                                                                replaceInLabel(desc, spoof)
                                                                        end
                                                                end
                                                        end
                                                end
                                        end)
                                end
                        end
                end
        end)
        maid(restoreAll)
end

do
        local shaderOriginals = nil
        local snowPart = nil
        local shaderSnowConn = nil

        local function saveLighting()
                shaderOriginals = {
                        Lighting.Ambient,
                        Lighting.Brightness,
                        Lighting.ColorShift_Bottom,
                        Lighting.ColorShift_Top,
                        Lighting.EnvironmentDiffuseScale,
                        Lighting.EnvironmentSpecularScale,
                        Lighting.GlobalShadows,
                        Lighting.OutdoorAmbient,
                        Lighting.ShadowSoftness,
                        Lighting.TimeOfDay,
                }
        end

        local function restoreLighting()
                if not shaderOriginals then
                        return
                end
                Lighting.Ambient = shaderOriginals[1]
                Lighting.Brightness = shaderOriginals[2]
                Lighting.ColorShift_Bottom = shaderOriginals[3]
                Lighting.ColorShift_Top = shaderOriginals[4]
                Lighting.EnvironmentDiffuseScale = shaderOriginals[5]
                Lighting.EnvironmentSpecularScale = shaderOriginals[6]
                Lighting.GlobalShadows = shaderOriginals[7]
                Lighting.OutdoorAmbient = shaderOriginals[8]
                Lighting.ShadowSoftness = shaderOriginals[9]
                Lighting.TimeOfDay = shaderOriginals[10]
                shaderOriginals = nil
        end

        local ShaderGroup = h2o.Tabs.misc:AddLeftGroupbox("shader", "snowflake")

        ShaderGroup:AddToggle("shader_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "night shader with falling snow",
        })
        ShaderGroup:AddSlider("shader_time", {
                Text = "time",
                Min = 0,
                Max = 24,
                Default = 12,
                Rounding = 0,
        })

        Toggles.shader_enabled:OnChanged(function()
                if Toggles.shader_enabled.Value then
                        saveLighting()
                        Lighting.Ambient = Color3.fromRGB(94, 99, 188)
                        Lighting.Brightness = 4
                        Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
                        Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
                        Lighting.EnvironmentDiffuseScale = 1
                        Lighting.EnvironmentSpecularScale = 1
                        Lighting.GlobalShadows = true
                        Lighting.OutdoorAmbient = Color3.fromRGB(0, 0, 0)
                        Lighting.ShadowSoftness = 3
                        Lighting.TimeOfDay = ("%02d:40:00"):format(Options.shader_time.Value or 12)

                        snowPart = Instance.new("Part")
                        snowPart.Name = "h2oShaderSnow"
                        snowPart.Anchored = true
                        snowPart.CanCollide = false
                        snowPart.Transparency = 1
                        snowPart.Size = Vector3.new(160, 1, 160)
                        snowPart.Parent = workspace
                        local emitter = Instance.new("ParticleEmitter")
                        emitter.Name = "h2oSnowEmitter"
                        emitter.Texture = "rbxassetid://92367298778210"
                        emitter.Rate = 220
                        emitter.Speed = NumberRange.new(14, 22)
                        emitter.Lifetime = NumberRange.new(5, 7)
                        emitter.SpreadAngle = Vector2.new(12, 12)
                        emitter.Size = NumberSequence.new(0.32)
                        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
                        emitter.Transparency = NumberSequence.new(0.06)
                        emitter.Acceleration = Vector3.new(4, -9, 0)
                        emitter.EmissionDirection = Enum.NormalId.Bottom
                        emitter.LightInfluence = 0
                        emitter.RotSpeed = NumberRange.new(-45, 45)
                        emitter.Parent = snowPart

                        local nextSnowUpdate = 0
                        shaderSnowConn = RunService.Heartbeat:Connect(function()
                                local now = os.clock()
                                if now < nextSnowUpdate then
                                        return
                                end
                                nextSnowUpdate = now + 0.1
                                local root = getRoot()
                                if root and snowPart then
                                        snowPart.Position = root.Position + Vector3.new(0, 90, 0)
                                end
                        end)
                else
                        if shaderSnowConn then
                                shaderSnowConn:Disconnect()
                                shaderSnowConn = nil
                        end
                        if snowPart then
                                snowPart:Destroy()
                                snowPart = nil
                        end
                        restoreLighting()
                end
        end)
        Options.shader_time:OnChanged(function()
                if Toggles.shader_enabled.Value then
                        Lighting.TimeOfDay = ("%02d:40:00"):format(Options.shader_time.Value or 12)
                end
        end)
        maid(function()
                if shaderSnowConn then
                        shaderSnowConn:Disconnect()
                end
                if snowPart then
                        snowPart:Destroy()
                end
                restoreLighting()
        end)
end

do
        local oldphys, oldsend = nil, nil
        local hasSetFFlag = setfflag ~= nil

        local BlinkGroup = h2o.Tabs.misc:AddLeftGroupbox("blink", "eye-off")

        BlinkGroup:AddToggle("blink_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "freezes your position for other players via network flags",
        })
        BlinkGroup:AddDropdown("blink_type", {
                Values = { "Movement Only", "All" },
                Default = "Movement Only",
                Text = "type",
        })
        BlinkGroup:AddToggle("blink_autosend", {
                Text = "auto send",
                Default = false,
                Tooltip = "periodically lets packets through so you do not rubber-band",
        })
        BlinkGroup:AddSlider("blink_threshold", {
                Text = "send threshold",
                Min = 0,
                Max = 1,
                Default = 0.5,
                Rounding = 2,
                Suffix = "s",
        })

        local function setFlags(physics, sender)
                if hasSetFFlag then
                        pcall(setfflag, "S2PhysicsSenderRate", physics)
                        pcall(setfflag, "DataSenderRate", sender)
                end
        end

        local blinkGeneration = 0
        Toggles.blink_enabled:OnChanged(function()
                blinkGeneration += 1
                local myGeneration = blinkGeneration
                if Toggles.blink_enabled.Value then
                        task.spawn(function()
                                while Toggles.blink_enabled.Value and not h2o.Unloaded and blinkGeneration == myGeneration do
                                        local physicsrate, senderrate = "0", Options.blink_type.Value == "All" and "-1" or "60"
                                        if Toggles.blink_autosend.Value then
                                                local threshold = Options.blink_threshold.Value
                                                if tick() % (threshold + 0.1) > threshold then
                                                        physicsrate, senderrate = "15", "60"
                                                end
                                        end
                                        if physicsrate ~= oldphys or senderrate ~= oldsend then
                                                setFlags(physicsrate, senderrate)
                                                oldphys, oldsend = physicsrate, senderrate
                                        end
                                        task.wait(0.03)
                                end
                        end)
                else
                        setFlags("15", "60")
                        oldphys, oldsend = nil, nil
                end
        end)
        maid(function()
                setFlags("15", "60")
        end)
end

do
        local trackedDrops = {}
        local deathConnection = nil

        local function trackDrop(obj)
                if obj.Name == "_drop" and obj:IsA("BasePart") then
                        trackedDrops[obj] = true
                end
        end

        local function disconnectDeath()
                if deathConnection then
                        deathConnection:Disconnect()
                        deathConnection = nil
                end
        end

        local function getRespawnRemote()
                return remote("Remotes", "Duels", "RespawnNow")
        end

        local ArcadeGroup = h2o.Tabs.misc:AddRightGroupbox("arcade", "joystick")

        ArcadeGroup:AddToggle("arcade_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "auto collects drops and respawns",
        })
        ArcadeGroup:AddToggle("arcade_collect", { Text = "collect drops", Default = true })
        ArcadeGroup:AddToggle("arcade_respawn", { Text = "auto respawn", Default = true })

        for _, obj in ipairs(workspace:GetChildren()) do
                trackDrop(obj)
        end
        maid(workspace.ChildAdded:Connect(trackDrop))
        maid(workspace.ChildRemoved:Connect(function(obj)
                trackedDrops[obj] = nil
        end))

        local collectAccum = 0
        maid(RunService.Heartbeat:Connect(function(dt)
                if h2o.Unloaded then
                        return
                end
                collectAccum += dt
                if collectAccum < 0.2 then
                        return
                end
                collectAccum = 0
                if not Toggles.arcade_enabled.Value or not Toggles.arcade_collect.Value then
                        return
                end
                local root = getRoot()
                if not root then
                        return
                end
                local humanoid = getHumanoid()
                local needsHealth = humanoid and humanoid.Health < humanoid.MaxHealth
                for obj in pairs(trackedDrops) do
                        if not obj.Parent then
                                trackedDrops[obj] = nil
                        elseif (obj:FindFirstChild("Health") and needsHealth) or obj:FindFirstChild("Ammo") then
                                if firetouchinterest then
                                        pcall(firetouchinterest, root, obj, 0)
                                        pcall(firetouchinterest, root, obj, 1)
                                end
                        end
                end
        end))

        maid(LocalPlayer.CharacterAdded:Connect(function(character)
                task.defer(function()
                        disconnectDeath()
                        if not (Toggles.arcade_enabled.Value and Toggles.arcade_respawn.Value) then
                                return
                        end
                        local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
                        if humanoid then
                                deathConnection = humanoid.Died:Connect(function()
                                        task.wait()
                                        if Toggles.arcade_enabled.Value and Toggles.arcade_respawn.Value then
                                                local respawnRemote = getRespawnRemote()
                                                if respawnRemote then
                                                        pcall(respawnRemote.FireServer, respawnRemote)
                                                end
                                        end
                                end)
                        end
                end)
        end))
        maid(disconnectDeath)
end

do
        ensureDamageHook()

        local HitNotifyGroup = h2o.Tabs.misc:AddRightGroupbox("hit notifier", "bell")

        HitNotifyGroup:AddToggle("hitnotify_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "notifies you when you deal damage",
        })
        HitNotifyGroup:AddSlider("hitnotify_duration", {
                Text = "notify duration",
                Min = 1,
                Max = 10,
                Default = 1,
                Rounding = 0,
                Suffix = "s",
        })
        HitNotifyGroup:AddDropdown("hitnotify_template", {
                Values = {
                        "Hit {NAME} for {DMG} in the {PART}",
                        "Hit {NAME} for {DMG} with {WEAPON}",
                        "{NAME} took {DMG} damage in the {PART}",
                        "{WEAPON} hit {NAME} for {DMG}",
                },
                Default = "Hit {NAME} for {DMG} in the {PART}",
                Text = "random notify text",
        })
        HitNotifyGroup:AddInput("hitnotify_custom", {
                Default = "",
                Text = "add custom text",
                Placeholder = "ex: {NAME}, {DMG}, {PART}",
        })
        HitNotifyGroup:AddLabel("formatting: {NAME}, {DMG}, {PART}, {WEAPON}")

        local lastNotifyKey, lastNotifyTime = nil, 0

        local function resolveVictimInfo(source)
                local name, part = "unknown", "body"
                if typeof(source) == "Instance" then
                        local node = source
                        while node and node ~= workspace do
                                local plr = Players:GetPlayerFromCharacter(node)
                                if plr then
                                        name = plr.DisplayName
                                        break
                                end
                                node = node.Parent
                        end
                        if source:IsA("BasePart") then
                                part = source.Name
                        end
                elseif typeof(source) == "Vector3" then
                        local nearest, bestDist = nil, math.huge
                        for _, plr in ipairs(Players:GetPlayers()) do
                                if plr ~= LocalPlayer and plr.Character then
                                        local r = plr.Character:FindFirstChild("HumanoidRootPart")
                                        if r then
                                                local d = (r.Position - source).Magnitude
                                                if d < bestDist then
                                                        nearest, bestDist = plr, d
                                                end
                                        end
                                end
                        end
                        if nearest then
                                name = nearest.DisplayName
                        end
                end
                return name, part
        end

        table.insert(h2o.DamageListeners, function(source, damage)
                if not Toggles.hitnotify_enabled.Value then
                        return false
                end
                local name, part = resolveVictimInfo(source)
                local key = name .. ":" .. math.floor(damage)
                local now = os.clock()
                if key == lastNotifyKey and now - lastNotifyTime < 0.3 then
                        return false
                end
                lastNotifyKey, lastNotifyTime = key, now

                local template = Options.hitnotify_custom.Value
                if template == nil or template == "" then
                        template = Options.hitnotify_template.Value
                end
                local message = tostring(template)
                        :gsub("{NAME}", name)
                        :gsub("{DMG}", tostring(math.floor(damage + 0.5)))
                        :gsub("{PART}", part)
                        :gsub("{WEAPON}", getLocalWeaponName())
                notify(message, Options.hitnotify_duration.Value)
                return false
        end)
end

do
        local UninjectGroup = h2o.Tabs.misc:AddRightGroupbox("uninject", "power")

        UninjectGroup:AddButton({
                Text = "unload h2o",
                Func = function()
                        Library:Unload()
                end,
        })
end

do
        local PostFxGroup = h2o.Tabs.world:AddLeftGroupbox("color correction", "palette")

        PostFxGroup:AddToggle("cc_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "color correction effect",
        })
        PostFxGroup:AddLabel("tint"):AddColorPicker("cc_tint", {
                Default = Color3.fromRGB(255, 255, 255),
                Title = "tint",
        })
        PostFxGroup:AddSlider("cc_saturation", { Text = "saturation", Min = -2, Max = 2, Default = 0, Rounding = 1 })
        PostFxGroup:AddSlider("cc_contrast", { Text = "contrast", Min = -2, Max = 2, Default = 0, Rounding = 1 })
        PostFxGroup:AddSlider("cc_brightness", { Text = "brightness", Min = -2, Max = 2, Default = 0, Rounding = 1 })

        local ccEffect = nil
        local function ccApply()
                if not Toggles.cc_enabled.Value then
                        return
                end
                if not ccEffect then
                        ccEffect = getWorldEffect("ColorCorrectionEffect", "h2oColorCorrection")
                        ccEffect.Parent = Lighting
                end
                ccEffect.Enabled = true
                ccEffect.TintColor = Options.cc_tint.Value
                ccEffect.Saturation = Options.cc_saturation.Value
                ccEffect.Contrast = Options.cc_contrast.Value
                ccEffect.Brightness = Options.cc_brightness.Value
        end

        Toggles.cc_enabled:OnChanged(function()
                if Toggles.cc_enabled.Value then
                        task.spawn(function()
                                while Toggles.cc_enabled.Value and not h2o.Unloaded do
                                        pcall(ccApply)
                                        task.wait(0.2)
                                end
                                if ccEffect then
                                        ccEffect.Enabled = false
                                end
                        end)
                elseif ccEffect then
                        ccEffect.Enabled = false
                end
        end)
        for _, id in ipairs({ "cc_saturation", "cc_contrast", "cc_brightness", "cc_tint" }) do
                Options[id]:OnChanged(ccApply)
        end
        maid(function()
                if ccEffect then
                        ccEffect.Enabled = false
                end
        end)
end

do
        local AtmoGroup = h2o.Tabs.world:AddLeftGroupbox("atmosphere", "cloud-fog")

        AtmoGroup:AddToggle("atmo_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "custom atmosphere",
        })
        AtmoGroup:AddLabel("color"):AddColorPicker("atmo_color", { Default = Color3.fromRGB(255, 255, 255), Title = "color" })
        AtmoGroup:AddLabel("decay"):AddColorPicker("atmo_decay", { Default = Color3.fromRGB(255, 255, 255), Title = "decay" })
        AtmoGroup:AddSlider("atmo_glare", { Text = "glare", Min = 0, Max = 10, Default = 1.5, Rounding = 1 })
        AtmoGroup:AddSlider("atmo_haze", { Text = "haze", Min = 0, Max = 10, Default = 10, Rounding = 1 })
        AtmoGroup:AddSlider("atmo_offset", { Text = "offset", Min = 0, Max = 1, Default = 0.4, Rounding = 2 })
        AtmoGroup:AddSlider("atmo_density", { Text = "density", Min = 0, Max = 1, Default = 0.5, Rounding = 2 })

        local atmoEffect = nil
        local function atmoApply()
                local enabled = Toggles.atmo_enabled.Value
                if enabled and not atmoEffect then
                        atmoEffect = getWorldEffect("Atmosphere", "h2oAtmosphere")
                end
                if atmoEffect then
                        atmoEffect.Parent = enabled and Lighting or nil
                        if enabled then
                                atmoEffect.Color = Options.atmo_color.Value
                                atmoEffect.Decay = Options.atmo_decay.Value
                                atmoEffect.Glare = Options.atmo_glare.Value
                                atmoEffect.Haze = Options.atmo_haze.Value
                                atmoEffect.Offset = Options.atmo_offset.Value
                                atmoEffect.Density = Options.atmo_density.Value
                        end
                end
        end

        Toggles.atmo_enabled:OnChanged(atmoApply)
        for _, id in ipairs({ "atmo_color", "atmo_decay", "atmo_glare", "atmo_haze", "atmo_offset", "atmo_density" }) do
                Options[id]:OnChanged(atmoApply)
        end
        maid(atmoApply)
end

do
        local LightGroup = h2o.Tabs.world:AddLeftGroupbox("lighting", "lightbulb")

        local colorProps = {
                { id = "light_ambient", text = "ambient", prop = "Ambient", def = Lighting.Ambient },
                { id = "light_outdoor", text = "outdoor ambient", prop = "OutdoorAmbient", def = Lighting.OutdoorAmbient },
                { id = "light_shift_bottom", text = "color shift bottom", prop = "ColorShift_Bottom", def = Lighting.ColorShift_Bottom },
                { id = "light_shift_top", text = "color shift top", prop = "ColorShift_Top", def = Lighting.ColorShift_Top },
                { id = "light_fogcolor", text = "fog color", prop = "FogColor", def = Lighting.FogColor },
        }
        for _, entry in ipairs(colorProps) do
                LightGroup:AddToggle(entry.id, { Text = entry.text, Default = false }):AddColorPicker(entry.id .. "_color", {
                        Default = entry.def,
                        Title = entry.text,
                })
        end

        LightGroup:AddToggle("light_fog", { Text = "fog", Default = false })
        LightGroup:AddSlider("light_fogstart", { Text = "fog start", Min = 0, Max = 10000, Default = Lighting.FogStart, Rounding = 0 })
        LightGroup:AddSlider("light_fogend", { Text = "fog end", Min = 0, Max = 100000, Default = Lighting.FogEnd, Rounding = 0 })
        LightGroup:AddToggle("light_exposure", { Text = "exposure compensation", Default = false })
        LightGroup:AddSlider("light_exposure_value", {
                Text = "exposure value",
                Min = -5,
                Max = 5,
                Default = Lighting.ExposureCompensation,
                Rounding = 1,
        })
        LightGroup:AddToggle("light_brightness", { Text = "brightness", Default = false })
        LightGroup:AddSlider("light_brightness_value", { Text = "brightness value", Min = 0, Max = 10, Default = Lighting.Brightness, Rounding = 1 })
        LightGroup:AddToggle("light_clock", { Text = "time of day", Default = false })
        LightGroup:AddSlider("light_clock_value", { Text = "clock time", Min = 0, Max = 24, Default = Lighting.ClockTime, Rounding = 1 })
        LightGroup:AddToggle("light_shadows", { Text = "global shadows", Default = Lighting.GlobalShadows })

        task.spawn(function()
                while not h2o.Unloaded do
                        task.wait(0.2)
                        pcall(function()
                                if Toggles.light_ambient.Value then
                                        saveWorldProp(Lighting, "Ambient")
                                        Lighting.Ambient = Options.light_ambient_color.Value
                                        saveWorldProp(Lighting, "OutdoorAmbient")
                                        Lighting.OutdoorAmbient = Options.light_ambient_color.Value
                                else
                                        restoreWorldProp(Lighting, "Ambient")
                                        restoreWorldProp(Lighting, "OutdoorAmbient")
                                end
                                if Toggles.light_outdoor.Value then
                                        saveWorldProp(Lighting, "OutdoorAmbient")
                                        Lighting.OutdoorAmbient = Options.light_outdoor_color.Value
                                end
                                if Toggles.light_shift_bottom.Value then
                                        saveWorldProp(Lighting, "ColorShift_Bottom")
                                        Lighting.ColorShift_Bottom = Options.light_shift_bottom_color.Value
                                else
                                        restoreWorldProp(Lighting, "ColorShift_Bottom")
                                end
                                if Toggles.light_shift_top.Value then
                                        saveWorldProp(Lighting, "ColorShift_Top")
                                        Lighting.ColorShift_Top = Options.light_shift_top_color.Value
                                else
                                        restoreWorldProp(Lighting, "ColorShift_Top")
                                end
                                if Toggles.light_fogcolor.Value then
                                        saveWorldProp(Lighting, "FogColor")
                                        Lighting.FogColor = Options.light_fogcolor_color.Value
                                else
                                        restoreWorldProp(Lighting, "FogColor")
                                end
                                if Toggles.light_fog.Value then
                                        saveWorldProp(Lighting, "FogStart")
                                        saveWorldProp(Lighting, "FogEnd")
                                        local startVal = Options.light_fogstart.Value
                                        local endVal = Options.light_fogend.Value
                                        if startVal > endVal then
                                                startVal, endVal = endVal, startVal
                                        end
                                        Lighting.FogStart = startVal
                                        Lighting.FogEnd = endVal
                                else
                                        restoreWorldProp(Lighting, "FogStart")
                                        restoreWorldProp(Lighting, "FogEnd")
                                end
                                if Toggles.light_exposure.Value then
                                        saveWorldProp(Lighting, "ExposureCompensation")
                                        Lighting.ExposureCompensation = Options.light_exposure_value.Value
                                else
                                        restoreWorldProp(Lighting, "ExposureCompensation")
                                end
                                if Toggles.light_brightness.Value then
                                        saveWorldProp(Lighting, "Brightness")
                                        Lighting.Brightness = Options.light_brightness_value.Value
                                else
                                        restoreWorldProp(Lighting, "Brightness")
                                end
                                if Toggles.light_clock.Value then
                                        saveWorldProp(Lighting, "ClockTime")
                                        Lighting.ClockTime = Options.light_clock_value.Value
                                else
                                        restoreWorldProp(Lighting, "ClockTime")
                                end
                                if Toggles.light_shadows.Value ~= Lighting.GlobalShadows then
                                        saveWorldProp(Lighting, "GlobalShadows")
                                        Lighting.GlobalShadows = Toggles.light_shadows.Value
                                end
                        end)
                end
        end)
        maid(function()
                for _, prop in ipairs({ "Ambient", "OutdoorAmbient", "ColorShift_Bottom", "ColorShift_Top", "FogColor", "FogStart", "FogEnd", "ExposureCompensation", "Brightness", "ClockTime", "GlobalShadows" }) do
                        restoreWorldProp(Lighting, prop)
                end
        end)
end

do
        local skyboxes = {
                Afternoon = { 600830446, 600831635, 600832720, 600886090, 600833862, 600835177 },
                ["Blue Space"] = { 149397692, 149397686, 149397697, 149397684, 149397688, 149397702 },
                ["Classic Roblox"] = { 1012890, 1012891, 1012887, 1012889, 1012888, 1014449 },
                Cloudy = { 591058823, 591059876, 591058104, 591057861, 591057625, 591059642 },
                Dusk = { 264908339, 264907909, 264909420, 264909758, 264908886, 264907379 },
                Dawn = { 1417494030, 1417494146, 1417494253, 1417494402, 1417494499, 1417494643 },
                ["Dark Skies"] = { 570557514, 570557775, 570557559, 570557620, 570557672, 570557727 },
                Earth = { 6444884337, 6444884785, 6444884337, 6444884785, 6444884337, 6444884785 },
                ["Horizontal Milky Way"] = { 159454299, 159454296, 159454293, 159454286, 159454300, 159454288 },
                Heaven = { 591058823, 591059642, 591059876, 591057625, 591057861, 591058104 },
                Jungle = { 214253616, 214253616, 214253616, 214253616, 214253616, 214253616 },
                Mountains = { 452457785, 452457806, 452457839, 452457866, 452457896, 452457928 },
                Nebula = { 149397697, 149397702, 149397692, 149397688, 149397684, 149397686 },
                ["Night Light"] = { 12064107, 12064152, 12064121, 12063984, 12064115, 12064131 },
                Night = { 12064121, 12064152, 12064107, 12064115, 12063984, 12064131 },
                ["Ocean Sky"] = { 150335574, 150335585, 150335628, 150335620, 150335610, 150335642 },
                Redshift = { 401664839, 401664862, 401664960, 401664881, 401664901, 401664936 },
                Space = { 149397684, 149397686, 149397688, 149397692, 149397697, 149397702 },
                Sunset = { 264909420, 264907909, 264908339, 264908886, 264909758, 264907379 },
                Storm = { 570557514, 570557775, 570557559, 570557620, 570557672, 570557727 },
                SFOTH = { 1012887, 1012891, 1012890, 1012888, 1012889, 1014449 },
                ["Solid Black"] = { 0, 0, 0, 0, 0, 0 },
                Saturn = { 149397688, 149397686, 149397684, 149397692, 149397702, 149397697 },
                Smoke = { 570557672, 570557514, 570557727, 570557559, 570557775, 570557620 },
                ["Vertical Milky Way"] = { 159454286, 159454288, 159454299, 159454300, 159454296, 159454293 },
                White = { 0, 0, 0, 0, 0, 0 },
        }

        local skyboxSettings = {
                Afternoon = { 1200, 18, 11, 14, Color3.fromRGB(150, 150, 150), Color3.fromRGB(210, 220, 235) },
                ["Blue Space"] = { 4500, 4, 6, 0, Color3.fromRGB(65, 80, 125), Color3.fromRGB(25, 30, 60) },
                ["Classic Roblox"] = { 1200, 21, 11, 12, Color3.fromRGB(128, 128, 128), Color3.fromRGB(192, 192, 192) },
                Cloudy = { 0, 12, 0, 13, Color3.fromRGB(135, 140, 145), Color3.fromRGB(180, 185, 190) },
                Dusk = { 900, 14, 8, 18.4, Color3.fromRGB(145, 95, 120), Color3.fromRGB(185, 120, 130) },
                Dawn = { 600, 16, 7, 6.2, Color3.fromRGB(170, 135, 115), Color3.fromRGB(230, 170, 145) },
                ["Dark Skies"] = { 2600, 0, 12, 0, Color3.fromRGB(45, 50, 65), Color3.fromRGB(45, 50, 60) },
                Earth = { 3000, 8, 5, 1, Color3.fromRGB(55, 80, 110), Color3.fromRGB(35, 50, 80) },
                ["Horizontal Milky Way"] = { 6000, 0, 8, 0, Color3.fromRGB(65, 55, 95), Color3.fromRGB(35, 25, 60) },
                Heaven = { 0, 24, 0, 12, Color3.fromRGB(205, 205, 230), Color3.fromRGB(245, 245, 255) },
                Jungle = { 200, 18, 0, 15, Color3.fromRGB(75, 115, 70), Color3.fromRGB(90, 130, 95) },
                Mountains = { 600, 16, 9, 10, Color3.fromRGB(125, 145, 160), Color3.fromRGB(180, 200, 215) },
                Nebula = { 7000, 0, 5, 0, Color3.fromRGB(85, 45, 125), Color3.fromRGB(40, 20, 70) },
                ["Night Light"] = { 5000, 0, 14, 0, Color3.fromRGB(80, 85, 120), Color3.fromRGB(35, 40, 70) },
                Night = { 3500, 0, 11, 0, Color3.fromRGB(55, 60, 80), Color3.fromRGB(25, 30, 45) },
                ["Ocean Sky"] = { 400, 20, 8, 13, Color3.fromRGB(120, 155, 180), Color3.fromRGB(135, 180, 210) },
                Redshift = { 1800, 18, 6, 18, Color3.fromRGB(160, 70, 65), Color3.fromRGB(150, 55, 50) },
                Space = { 6500, 0, 6, 0, Color3.fromRGB(50, 55, 95), Color3.fromRGB(15, 20, 45) },
                Sunset = { 700, 20, 7, 17.8, Color3.fromRGB(170, 105, 95), Color3.fromRGB(235, 135, 95) },
                Storm = { 0, 0, 7, 16, Color3.fromRGB(65, 70, 80), Color3.fromRGB(70, 75, 85) },
                SFOTH = { 1000, 21, 11, 14, Color3.fromRGB(135, 135, 135), Color3.fromRGB(190, 190, 190) },
                ["Solid Black"] = { 0, 0, 0, 0, Color3.new(0, 0, 0), Color3.new(0, 0, 0) },
                Saturn = { 5500, 0, 18, 0, Color3.fromRGB(105, 85, 65), Color3.fromRGB(60, 45, 35) },
                Smoke = { 0, 0, 5, 3, Color3.fromRGB(85, 85, 85), Color3.fromRGB(95, 95, 95) },
                ["Vertical Milky Way"] = { 6200, 0, 8, 0, Color3.fromRGB(70, 50, 90), Color3.fromRGB(30, 20, 55) },
                White = { 0, 0, 0, 12, Color3.new(1, 1, 1), Color3.new(1, 1, 1) },
        }

        local skyNames = {}
        for name in pairs(skyboxes) do
                table.insert(skyNames, name)
        end
        table.sort(skyNames)

        local SkyGroup = h2o.Tabs.world:AddRightGroupbox("skybox", "cloud-sun")

        SkyGroup:AddToggle("skybox_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "replaces the game skybox",
        })
        SkyGroup:AddDropdown("skybox_selected", {
                Values = skyNames,
                Default = "Afternoon",
                Text = "preset",
                Searchable = true,
        })

        local skyInstances = {}

        local function clearSkies()
                for _, sky in ipairs(skyInstances) do
                        pcall(function()
                                sky:Destroy()
                        end)
                end
                table.clear(skyInstances)
        end

        local function applySkybox()
                clearSkies()
                local name = Options.skybox_selected.Value
                local ids = skyboxes[name]
                local settings = skyboxSettings[name]
                if not ids or not settings then
                        return
                end
                saveWorldProp(Lighting, "ClockTime")
                saveWorldProp(Lighting, "Ambient")
                saveWorldProp(Lighting, "OutdoorAmbient")
                saveWorldProp(Lighting, "FogColor")
                local sky = Instance.new("Sky")
                sky.Name = "h2oSkybox"
                sky.SkyboxBk = ids[1] ~= 0 and ("rbxassetid://" .. ids[1]) or ""
                sky.SkyboxDn = ids[2] ~= 0 and ("rbxassetid://" .. ids[2]) or ""
                sky.SkyboxFt = ids[3] ~= 0 and ("rbxassetid://" .. ids[3]) or ""
                sky.SkyboxLf = ids[4] ~= 0 and ("rbxassetid://" .. ids[4]) or ""
                sky.SkyboxRt = ids[5] ~= 0 and ("rbxassetid://" .. ids[5]) or ""
                sky.SkyboxUp = ids[6] ~= 0 and ("rbxassetid://" .. ids[6]) or ""
                sky.StarCount = settings[1]
                sky.SunAngularSize = settings[2]
                sky.MoonAngularSize = settings[3]
                sky.CelestialBodiesShown = settings[2] > 0 or settings[3] > 0
                sky.Parent = Lighting
                table.insert(skyInstances, sky)
                Lighting.ClockTime = settings[4]
                Lighting.Ambient = settings[5]
                Lighting.OutdoorAmbient = settings[5]
                Lighting.FogColor = settings[6]
        end

        Toggles.skybox_enabled:OnChanged(function()
                if Toggles.skybox_enabled.Value then
                        applySkybox()
                        task.spawn(function()
                                while Toggles.skybox_enabled.Value and not h2o.Unloaded do
                                        task.wait(0.5)
                                        if Toggles.skybox_enabled.Value and not (skyInstances[1] and skyInstances[1].Parent) then
                                                pcall(applySkybox)
                                        end
                                end
                        end)
                else
                        clearSkies()
                        for _, prop in ipairs({ "ClockTime", "Ambient", "OutdoorAmbient", "FogColor" }) do
                                restoreWorldProp(Lighting, prop)
                        end
                end
        end)
        Options.skybox_selected:OnChanged(function()
                if Toggles.skybox_enabled.Value then
                        applySkybox()
                end
        end)
        maid(function()
                clearSkies()
                for _, prop in ipairs({ "ClockTime", "Ambient", "OutdoorAmbient", "FogColor" }) do
                        restoreWorldProp(Lighting, prop)
                end
        end)
end

do
        local weatherTextures = {
                Rain = "rbxassetid://241876422",
                Mist = "rbxassetid://130207970",
                Snow = "rbxassetid://92367298778210",
                Leaf = "rbxassetid://297774371",
        }

        local weatherPresets = {
                ["Heavy Rain"] = {
                        light = { 14, 1.4, 450, Color3.fromRGB(120, 135, 155) },
                        layers = {
                                { tex = "Rain", rate = 850, speed = 125, lifetime = 0.75, spread = 3, size = 0.075, color = Color3.fromRGB(185, 205, 255), accel = Vector3.new(0, -360, 0), transparency = 0.05 },
                                { tex = "Mist", rate = 35, speed = 7, lifetime = 3.5, spread = 35, size = 0.45, color = Color3.fromRGB(150, 160, 170), accel = Vector3.new(8, -4, 0), transparency = 0.82 },
                        },
                },
                Rain = {
                        light = { 14, 1.7, 650, Color3.fromRGB(150, 165, 185) },
                        layers = {
                                { tex = "Rain", rate = 420, speed = 105, lifetime = 0.85, spread = 4, size = 0.065, color = Color3.fromRGB(195, 215, 255), accel = Vector3.new(0, -300, 0), transparency = 0.08 },
                                { tex = "Mist", rate = 18, speed = 6, lifetime = 3.3, spread = 35, size = 0.38, color = Color3.fromRGB(175, 185, 195), accel = Vector3.new(4, -3, 0), transparency = 0.86 },
                        },
                },
                Snow = {
                        light = { 13, 2.2, 520, Color3.fromRGB(220, 225, 235) },
                        layers = {
                                { tex = "Snow", rate = 180, speed = 16, lifetime = 5, spread = 60, size = 0.35, color = Color3.fromRGB(255, 255, 255), accel = Vector3.new(12, -28, 0), transparency = 0.05 },
                                { tex = "Mist", rate = 35, speed = 8, lifetime = 5, spread = 90, size = 1.1, color = Color3.fromRGB(235, 240, 255), accel = Vector3.new(4, -4, 0), transparency = 0.8 },
                        },
                },
                City = {
                        light = { 16, 1.5, 500, Color3.fromRGB(115, 120, 130) },
                        layers = {
                                { tex = "Rain", rate = 260, speed = 95, lifetime = 0.95, spread = 6, size = 0.055, color = Color3.fromRGB(180, 190, 210), accel = Vector3.new(-20, -260, 0), transparency = 0.12 },
                                { tex = "Mist", rate = 45, speed = 10, lifetime = 3, spread = 45, size = 0.42, color = Color3.fromRGB(125, 130, 135), accel = Vector3.new(-35, -3, 0), transparency = 0.84 },
                        },
                },
                ["Windy Day"] = {
                        light = { 13, 2.4, 900, Color3.fromRGB(190, 200, 205) },
                        layers = {
                                { tex = "Mist", rate = 70, speed = 24, lifetime = 2.2, spread = 28, size = 0.28, color = Color3.fromRGB(220, 220, 220), accel = Vector3.new(95, -2, 0), transparency = 0.9 },
                                { tex = "Leaf", rate = 22, speed = 28, lifetime = 3, spread = 38, size = 0.18, color = Color3.fromRGB(165, 150, 95), accel = Vector3.new(105, -12, 0), transparency = 0.18, rot = 120 },
                        },
                },
                ["Heavy Rain Night"] = {
                        light = { 0, 0.65, 360, Color3.fromRGB(45, 55, 75) },
                        layers = {
                                { tex = "Rain", rate = 760, speed = 125, lifetime = 0.8, spread = 4, size = 0.075, color = Color3.fromRGB(120, 150, 200), accel = Vector3.new(4, -360, 0), transparency = 0.08 },
                                { tex = "Mist", rate = 42, speed = 7, lifetime = 3.8, spread = 40, size = 0.5, color = Color3.fromRGB(55, 65, 85), accel = Vector3.new(10, -4, 0), transparency = 0.84 },
                        },
                },
                ["Forest Rain Night"] = {
                        light = { 0, 0.75, 420, Color3.fromRGB(30, 55, 50) },
                        layers = {
                                { tex = "Rain", rate = 470, speed = 105, lifetime = 0.9, spread = 8, size = 0.06, color = Color3.fromRGB(130, 170, 170), accel = Vector3.new(8, -300, 0), transparency = 0.12 },
                                { tex = "Mist", rate = 50, speed = 8, lifetime = 3.8, spread = 42, size = 0.45, color = Color3.fromRGB(45, 85, 70), accel = Vector3.new(16, -4, 0), transparency = 0.84 },
                                { tex = "Leaf", rate = 12, speed = 16, lifetime = 3.5, spread = 40, size = 0.16, color = Color3.fromRGB(55, 115, 65), accel = Vector3.new(35, -12, 0), transparency = 0.25, rot = 90 },
                        },
                },
                ["Light Rain And Thunder"] = {
                        light = { 17, 1.25, 560, Color3.fromRGB(95, 105, 125) },
                        thunder = true,
                        layers = {
                                { tex = "Rain", rate = 240, speed = 95, lifetime = 0.95, spread = 6, size = 0.055, color = Color3.fromRGB(195, 210, 255), accel = Vector3.new(0, -275, 0), transparency = 0.12 },
                                { tex = "Mist", rate = 24, speed = 7, lifetime = 3.4, spread = 35, size = 0.4, color = Color3.fromRGB(130, 140, 155), accel = Vector3.new(5, -3, 0), transparency = 0.86 },
                        },
                },
        }

        local weatherNames = {}
        for name in pairs(weatherPresets) do
                table.insert(weatherNames, name)
        end
        table.sort(weatherNames)

        local WeatherGroup = h2o.Tabs.world:AddRightGroupbox("weather", "cloud-rain")

        WeatherGroup:AddToggle("weather_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "particle weather effects",
        })
        WeatherGroup:AddDropdown("weather_selected", {
                Values = weatherNames,
                Default = "Heavy Rain",
                Text = "preset",
                Searchable = true,
        })
        WeatherGroup:AddSlider("weather_rate", { Text = "rate", Min = 0, Max = 5, Default = 1, Rounding = 1 })
        WeatherGroup:AddSlider("weather_lifetime", { Text = "lifetime", Min = 0, Max = 2, Default = 1, Rounding = 2 })
        WeatherGroup:AddSlider("weather_timescale", { Text = "timescale", Min = 0.1, Max = 3, Default = 1, Rounding = 1 })

        local weatherPart = nil
        local lightningLight = nil
        local lightningThread = nil
        local weatherFollowConn = nil

        local function clearWeather()
                if weatherFollowConn then
                        weatherFollowConn:Disconnect()
                        weatherFollowConn = nil
                end
                if weatherPart then
                        weatherPart:Destroy()
                        weatherPart = nil
                end
                if lightningLight then
                        lightningLight:Destroy()
                        lightningLight = nil
                end
                if lightningThread then
                        task.cancel(lightningThread)
                        lightningThread = nil
                end
        end

        local function buildWeather()
                clearWeather()
                local preset = weatherPresets[Options.weather_selected.Value]
                if not preset then
                        return
                end
                weatherPart = Instance.new("Part")
                weatherPart.Name = "h2oWeather"
                weatherPart.Anchored = true
                weatherPart.CanCollide = false
                weatherPart.Transparency = 1
                weatherPart.Size = Vector3.new(220, 1, 220)
                weatherPart.Parent = workspace

                for index, layer in ipairs(preset.layers) do
                        local emitter = Instance.new("ParticleEmitter")
                        emitter.Name = "h2oWeatherLayer" .. index
                        emitter.Texture = weatherTextures[layer.tex]
                        emitter.Rate = layer.rate * Options.weather_rate.Value
                        emitter.Speed = NumberRange.new(layer.speed * Options.weather_timescale.Value)
                        emitter.Lifetime = NumberRange.new(layer.lifetime * Options.weather_lifetime.Value)
                        emitter.SpreadAngle = Vector2.new(layer.spread, layer.spread)
                        emitter.Size = NumberSequence.new(layer.size)
                        emitter.Color = ColorSequence.new(layer.color)
                        emitter.Transparency = NumberSequence.new(layer.transparency)
                        emitter.Acceleration = layer.accel
                        emitter.EmissionDirection = Enum.NormalId.Bottom
                        emitter.LightEmission = 0.3
                        emitter.LightInfluence = 0
                        if layer.rot then
                                emitter.RotSpeed = NumberRange.new(-layer.rot, layer.rot)
                        end
                        pcall(function()
                                emitter.Shape = Enum.ParticleEmitterShape.Box
                                emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
                                emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
                        end)
                        emitter.Parent = weatherPart
                end

                saveWorldProp(Lighting, "ClockTime")
                saveWorldProp(Lighting, "Brightness")
                saveWorldProp(Lighting, "FogEnd")
                saveWorldProp(Lighting, "FogColor")
                Lighting.ClockTime = preset.light[1]
                Lighting.Brightness = preset.light[2]
                Lighting.FogEnd = preset.light[3]
                Lighting.FogColor = preset.light[4]

                if preset.thunder then
                        lightningLight = Instance.new("PointLight")
                        lightningLight.Name = "h2oLightning"
                        lightningLight.Color = Color3.fromRGB(210, 225, 255)
                        lightningLight.Brightness = 0
                        lightningLight.Range = 120
                        lightningLight.Parent = weatherPart
                        lightningThread = task.spawn(function()
                                while Toggles.weather_enabled.Value and not h2o.Unloaded and lightningLight do
                                        task.wait(math.random(35, 90) / 10)
                                        if not lightningLight then
                                                break
                                        end
                                        lightningLight.Brightness = 8
                                        task.wait(0.06)
                                        lightningLight.Brightness = 0
                                        task.wait(0.08)
                                        lightningLight.Brightness = 5
                                        task.wait(0.05)
                                        lightningLight.Brightness = 0
                                end
                        end)
                end

                local nextFollowUpdate = 0
                weatherFollowConn = RunService.Heartbeat:Connect(function()
                        local now = os.clock()
                        if now < nextFollowUpdate then
                                return
                        end
                        nextFollowUpdate = now + 0.1
                        local root = getRoot()
                        if weatherPart and root then
                                weatherPart.Position = root.Position + Vector3.new(0, 85, 0)
                        end
                end)
        end

        Toggles.weather_enabled:OnChanged(function()
                if Toggles.weather_enabled.Value then
                        buildWeather()
                else
                        clearWeather()
                        for _, prop in ipairs({ "ClockTime", "Brightness", "FogEnd", "FogColor" }) do
                                restoreWorldProp(Lighting, prop)
                        end
                end
        end)
        for _, id in ipairs({ "weather_selected", "weather_rate", "weather_lifetime", "weather_timescale" }) do
                Options[id]:OnChanged(function()
                        if Toggles.weather_enabled.Value then
                                buildWeather()
                        end
                end)
        end
        maid(function()
                clearWeather()
                for _, prop in ipairs({ "ClockTime", "Brightness", "FogEnd", "FogColor" }) do
                        restoreWorldProp(Lighting, prop)
                end
        end)
end

do
        local AmbienceGroup = h2o.Tabs.world:AddRightGroupbox("ambience", "music")

        AmbienceGroup:AddToggle("ambience_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "loops ambient sound",
        })
        AmbienceGroup:AddDropdown("ambience_selected", {
                Values = { "Heavy Rain", "Rain", "City", "Windy Day", "Heavy Rain Night", "Forest Rain Night", "Light Rain And Thunder" },
                Default = "Heavy Rain",
                Text = "preset",
        })
        AmbienceGroup:AddSlider("ambience_volume", { Text = "volume", Min = 0, Max = 2, Default = 0.5, Rounding = 1 })

        local ambienceSound = Instance.new("Sound")
        ambienceSound.Name = "h2oAmbience"
        ambienceSound.Looped = true
        ambienceSound.SoundId = "rbxassetid://9112854440"

        Toggles.ambience_enabled:OnChanged(function()
                if Toggles.ambience_enabled.Value then
                        ambienceSound.Volume = Options.ambience_volume.Value
                        ambienceSound.Parent = SoundService
                        ambienceSound:Play()
                        task.spawn(function()
                                while Toggles.ambience_enabled.Value and not h2o.Unloaded do
                                        task.wait(0.5)
                                        if not ambienceSound.IsPlaying then
                                                ambienceSound:Play()
                                        end
                                end
                        end)
                else
                        ambienceSound:Stop()
                        ambienceSound.Parent = nil
                end
        end)
        Options.ambience_volume:OnChanged(function()
                ambienceSound.Volume = Options.ambience_volume.Value
        end)
        maid(function()
                ambienceSound:Stop()
                ambienceSound:Destroy()
        end)
end

do
        local BloomGroup = h2o.Tabs.world:AddRightGroupbox("bloom", "sun")

        BloomGroup:AddToggle("bloom_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "bloom effect",
        })
        BloomGroup:AddSlider("bloom_intensity", { Text = "intensity", Min = 0, Max = 5, Default = 0.6, Rounding = 1 })
        BloomGroup:AddSlider("bloom_size", { Text = "size", Min = 0, Max = 100, Default = 26, Rounding = 0 })
        BloomGroup:AddSlider("bloom_threshold", { Text = "threshold", Min = 0, Max = 5, Default = 0.4, Rounding = 1 })

        local bloomEffect = nil
        local function bloomApply()
                local enabled = Toggles.bloom_enabled.Value
                if enabled and not bloomEffect then
                        bloomEffect = getWorldEffect("BloomEffect", "h2oBloom")
                        bloomEffect.Parent = Lighting
                end
                if bloomEffect then
                        bloomEffect.Enabled = enabled
                        if enabled then
                                bloomEffect.Intensity = Options.bloom_intensity.Value
                                bloomEffect.Size = Options.bloom_size.Value
                                bloomEffect.Threshold = Options.bloom_threshold.Value
                        end
                end
        end

        Toggles.bloom_enabled:OnChanged(bloomApply)
        for _, id in ipairs({ "bloom_intensity", "bloom_size", "bloom_threshold" }) do
                Options[id]:OnChanged(bloomApply)
        end
        maid(function()
                if bloomEffect then
                        bloomEffect.Enabled = false
                end
        end)
end

do
        local SunRaysGroup = h2o.Tabs.world:AddRightGroupbox("sun rays", "sun-dim")

        SunRaysGroup:AddToggle("sunrays_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "god rays effect",
        })
        SunRaysGroup:AddSlider("sunrays_intensity", { Text = "intensity", Min = 0, Max = 1, Default = 0.25, Rounding = 2 })
        SunRaysGroup:AddSlider("sunrays_spread", { Text = "spread", Min = 0, Max = 1, Default = 1, Rounding = 2 })

        local sunRaysEffect = nil
        local function sunRaysApply()
                local enabled = Toggles.sunrays_enabled.Value
                if enabled and not sunRaysEffect then
                        sunRaysEffect = getWorldEffect("SunRaysEffect", "h2oSunRays")
                        sunRaysEffect.Parent = Lighting
                end
                if sunRaysEffect then
                        sunRaysEffect.Enabled = enabled
                        if enabled then
                                sunRaysEffect.Intensity = Options.sunrays_intensity.Value
                                sunRaysEffect.Spread = Options.sunrays_spread.Value
                        end
                end
        end

        Toggles.sunrays_enabled:OnChanged(sunRaysApply)
        Options.sunrays_intensity:OnChanged(sunRaysApply)
        Options.sunrays_spread:OnChanged(sunRaysApply)
        maid(function()
                if sunRaysEffect then
                        sunRaysEffect.Enabled = false
                end
        end)
end

do
        local CameraGroup = h2o.Tabs.world:AddRightGroupbox("camera", "camera")

        CameraGroup:AddToggle("cam_antiflash", {
                Text = "anti flashbang",
                Default = false,
                Tooltip = "blocks flashbang effects",
        })
        CameraGroup:AddToggle("cam_antismoke", {
                Text = "anti smoke",
                Default = false,
                Tooltip = "removes smoke screens",
        })
        CameraGroup:AddToggle("cam_fov", { Text = "fov changer", Default = false })
        CameraGroup:AddSlider("cam_fov_value", { Text = "fov", Min = 1, Max = 120, Default = 120, Rounding = 0 })
        CameraGroup:AddToggle("cam_aspect", { Text = "aspect ratio", Default = false })
        CameraGroup:AddSlider("cam_ratio_x", { Text = "ratio x", Min = 0.1, Max = 5, Default = 1, Rounding = 1 })
        CameraGroup:AddSlider("cam_ratio_y", { Text = "ratio y", Min = 0.1, Max = 5, Default = 0.65, Rounding = 2 })
        CameraGroup:AddSlider("cam_blur", { Text = "blur", Min = 0, Max = 56, Default = 0, Rounding = 0 })

        local originalFOV = nil
        local flashHookReady = false
        local smokeHooked = false
        local originalSmokeScreen, originalSmokeCloud = nil, nil
        local cameraBlur = nil

        local function ensureFlashHook()
                if flashHookReady then
                        return
                end
                pcall(function()
                        local flashed = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.FighterInterface.Flashed)
                        if type(flashed) == "table" and type(flashed.Flash) == "function" and not flashed.__h2oFlashHook then
                                local original = flashed.Flash
                                flashed.__h2oFlashHook = original
                                flashed.Flash = function(...)
                                        if Toggles.cam_antiflash.Value then
                                                return
                                        end
                                        return original(...)
                                end
                                flashHookReady = true
                        end
                end)
        end

        local function setAntiSmoke(enabled)
                pcall(function()
                        local smokeScreen = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.FighterInterface.SmokeScreen)
                        local smokeCloud = require(LocalPlayer.PlayerScripts.Modules.SmokeCloud)
                        if enabled then
                                if not smokeHooked then
                                        originalSmokeScreen = smokeScreen.Update
                                        originalSmokeCloud = smokeCloud.Update
                                        smokeScreen.Update = function(self)
                                                pcall(function()
                                                        self._smoke_cloud_spring.Target = 0
                                                        self._smoke_cloud_cover.Transparency = 1
                                                        self._smoke_cloud_dof.Parent = nil
                                                end)
                                        end
                                        smokeCloud.Update = function(self)
                                                pcall(function()
                                                        if self.Model then
                                                                self.Model:Destroy()
                                                        end
                                                end)
                                                return true
                                        end
                                        smokeHooked = true
                                end
                        elseif smokeHooked then
                                smokeScreen.Update = originalSmokeScreen
                                smokeCloud.Update = originalSmokeCloud
                                smokeHooked = false
                        end
                end)
        end

        local cameraConn = nil
        local function updateCameraConnection()
                if Toggles.cam_fov.Value or Toggles.cam_aspect.Value then
                        if not cameraConn then
                                local camera = workspace.CurrentCamera
                                if camera and originalFOV == nil then
                                        originalFOV = camera.FieldOfView
                                end
                                cameraConn = RunService.RenderStepped:Connect(function()
                                        local cam = workspace.CurrentCamera
                                        if not cam then
                                                return
                                        end
                                        if Toggles.cam_aspect.Value then
                                                cam.FieldOfView = Toggles.cam_fov.Value and Options.cam_fov_value.Value or (originalFOV or 70)
                                                cam.CFrame = cam.CFrame
                                                        * CFrame.new(0, 0, 0, Options.cam_ratio_x.Value, 0, 0, 0, Options.cam_ratio_y.Value, 0, 0, 0, 1)
                                        elseif Toggles.cam_fov.Value then
                                                cam.FieldOfView = Options.cam_fov_value.Value
                                        end
                                end)
                                maid(cameraConn)
                        end
                elseif cameraConn and not Toggles.cam_fov.Value and not Toggles.cam_aspect.Value then
                        cameraConn:Disconnect()
                        cameraConn = nil
                        local cam = workspace.CurrentCamera
                        if cam and originalFOV then
                                cam.FieldOfView = originalFOV
                                originalFOV = nil
                        end
                end
        end
        Toggles.cam_fov:OnChanged(updateCameraConnection)
        Toggles.cam_aspect:OnChanged(updateCameraConnection)
        Options.cam_fov_value:OnChanged(function()
                if Toggles.cam_fov.Value then
                        local cam = workspace.CurrentCamera
                        if cam then
                                cam.FieldOfView = Options.cam_fov_value.Value
                        end
                end
        end)

        Toggles.cam_antiflash:OnChanged(function()
                if Toggles.cam_antiflash.Value then
                        ensureFlashHook()
                end
        end)

        Toggles.cam_antismoke:OnChanged(function()
                setAntiSmoke(Toggles.cam_antismoke.Value)
        end)

        local blurConn = RunService.Heartbeat:Connect(function()
                if h2o.Unloaded then
                        return
                end
                local wanted = Options.cam_blur.Value
                if wanted > 0 then
                        if not cameraBlur then
                                cameraBlur = Instance.new("BlurEffect")
                                cameraBlur.Name = "h2oCameraBlur"
                                cameraBlur.Parent = Lighting
                        end
                        cameraBlur.Size = wanted
                elseif cameraBlur then
                        cameraBlur:Destroy()
                        cameraBlur = nil
                end
        end)
        maid(blurConn)

        maid(function()
                setAntiSmoke(false)
                if cameraConn then
                        cameraConn:Disconnect()
                end
                local cam = workspace.CurrentCamera
                if cam and originalFOV then
                        cam.FieldOfView = originalFOV
                end
                if cameraBlur then
                        cameraBlur:Destroy()
                end
        end)
end

do
        local FreecamGroup = h2o.Tabs.world:AddLeftGroupbox("freecam", "video")

        FreecamGroup:AddToggle("freecam_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "detaches the camera from your character",
        })
        FreecamGroup:AddSlider("freecam_speed", { Text = "speed", Min = 1, Max = 150, Default = 50, Rounding = 0, Suffix = " studs/s" })

        local freecamPos = nil

        Toggles.freecam_enabled:OnChanged(function()
                if Toggles.freecam_enabled.Value then
                        local camera = workspace.CurrentCamera
                        freecamPos = camera and camera.CFrame.Position or Vector3.zero
                        RunService:BindToRenderStep("h2oFreecam", Enum.RenderPriority.Camera.Value + 1, function(dt)
                                if not Toggles.freecam_enabled.Value or not freecamPos then
                                        return
                                end
                                local camera = workspace.CurrentCamera
                                if not camera then
                                        return
                                end
                                dt = math.min(dt, 1 / 15)
                                local look = camera.CFrame.LookVector
                                local right = camera.CFrame.RightVector
                                local move = Vector3.zero
                                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                                        move += look
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                                        move -= look
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                                        move += right
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                                        move -= right
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                                        move += Vector3.yAxis
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                                        move -= Vector3.yAxis
                                end
                                local slow = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                                local speed = Options.freecam_speed.Value * (slow and 0.25 or 1)
                                if move.Magnitude > 0 then
                                        freecamPos += move.Unit * speed * dt
                                end
                                camera.CFrame = CFrame.new(freecamPos) * camera.CFrame.Rotation
                                camera.Focus = camera.CFrame * CFrame.new(0, 0, -100)
                        end)
                else
                        pcall(function()
                                RunService:UnbindFromRenderStep("h2oFreecam")
                        end)
                        freecamPos = nil
                end
        end)
        maid(function()
                pcall(function()
                        RunService:UnbindFromRenderStep("h2oFreecam")
                end)
        end)
end

do
        local WorldMoveGroup = h2o.Tabs.world:AddLeftGroupbox("world movement", "move-3d")

        WorldMoveGroup:AddToggle("projectiletp_enabled", {
                Text = "projectile tp",
                Default = false,
                Tooltip = "teleports thrown projectiles to the closest enemy head",
        })

        local projectileConnections = {}

        local function getClosestHead()
                local root = getRoot()
                if not root then
                        return nil
                end
                local best, bestDist = nil, math.huge
                for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer and plr.Character then
                                local head = plr.Character:FindFirstChild("Head")
                                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                                if head and hum and hum.Health > 0 then
                                        local d = (head.Position - root.Position).Magnitude
                                        if d < bestDist then
                                                best, bestDist = head, d
                                        end
                                end
                        end
                end
                return best
        end

        local function attachPart(part)
                if not part:IsA("BasePart") then
                        return
                end
                part.CanCollide = false
                part.Massless = true
                task.spawn(function()
                        while part.Parent and Toggles.projectiletp_enabled.Value and not h2o.Unloaded do
                                local head = getClosestHead()
                                if head then
                                        part.AssemblyAngularVelocity = Vector3.zero
                                        part.CFrame = CFrame.new(head.Position + Vector3.new(0, 0.25, 0))
                                end
                                RunService.Heartbeat:Wait()
                        end
                end)
        end

        local function hookFolder(folder)
                for _, desc in ipairs(folder:GetDescendants()) do
                        attachPart(desc)
                end
                table.insert(projectileConnections, folder.DescendantAdded:Connect(attachPart))
        end

        local targetFolders = { Daggers = true, Bow = true, Slingshot = true }
        local projectileConn = nil

        Toggles.projectiletp_enabled:OnChanged(function()
                if Toggles.projectiletp_enabled.Value then
                        for _, child in ipairs(workspace:GetChildren()) do
                                if targetFolders[child.Name] then
                                        hookFolder(child)
                                end
                        end
                        projectileConn = workspace.ChildAdded:Connect(function(child)
                                if targetFolders[child.Name] then
                                        hookFolder(child)
                                end
                        end)
                else
                        if projectileConn then
                                projectileConn:Disconnect()
                                projectileConn = nil
                        end
                        for _, conn in ipairs(projectileConnections) do
                                pcall(function()
                                        conn:Disconnect()
                                end)
                        end
                        table.clear(projectileConnections)
                end
        end)
        maid(function()
                if projectileConn then
                        projectileConn:Disconnect()
                end
                for _, conn in ipairs(projectileConnections) do
                        pcall(function()
                                conn:Disconnect()
                        end)
                end
        end)

        WorldMoveGroup:AddToggle("strafe_enabled", {
                Text = "target strafe",
                Default = false,
                Tooltip = "orbits your movement around the nearest enemy",
        })
        WorldMoveGroup:AddSlider("strafe_search", { Text = "search range", Min = 1, Max = 30, Default = 24, Rounding = 0, Suffix = " studs" })
        WorldMoveGroup:AddSlider("strafe_radius", { Text = "strafe range", Min = 1, Max = 30, Default = 18, Rounding = 0, Suffix = " studs" })
        WorldMoveGroup:AddSlider("strafe_yfactor", { Text = "y factor", Min = 0, Max = 100, Default = 100, Rounding = 0, Suffix = "%" })

        local strafeOriginal = nil
        local strafeAngle = 0

        Toggles.strafe_enabled:OnChanged(function()
                if Toggles.strafe_enabled.Value then
                        pcall(function()
                                local playerModule = require(LocalPlayer.PlayerScripts.PlayerModule)
                                local controls = playerModule:GetControls()
                                if controls and type(controls.moveFunction) == "function" then
                                        strafeOriginal = controls.moveFunction
                                        controls.moveFunction = function(self, moveVector, faceForward)
                                                if not Toggles.strafe_enabled.Value or UserInputService:IsKeyDown(Enum.KeyCode.S) then
                                                        return strafeOriginal(self, moveVector, faceForward)
                                                end
                                                local root = getRoot()
                                                local target = getNearestEnemyRoot(Options.strafe_search.Value)
                                                if not root or not target then
                                                        return strafeOriginal(self, moveVector, faceForward)
                                                end
                                                local targetPos = target.Position
                                                local localPos = root.Position
                                                local yDiff = math.abs(localPos.Y - targetPos.Y) * (Options.strafe_yfactor.Value / 100)
                                                local radius = math.max(Options.strafe_radius.Value - yDiff, 2)
                                                local flat = Vector3.new(targetPos.X, localPos.Y, targetPos.Z)
                                                local newPos = flat + CFrame.Angles(0, math.rad(strafeAngle), 0).LookVector * radius
                                                local moveDir = (newPos - localPos) * Vector3.new(1, 0, 1)
                                                if moveDir.Magnitude < 0.01 then
                                                        return strafeOriginal(self, moveVector, faceForward)
                                                end
                                                strafeAngle = (strafeAngle + 4) % 360
                                                return strafeOriginal(self, moveDir.Unit, faceForward)
                                        end
                                end
                        end)
                elseif strafeOriginal then
                        pcall(function()
                                local playerModule = require(LocalPlayer.PlayerScripts.PlayerModule)
                                local controls = playerModule:GetControls()
                                controls.moveFunction = strafeOriginal
                        end)
                        strafeOriginal = nil
                end
        end)
        maid(function()
                if strafeOriginal then
                        pcall(function()
                                local playerModule = require(LocalPlayer.PlayerScripts.PlayerModule)
                                local controls = playerModule:GetControls()
                                controls.moveFunction = strafeOriginal
                        end)
                end
        end)

        WorldMoveGroup:AddToggle("spin_enabled", {
                Text = "spin",
                Default = false,
                Tooltip = "spins your character",
        })
        WorldMoveGroup:AddDropdown("spin_mode", {
                Values = { "CFrame", "RotVelocity", "BodyMover" },
                Default = "CFrame",
                Text = "mode",
        })
        WorldMoveGroup:AddSlider("spin_speed", { Text = "speed", Min = 1, Max = 100, Default = 40, Rounding = 0 })
        WorldMoveGroup:AddToggle("spin_x", { Text = "spin x", Default = false })
        WorldMoveGroup:AddToggle("spin_y", { Text = "spin y", Default = true })
        WorldMoveGroup:AddToggle("spin_z", { Text = "spin z", Default = false })

        local angularVelocity = nil
        local spinConn = nil

        Toggles.spin_enabled:OnChanged(function()
                if Toggles.spin_enabled.Value then
                        spinConn = RunService.PreSimulation:Connect(function()
                                if not isAlive() then
                                        return
                                end
                                local root = getRoot()
                                local humanoid = getHumanoid()
                                if not root or not humanoid then
                                        return
                                end
                                local mode = Options.spin_mode.Value
                                local speed = Options.spin_speed.Value
                                local x = Toggles.spin_x.Value
                                local y = Toggles.spin_y.Value
                                local z = Toggles.spin_z.Value
                                if mode == "RotVelocity" then
                                        humanoid.AutoRotate = false
                                        local orig = root.RotVelocity
                                        root.RotVelocity = Vector3.new(
                                                x and speed or orig.X,
                                                y and speed or orig.Y,
                                                z and speed or orig.Z
                                        )
                                elseif mode == "CFrame" then
                                        local val = math.rad((tick() * (20 * speed)) % 360)
                                        local rx, ry, rz = root.CFrame:ToOrientation()
                                        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(
                                                x and val or rx,
                                                y and val or ry,
                                                z and val or rz
                                        )
                                elseif mode == "BodyMover" then
                                        if not angularVelocity or not angularVelocity.Parent then
                                                if angularVelocity then
                                                        pcall(function()
                                                                angularVelocity:Destroy()
                                                        end)
                                                end
                                                angularVelocity = Instance.new("BodyAngularVelocity")
                                                angularVelocity.Name = "h2oSpinVelocity"
                                                angularVelocity.Parent = root
                                        end
                                        angularVelocity.MaxTorque = Vector3.new(
                                                x and math.huge or 0,
                                                y and math.huge or 0,
                                                z and math.huge or 0
                                        )
                                        angularVelocity.AngularVelocity = Vector3.new(speed, speed, speed)
                                end
                        end)
                else
                        if spinConn then
                                spinConn:Disconnect()
                                spinConn = nil
                        end
                        if angularVelocity then
                                pcall(function()
                                        angularVelocity:Destroy()
                                end)
                                angularVelocity = nil
                        end
                        local humanoid = getHumanoid()
                        if humanoid and Options.spin_mode.Value == "RotVelocity" then
                                humanoid.AutoRotate = true
                        end
                end
        end)
        maid(function()
                if angularVelocity then
                        pcall(function()
                                angularVelocity:Destroy()
                        end)
                end
                local humanoid = getHumanoid()
                if humanoid then
                        humanoid.AutoRotate = true
                end
        end)

        WorldMoveGroup:AddToggle("antiaim_enabled", {
                Text = "anti aim",
                Default = false,
                Tooltip = "fake camera rotation sent to the server",
        })
        WorldMoveGroup:AddDropdown("antiaim_pitch", {
                Values = { "disabled", "up", "down", "zero", "random" },
                Default = "disabled",
                Text = "pitch",
        })
        WorldMoveGroup:AddDropdown("antiaim_yaw", {
                Values = { "disabled", "backwards", "spin", "random" },
                Default = "disabled",
                Text = "yaw",
        })
        WorldMoveGroup:AddToggle("antiaim_underground", { Text = "underground", Default = false })

        local antiaimThread = nil
        local antiaimGeneration = 0

        local function getAntiAimRotation()
                local basePitch, baseYaw = 0, 0
                pcall(function()
                        local controller = require(LocalPlayer.PlayerScripts.Controllers.CameraController)
                        if controller.Rotation then
                                basePitch, baseYaw = controller.Rotation.X, controller.Rotation.Y
                        end
                end)
                local pitchMode = Options.antiaim_pitch.Value
                local yawMode = Options.antiaim_yaw.Value
                local pitch = basePitch
                if Toggles.antiaim_underground.Value then
                        pitch = math.rad(179)
                elseif pitchMode == "up" then
                        pitch = math.rad(-89)
                elseif pitchMode == "down" then
                        pitch = math.rad(179)
                elseif pitchMode == "zero" then
                        pitch = 0
                elseif pitchMode == "random" then
                        pitch = math.rad(math.random(-89, 179))
                end
                local yaw = baseYaw
                if yawMode == "backwards" then
                        yaw = yaw + math.rad(180)
                elseif yawMode == "spin" then
                        yaw = math.rad((tick() * 720) % 360)
                elseif yawMode == "random" then
                        yaw = math.rad(math.random(0, 359))
                end
                return Vector2.new(pitch, yaw)
        end

        Toggles.antiaim_enabled:OnChanged(function()
                antiaimGeneration += 1
                local myGeneration = antiaimGeneration
                if Toggles.antiaim_enabled.Value then
                        if antiaimThread then
                                task.cancel(antiaimThread)
                        end
                        antiaimThread = task.spawn(function()
                                local utility = nil
                                pcall(function()
                                        utility = require(game:GetService("ReplicatedStorage").Modules.Utility)
                                end)
                                local updateRotation = remote("Remotes", "Replication", "Fighter", "UpdateCameraRotation")
                                while Toggles.antiaim_enabled.Value and not h2o.Unloaded and antiaimGeneration == myGeneration do
                                        if utility and updateRotation then
                                                local rotation = getAntiAimRotation()
                                                local burst = Options.antiaim_yaw.Value == "random" and 3 or 1
                                                for _ = 1, burst do
                                                        pcall(function()
                                                                updateRotation:FireServer(utility:EncodeCameraRotation(rotation), nil)
                                                        end)
                                                        RunService.Heartbeat:Wait()
                                                end
                                        else
                                                task.wait(0.5)
                                                pcall(function()
                                                        utility = require(game:GetService("ReplicatedStorage").Modules.Utility)
                                                end)
                                                updateRotation = remote("Remotes", "Replication", "Fighter", "UpdateCameraRotation")
                                        end
                                end
                        end)
                elseif antiaimThread then
                        task.cancel(antiaimThread)
                        antiaimThread = nil
                end
        end)
        maid(function()
                if antiaimThread then
                        task.cancel(antiaimThread)
                end
        end)
end

do
        local SkinGroup = h2o.Tabs.visuals:AddLeftGroupbox("skin changer", "shirt")

        SkinGroup:AddToggle("skinchanger_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "unlocks every cosmetic and applies your equips client-side",
        })
        SkinGroup:AddDropdown("skinchanger_weapon", {
                Values = { "Assault Rifle" },
                Default = "Assault Rifle",
                Text = "weapon",
                Searchable = true,
        })
        SkinGroup:AddDropdown("skinchanger_type", {
                Values = { "Skin", "Wrap", "Charm", "Finisher" },
                Default = "Skin",
                Text = "type",
        })
        SkinGroup:AddDropdown("skinchanger_cosmetic", {
                Values = { "None" },
                Default = "None",
                Text = "cosmetic",
                Searchable = true,
        })
        SkinGroup:AddToggle("skinchanger_all", { Text = "apply to all weapons", Default = false })

        local weaponList = {}
        pcall(function()
                local folder = StarterPlayer.StarterPlayerScripts.Assets.ViewModels.Weapons
                for _, model in ipairs(folder:GetChildren()) do
                        if model:IsA("Model") then
                                table.insert(weaponList, model.Name)
                        end
                end
                pcall(function()
                        for _, model in ipairs(folder.Unobtainable:GetChildren()) do
                                if model:IsA("Model") then
                                        table.insert(weaponList, model.Name)
                                end
                        end
                end)
        end)
        if #weaponList == 0 then
                weaponList = { "Assault Rifle", "Handgun", "Fists", "Grenade" }
        end
        table.sort(weaponList)
        Options.skinchanger_weapon:SetValues(weaponList)
        Options.skinchanger_weapon:SetValue(weaponList[1])

        local typeLists = { Skin = {}, Wrap = {}, Charm = {}, Finisher = {} }
        local catalogEntries = {}
        local catalogLoaded = false
        local bannedNames = { Bubblegum = true, Ragdoll = true, ["Fall Apart"] = true, ["Every Finisher Ever"] = true }
        local cosmeticTypes = { "Skin", "Wrap", "Charm", "Finisher" }

        local function isBanned(name)
                if type(name) ~= "string" then
                        return true
                end
                if name:find("MISSING_") then
                        return true
                end
                return bannedNames[name] == true
        end

        local function loadCatalog()
                if catalogLoaded then
                        return true
                end
                local result = nil
                pcall(function()
                        local module = remote("Modules", "CosmeticLibrary")
                        if module then
                                result = require(module)
                        end
                end)
                if type(result) ~= "table" or type(result.Cosmetics) ~= "table" then
                        return false
                end
                table.clear(catalogEntries)
                for _, key in ipairs(cosmeticTypes) do
                        table.clear(typeLists[key])
                end
                for name, entry in pairs(result.Cosmetics) do
                        if type(name) == "string" and type(entry) == "table" and not isBanned(name) then
                                local ctype = entry.Type
                                if typeLists[ctype] then
                                        catalogEntries[name] = entry
                                        table.insert(typeLists[ctype], name)
                                end
                        end
                end
                for _, list in pairs(typeLists) do
                        table.sort(list)
                end
                catalogLoaded = true
                return true
        end

        local equips = {}

        local function cloneCosmetic(name)
                local entry = catalogEntries[name]
                if not entry then
                        return nil
                end
                local copy = table.clone(entry)
                copy.Name = name
                copy.Owned = true
                copy.Unlocked = true
                copy.Locked = false
                copy.Amount = math.max(1, tonumber(copy.Amount) or 1)
                copy.Count = math.max(1, tonumber(copy.Count) or 1)
                return copy
        end

        local function syncDataField()
                local parts = {}
                for weapon, slots in pairs(equips) do
                        for ctype, cname in pairs(slots) do
                                table.insert(parts, weapon .. "\1" .. ctype .. "\1" .. cname)
                        end
                end
                table.sort(parts)
                Options.skinchanger_data.Value = table.concat(parts, "\2")
        end

        local function decodeEquips(blob)
                table.clear(equips)
                if type(blob) ~= "string" or blob == "" then
                        return
                end
                for _, part in ipairs(blob:split("\2")) do
                        local bits = part:split("\1")
                        if #bits == 3 and bits[1] ~= "" and bits[2] ~= "" and bits[3] ~= "" then
                                equips[bits[1]] = equips[bits[1]] or {}
                                equips[bits[1]][bits[2]] = bits[3]
                        end
                end
        end

        local dataController = nil
        local realGet = nil
        local realGetWeaponData = nil
        local controllerReady = false

        local function ensureDataController()
                if controllerReady then
                        return true
                end
                pcall(function()
                        dataController = require(LocalPlayer.PlayerScripts.Controllers.PlayerDataController)
                end)
                if type(dataController) ~= "table" or type(dataController.Get) ~= "function" then
                        return false
                end
                realGet = dataController.Get
                realGetWeaponData = type(dataController.GetWeaponData) == "function" and dataController.GetWeaponData or nil
                dataController.Get = function(self, key)
                        local data = realGet(self, key)
                        if not Toggles.skinchanger_enabled.Value then
                                return data
                        end
                        if key == "CosmeticInventory" then
                                local proxy = {}
                                if type(data) == "table" then
                                        for k, v in pairs(data) do
                                                proxy[k] = v
                                        end
                                end
                                for name in pairs(catalogEntries) do
                                        if proxy[name] == nil or type(proxy[name]) == "boolean" then
                                                local cloned = cloneCosmetic(name)
                                                if cloned then
                                                        proxy[name] = cloned
                                                end
                                        end
                                end
                                return proxy
                        end
                        return data
                end
                if realGetWeaponData then
                        dataController.GetWeaponData = function(self, wname)
                                local data = realGetWeaponData(self, wname)
                                if not Toggles.skinchanger_enabled.Value or type(data) ~= "table" then
                                        return data
                                end
                                local weq = equips[wname]
                                if not weq or not next(weq) then
                                        return data
                                end
                                local merged = table.clone(data)
                                merged.Name = wname
                                for ctype, cname in pairs(weq) do
                                        local cloned = cloneCosmetic(cname)
                                        if cloned then
                                                merged[ctype] = cloned
                                        end
                                end
                                return merged
                        end
                end
                controllerReady = true
                return true
        end

        local function isGenuinelyOwned(name)
                if not controllerReady or type(name) ~= "string" then
                        return false
                end
                local ok, real = pcall(realGet, dataController, "CosmeticInventory")
                return ok and type(real) == "table" and type(real[name]) == "table"
        end

        local function replicateData()
                pcall(function()
                        local current = dataController and dataController.CurrentData
                        if current and current.Replicate then
                                current:Replicate("WeaponInventory")
                                current:Replicate("CosmeticInventory")
                        end
                end)
        end

        local collectionService = game:GetService("CollectionService")

        local function getIdentity()
                if type(getthreadidentity) == "function" then
                        local ok, id = pcall(getthreadidentity)
                        if ok then
                                return id
                        end
                end
                return 8
        end

        local function setIdentity(id)
                if type(setthreadidentity) == "function" then
                        pcall(setthreadidentity, id)
                end
        end

        local KNIFE_CUSTOM_SKIN = "Knife (Custom Skin)"
        local REAVER_KNIFE_CUSTOM_SKIN = "reaver"
        local DAGGERS_CUSTOM_SKIN = "Jett"
        local SATCHEL_CUSTOM_SKIN = "Raze"
        local SNIPER_CUSTOM_SKIN = "Chamber"
        local RPG_CUSTOM_SKIN = "RPG Raze"
        local FISTS_CUSTOM_SKIN = "Agent"
        local BOW_CUSTOM_SKIN = "Sova"
        local ASSAULT_RIFLE_CUSTOM_SKIN = "Vandal"
        local DICE_TRIPMINE_SKIN = "Subspace Tripmine (Custom Skin)"
        local SPIKE_TRIPMINE_SKIN = "Spike"

        local DICE_TRIPMINE_OUTER_MESH_ID = "rbxassetid://5555691474"
        local DICE_TRIPMINE_INNER_MESH_ID = "rbxassetid://5555691356"
        local DICE_TRIPMINE_IMAGE_ID = "rbxassetid://98372867049331"
        local DICE_TRIPMINE_IMAGE_HIGH_RES_ID = "rbxassetid://75601061529918"
        local DICE_TRIPMINE_MESH_SCALE = 3.35
        local DICE_TRIPMINE_WORLD_MESH_SCALE = 3.25
        local SPIKE_TRIPMINE_MESH_ID = "rbxassetid://97754746098028"
        local TRIPMINE_STAR_REMOVE_MESH_ID = "rbxassetid://13792525075"
        local SPIKE_TRIPMINE_MESH_SCALE = 85
        local SPIKE_TRIPMINE_WORLD_MESH_SCALE = 50
        local SNIPER_CUSTOM_REPLACEMENT_MESH_ID = "rbxassetid://98786413608787"
        local SNIPER_CUSTOM_REPLACEMENT_TEXTURE_ID = "rbxassetid://131686603013672"
        local SNIPER_CUSTOM_REPLACEMENT_SIZE = Vector3.new(0.025, 0.025, 0.025)
        local SNIPER_CUSTOM_REPLACEMENT_OFFSET = Vector3.new(0, -0.25, 0)
        local DAGGERS_CUSTOM_SOURCE_MESH_ID = "rbxassetid://94772705561955"
        local DAGGERS_CUSTOM_REPLACEMENT_MESH_ID = "rbxassetid://128075492497238"
        local DAGGERS_CUSTOM_REPLACEMENT_TEXTURE_ID = "rbxassetid://79246900644201"
        local DAGGERS_CUSTOM_REPLACEMENT_SIZE = Vector3.new(0.03, 0.03, 0.03)
        local DAGGERS_CUSTOM_REPLACEMENT_ROTATION = Vector3.new(0, 90, -90)
        local SATCHEL_CUSTOM_REPLACEMENT_MESH_ID = "rbxassetid://129982008330139"
        local SATCHEL_CUSTOM_REPLACEMENT_TEXTURE_ID = "rbxassetid://121713947189258"
        local SATCHEL_CUSTOM_REPLACEMENT_SIZE = Vector3.new(0.5, 0.5, 0.5)
        local SATCHEL_CUSTOM_WORLD_REPLACEMENT_SIZE = Vector3.new(0.6, 0.6, 0.6)
        local SATCHEL_CUSTOM_REPLACEMENT_ROTATION = Vector3.new(0, -90, 0)
        local RPG_CUSTOM_BODY_REPLACEMENT_MESH_ID = "rbxassetid://81554047161707"
        local RPG_CUSTOM_BODY_REPLACEMENT_TEXTURE_ID = "rbxassetid://133257377819985"
        local RPG_CUSTOM_REPLACEMENT_SCALE = 0.5
        local RPG_CUSTOM_REPLACEMENT_ROTATION = Vector3.new(0, 90, 0)
        local RPG_CUSTOM_REPLACEMENT_OFFSET = Vector3.new(0.04, 0, 0)
        local FISTS_CUSTOM_LEFT_MESH_ID = "rbxassetid://120273083766829"
        local FISTS_CUSTOM_LEFT_TEXTURE_ID = "rbxassetid://124608382264962"
        local FISTS_CUSTOM_RIGHT_MESH_ID = "rbxassetid://129220833982000"
        local FISTS_CUSTOM_RIGHT_TEXTURE_ID = "rbxassetid://118482605175566"
        local FISTS_CUSTOM_MESH_SCALE = Vector3.new(0.1, 0.1, 0.1)
        local FISTS_CUSTOM_LEFT_ROTATION = Vector3.new(45, 0, 0)
        local FISTS_CUSTOM_RIGHT_ROTATION = Vector3.new(-45, 0, 0)
        local BOW_CUSTOM_BODY_REPLACEMENT_MESH_ID = "rbxassetid://80147707463344"
        local BOW_CUSTOM_BODY_REPLACEMENT_TEXTURE_ID = "rbxassetid://87690225474067"
        local BOW_CUSTOM_ARROW_REPLACEMENT_MESH_ID = "rbxassetid://97839236861642"
        local BOW_CUSTOM_ARROW_REPLACEMENT_TEXTURE_ID = "rbxassetid://82458179247269"
        local BOW_CUSTOM_REPLACEMENT_SIZE = Vector3.new(0.25, 0.25, 0.25)

        local CUSTOM_SKIN_IMAGE_OVERRIDES = {
                [REAVER_KNIFE_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                ["sky"] = { Image = "", ImageHighResolution = "" },
                ["Camera"] = { Image = "", ImageHighResolution = "" },
                ["Grenade Raze"] = { Image = "", ImageHighResolution = "" },
                [DAGGERS_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                [SATCHEL_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                [SNIPER_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                ["Operator"] = { Image = "", ImageHighResolution = "" },
                [RPG_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                [FISTS_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                [BOW_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                [ASSAULT_RIFLE_CUSTOM_SKIN] = { Image = "", ImageHighResolution = "" },
                [DICE_TRIPMINE_SKIN] = { Image = DICE_TRIPMINE_IMAGE_ID, ImageHighResolution = DICE_TRIPMINE_IMAGE_HIGH_RES_ID },
                [SPIKE_TRIPMINE_SKIN] = { Image = "", ImageHighResolution = "" },
        }

        local SNIPER_MESH_SKIN_OVERRIDES = {
                [SNIPER_CUSTOM_SKIN] = {
                        Skin = SNIPER_CUSTOM_SKIN,
                        BodyMeshIds = { "rbxassetid://95497877882755", "rbxassetid://118920880889483", "rbxassetid://80662423119419" },
                        RemoveMeshIds = { "rbxassetid://100168191352015", "rbxassetid://82935541182957", "rbxassetid://95388370230390", "rbxassetid://84918196407550" },
                        ReplacementMeshId = SNIPER_CUSTOM_REPLACEMENT_MESH_ID,
                        ReplacementTextureId = SNIPER_CUSTOM_REPLACEMENT_TEXTURE_ID,
                        ReplacementSize = SNIPER_CUSTOM_REPLACEMENT_SIZE,
                        ReplacementOffset = SNIPER_CUSTOM_REPLACEMENT_OFFSET,
                },
                ["Operator"] = {
                        Skin = "Operator",
                        BodyMeshIds = { "rbxassetid://13188893115", "rbxassetid://13188892761", "rbxassetid://14778413014", "rbxassetid://13188893017", "rbxassetid://14774727092" },
                        RemoveMeshIds = { "rbxassetid://13188893310", "rbxassetid://13188892855" },
                        BulletMeshIds = { "rbxassetid://14002915797" },
                        MagazineMeshIds = { "rbxassetid://13188892532", "rbxassetid://13188892651" },
                        BodyReplacementMeshId = "rbxassetid://132995629661821",
                        BodyReplacementTextureId = "rbxassetid://80634410259243",
                        ScopeReplacementMeshId = "rbxassetid://103988563532751",
                        ScopeReplacementTextureId = "rbxassetid://136789986141252",
                        MagazineReplacementMeshId = "rbxassetid://80074307887476",
                        MagazineReplacementTextureId = "rbxassetid://80634410259243",
                        ReplacementSize = Vector3.new(0.3, 0.3, 0.3),
                        ReplacementOffset = Vector3.new(0, -0.25, 0),
                        ScopeOffset = Vector3.new(0.175, 0.5, 0.005),
                        MagazineOffset = Vector3.new(0.7, 0, 0.05),
                        BulletOffset = Vector3.new(-1.25, 0, 0),
                        ReplacementVersion = 9,
                },
        }

        local DAGGERS_MESH_SKIN_OVERRIDES = {
                [DAGGERS_CUSTOM_SKIN] = {
                        Skin = DAGGERS_CUSTOM_SKIN,
                        SourceMeshIds = { DAGGERS_CUSTOM_SOURCE_MESH_ID },
                        ReplacementMeshId = DAGGERS_CUSTOM_REPLACEMENT_MESH_ID,
                        ReplacementTextureId = DAGGERS_CUSTOM_REPLACEMENT_TEXTURE_ID,
                        ReplacementSize = DAGGERS_CUSTOM_REPLACEMENT_SIZE,
                        ReplacementRotation = DAGGERS_CUSTOM_REPLACEMENT_ROTATION,
                        ReplacementVersion = 6,
                        FallbackBodyNames = { "LeftBody", "RightBody" },
                },
        }

        local SATCHEL_MESH_SKIN_OVERRIDES = {
                [SATCHEL_CUSTOM_SKIN] = {
                        Skin = SATCHEL_CUSTOM_SKIN,
                        SourceMeshIds = { "rbxassetid://138805549853994", "rbxassetid://125258747465100", "rbxassetid://111319295872696", "rbxassetid://129504437671598", "rbxassetid://104440368867933" },
                        ReplacementMeshId = SATCHEL_CUSTOM_REPLACEMENT_MESH_ID,
                        ReplacementTextureId = SATCHEL_CUSTOM_REPLACEMENT_TEXTURE_ID,
                        ReplacementSize = SATCHEL_CUSTOM_REPLACEMENT_SIZE,
                        WorldReplacementSize = SATCHEL_CUSTOM_WORLD_REPLACEMENT_SIZE,
                        ReplacementRotation = SATCHEL_CUSTOM_REPLACEMENT_ROTATION,
                        ReplacementVersion = 5,
                },
                [REAVER_KNIFE_CUSTOM_SKIN] = {
                        Skin = REAVER_KNIFE_CUSTOM_SKIN,
                        SourceMeshIds = { "rbxassetid://85166039303292", "rbxassetid://125674590013235", "rbxassetid://97042702941502", "rbxassetid://116723276788898", "rbxassetid://99266754879173" },
                        ReplacementMeshId = "rbxassetid://76054449109492",
                        ReplacementTextureId = "rbxassetid://117578984602503",
                        ReplacementSize = Vector3.new(0.3, 0.3, 0.3),
                        ReplacementRotation = Vector3.new(0, 90, 0),
                        ReplacementOffset = Vector3.new(0, 0.5, 0),
                        ReplacementVersion = 3,
                },
                ["sky"] = {
                        Skin = "sky",
                        SourceMeshIds = { "rbxassetid://140203670599306" },
                        ReplacementMeshId = "rbxassetid://78577370691269",
                        ReplacementTextureId = "rbxassetid://130284287910497",
                        ReplacementSize = Vector3.new(0.6, 0.6, 0.6),
                        ReplacementRotation = Vector3.new(0, 90, 0),
                        WorldSourceMeshIds = { "rbxassetid://140203670599306" },
                        WorldReplacementMeshId = "rbxassetid://111122607123480",
                        WorldReplacementTextureId = "rbxassetid://86629139856581",
                        WorldReplacementSize = Vector3.new(0.3, 0.3, 0.3),
                        WorldReplacementRotation = Vector3.zero,
                        ReplacementVersion = 2,
                },
                ["Grenade Raze"] = {
                        Skin = "Grenade Raze",
                        SourceMeshIds = { "rbxassetid://87132852844264", "rbxassetid://96681677373844", "rbxassetid://121396126155803", "rbxassetid://121842208464560" },
                        ReplacementMeshId = "rbxassetid://80612596590820",
                        ReplacementTextureId = "rbxassetid://123233413518598",
                        ReplacementSize = Vector3.new(0.8, 0.8, 0.8),
                        ReplacementVersion = 2,
                },
                ["Camera"] = {
                        Skin = "Camera",
                        SourceMeshIds = { "rbxassetid://17835823024", "rbxassetid://17835823121", "rbxassetid://17835823211" },
                        ReplacementMeshId = "rbxassetid://112849634500139",
                        ReplacementTextureId = "rbxassetid://126465878813440",
                        ReplacementSize = Vector3.new(0.5, 0.5, 0.5),
                        ReplacementRotation = Vector3.new(0, 0, -90),
                        WorldSourceMeshIds = { "rbxassetid://17835823024", "rbxassetid://17835823121", "rbxassetid://17835823211" },
                        WorldReplacementSize = Vector3.new(2, 2, 2),
                        WorldReplacementRotation = Vector3.new(0, 90, -90),
                        ReplacementVersion = 2,
                },
        }

        local RPG_MESH_SKIN_OVERRIDES = {
                [RPG_CUSTOM_SKIN] = {
                        Skin = RPG_CUSTOM_SKIN,
                        BodyMeshIds = { "rbxassetid://17638908187", "rbxassetid://17638908626" },
                        JuggleMeshIds = { "rbxassetid://17638908803", "rbxassetid://17638907818" },
                        RocketMeshIds = { "rbxassetid://17638908803", "rbxassetid://17638907818" },
                        BodyReplacementMeshId = RPG_CUSTOM_BODY_REPLACEMENT_MESH_ID,
                        BodyReplacementTextureId = RPG_CUSTOM_BODY_REPLACEMENT_TEXTURE_ID,
                        ReplacementScale = RPG_CUSTOM_REPLACEMENT_SCALE,
                        ReplacementRotation = RPG_CUSTOM_REPLACEMENT_ROTATION,
                        ReplacementOffset = RPG_CUSTOM_REPLACEMENT_OFFSET,
                        ReplacementVersion = 3,
                },
        }

        local FISTS_MESH_SKIN_OVERRIDES = {
                [FISTS_CUSTOM_SKIN] = {
                        Skin = FISTS_CUSTOM_SKIN,
                        LeftPartName = "LeftItem",
                        RightPartName = "RightItem",
                        LeftMeshId = FISTS_CUSTOM_LEFT_MESH_ID,
                        LeftTextureId = FISTS_CUSTOM_LEFT_TEXTURE_ID,
                        RightMeshId = FISTS_CUSTOM_RIGHT_MESH_ID,
                        RightTextureId = FISTS_CUSTOM_RIGHT_TEXTURE_ID,
                        MeshScale = FISTS_CUSTOM_MESH_SCALE,
                        LeftRotation = FISTS_CUSTOM_LEFT_ROTATION,
                        RightRotation = FISTS_CUSTOM_RIGHT_ROTATION,
                        ReplacementVersion = 1,
                },
        }

        local BOW_MESH_SKIN_OVERRIDES = {
                [BOW_CUSTOM_SKIN] = {
                        Skin = BOW_CUSTOM_SKIN,
                        BodyMeshIds = { "rbxassetid://116947825701555", "rbxassetid://80510746199823" },
                        ArrowMeshIds = { "rbxassetid://108027163190911", "rbxassetid://114261802270550" },
                        BodyReplacementMeshId = BOW_CUSTOM_BODY_REPLACEMENT_MESH_ID,
                        BodyReplacementTextureId = BOW_CUSTOM_BODY_REPLACEMENT_TEXTURE_ID,
                        ArrowReplacementMeshId = BOW_CUSTOM_ARROW_REPLACEMENT_MESH_ID,
                        ArrowReplacementTextureId = BOW_CUSTOM_ARROW_REPLACEMENT_TEXTURE_ID,
                        ReplacementSize = BOW_CUSTOM_REPLACEMENT_SIZE,
                        ReplacementVersion = 2,
                },
        }

        local ASSAULT_RIFLE_MESH_SKIN_OVERRIDES = {
                [ASSAULT_RIFLE_CUSTOM_SKIN] = {
                        Skin = ASSAULT_RIFLE_CUSTOM_SKIN,
                        BodyMeshIds = { "rbxassetid://17661950733", "rbxassetid://17661950585", "rbxassetid://17662005180", "rbxassetid://17662016762" },
                        BoltMeshIds = { "rbxassetid://17661950452" },
                        MagazineMeshIds = { "rbxassetid://17662005301", "rbxassetid://17662005453" },
                        ReloadMagazineMeshIds = { "rbxassetid://17662005453", "rbxassetid://17662005301" },
                        BodyReplacementMeshId = "rbxassetid://138100951261312",
                        BodyReplacementTextureId = "rbxassetid://84167100219585",
                        MagazineReplacementMeshId = "rbxassetid://92935167277909",
                        MagazineReplacementTextureId = "rbxassetid://84167100219585",
                        ReloadMagazineReplacementMeshId = "rbxassetid://92935167277909",
                        ReloadMagazineReplacementTextureId = "rbxassetid://84167100219585",
                        ReplacementSize = Vector3.new(0.35, 0.35, 0.35),
                        ReplacementOffset = Vector3.new(0.1, -0.25, 0.04),
                        MagazineOffset = Vector3.new(-0.135, -0.2, -0.03),
                        ReplacementVersion = 6,
                },
        }

        local TRIPMINE_MESH_SKIN_OVERRIDES = {
                [DICE_TRIPMINE_SKIN] = {
                        Skin = DICE_TRIPMINE_SKIN,
                        MeshIds = { DICE_TRIPMINE_OUTER_MESH_ID, DICE_TRIPMINE_INNER_MESH_ID },
                        RemoveMeshId = TRIPMINE_STAR_REMOVE_MESH_ID,
                        Scale = DICE_TRIPMINE_MESH_SCALE,
                        WorldScale = DICE_TRIPMINE_WORLD_MESH_SCALE,
                        WorldGroundOffset = 0.5,
                        ExtraMeshScale = 1.15,
                        WorldExtraMeshScale = 1,
                        Color = Color3.fromRGB(255, 255, 255),
                        Material = Enum.Material.SmoothPlastic,
                        Reflectance = 0,
                        ClearTexture = true,
                },
                [SPIKE_TRIPMINE_SKIN] = {
                        Skin = SPIKE_TRIPMINE_SKIN,
                        MeshId = SPIKE_TRIPMINE_MESH_ID,
                        RemoveMeshId = TRIPMINE_STAR_REMOVE_MESH_ID,
                        Scale = SPIKE_TRIPMINE_MESH_SCALE,
                        WorldScale = SPIKE_TRIPMINE_WORLD_MESH_SCALE,
                        WorldGroundOffset = 0.5,
                        Color = Color3.fromRGB(163, 162, 165),
                        ClearTexture = true,
                },
        }

        local function findDescendantByName(parent, name)
                if not parent then
                        return nil
                end
                local direct = parent:FindFirstChild(name)
                if direct then
                        return direct
                end
                for _, descendant in ipairs(parent:GetDescendants()) do
                        if descendant.Name == name then
                                return descendant
                        end
                end
                return nil
        end

        local function normalizeAssetId(assetId)
                return tostring(assetId or ""):match("%d+") or ""
        end

        local function meshMatchesAssetId(inst, assetId)
                local id = normalizeAssetId(assetId)
                if id == "" or typeof(inst) ~= "Instance" then
                        return false
                end
                if inst:IsA("SpecialMesh") then
                        return normalizeAssetId(inst.MeshId) == id or normalizeAssetId(inst.TextureId) == id
                elseif inst:IsA("MeshPart") then
                        return normalizeAssetId(inst.MeshId) == id or normalizeAssetId(inst.TextureID) == id
                end
                return false
        end

        local function meshMatchesAnyAssetId(inst, assetIds)
                for _, assetId in ipairs(assetIds or {}) do
                        if meshMatchesAssetId(inst, assetId) then
                                return true
                        end
                end
                return false
        end

        local function getMeshLikePart(obj)
                if typeof(obj) ~= "Instance" then
                        return nil
                end
                if obj:IsA("SpecialMesh") then
                        return obj.Parent and obj.Parent:IsA("BasePart") and obj.Parent or nil
                end
                return obj:IsA("BasePart") and obj or nil
        end

        local function rotationCFrameFromDegrees(rotation)
                if typeof(rotation) ~= "Vector3" then
                        return CFrame.identity
                end
                return CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
        end

        local function namePathContains(inst, needle)
                needle = tostring(needle or ""):lower()
                if needle == "" then
                        return false
                end
                local current = inst
                while current and current ~= game do
                        if tostring(current.Name or ""):lower():find(needle, 1, true) then
                                return true
                        end
                        current = current.Parent
                end
                return false
        end

        local function averageCFrame(parts)
                local first = parts and parts[1]
                if not first then
                        return CFrame.identity
                end
                local position = Vector3.zero
                for _, part in ipairs(parts) do
                        position += part.Position
                end
                position /= #parts
                return CFrame.new(position) * (first.CFrame - first.CFrame.Position)
        end

        local function addReplacementSpecialMesh(part, profile, defaultScale)
                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Enum.MeshType.FileMesh
                mesh.MeshId = profile.ReplacementMeshId
                pcall(function()
                        mesh.TextureId = profile.ReplacementTextureId or ""
                end)
                mesh.Scale = profile.ReplacementMeshScale or profile.ReplacementSize or defaultScale or Vector3.new(1, 1, 1)
                pcall(function()
                        mesh.VertexColor = Vector3.new(1, 1, 1)
                end)
                mesh.Parent = part
                return mesh
        end

        local function copyWrapInfo(source, replacement)
                if not (source and replacement) then
                        return
                end
                local wrapGroup = source:GetAttribute("WrapGroup")
                if wrapGroup ~= nil then
                        replacement:SetAttribute("WrapGroup", wrapGroup)
                end
                pcall(function()
                        if collectionService:HasTag(source, "Wrappable") then
                                collectionService:AddTag(replacement, "Wrappable")
                        end
                end)
        end

        local function stripPartVisuals(part, attributeName)
                part:SetAttribute(attributeName, true)
                pcall(function()
                        part:RemoveTag("Wrappable")
                end)
                pcall(function()
                        collectionService:RemoveTag(part, "Wrappable")
                end)
                if part:IsA("MeshPart") then
                        pcall(function()
                                part.TextureID = ""
                        end)
                        pcall(function()
                                part.MeshId = ""
                        end)
                end
                for _, child in ipairs(part:GetDescendants()) do
                        if child:IsA("Decal") or child:IsA("Texture") then
                                child.Transparency = 1
                        elseif child:IsA("SurfaceAppearance") then
                                child:Destroy()
                        elseif child:IsA("SpecialMesh") then
                                child.Scale = Vector3.zero
                                pcall(function()
                                        child.MeshId = ""
                                end)
                                pcall(function()
                                        child.TextureId = ""
                                end)
                        elseif child:IsA("Highlight") then
                                child.Enabled = false
                        end
                end
        end

        local function hideMeshAnchor(part, attributeName)
                if not (part and part:IsA("BasePart")) then
                        return false
                end
                if part:GetAttribute(attributeName) then
                        return true
                end
                part.Transparency = 1
                part.LocalTransparencyModifier = 1
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.Massless = true
                pcall(function()
                        part.CastShadow = false
                end)
                pcall(function()
                        part.Size = Vector3.new(0.001, 0.001, 0.001)
                end)
                part:SetAttribute("IgnoreObject", true)
                part:SetAttribute("IgnoreTransparency", true)
                stripPartVisuals(part, attributeName)
                return true
        end

        local function applyDaggerMeshProfile(root, profile)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                if root:GetAttribute("__h2oDaggerMeshSkin") == profile.Skin and root:GetAttribute("__h2oDaggerMeshSignature") == profile.Signature then
                        return true
                end
                local replaced, seen = 0, {}
                local function replaceIfTarget(obj)
                        if seen[obj] or not meshMatchesAnyAssetId(obj, profile.SourceMeshIds) then
                                return
                        end
                        seen[obj] = true
                        local part = getMeshLikePart(obj)
                        if not part or part:GetAttribute("__h2oDaggerHiddenAnchor") or part:GetAttribute("__h2oDaggerReplacementMeshPart") then
                                return
                        end
                        local anchorParent = part.Parent
                        if not anchorParent then
                                return
                        end
                        local originalName = part.Name
                        part.Name = "__h2oDaggerAnchor_" .. originalName
                        local replacement = Instance.new("Part")
                        replacement.Name = originalName
                        replacement.Size = Vector3.new(1, 1, 1)
                        replacement.CFrame = part.CFrame * rotationCFrameFromDegrees(profile.ReplacementRotation)
                        replacement.Anchored = part.Anchored
                        replacement.CanCollide = false
                        replacement.CanTouch = false
                        replacement.CanQuery = false
                        replacement.Massless = true
                        replacement.Color = Color3.fromRGB(255, 255, 255)
                        pcall(function()
                                replacement.Material = part.Material
                        end)
                        pcall(function()
                                replacement.CastShadow = false
                        end)
                        replacement:SetAttribute("__h2oDaggerReplacementMeshPart", true)
                        replacement:SetAttribute("IgnoreTransparency", true)
                        addReplacementSpecialMesh(replacement, profile)
                        copyWrapInfo(part, replacement)
                        replacement.Parent = anchorParent
                        local weld = Instance.new("WeldConstraint")
                        weld.Name = "__h2oDaggerReplacementWeld"
                        weld.Part0 = part
                        weld.Part1 = replacement
                        weld.Parent = replacement
                        hideMeshAnchor(part, "__h2oDaggerHiddenAnchor")
                        part:SetAttribute("IgnoreObject", true)
                        part:SetAttribute("IgnoreTransparency", true)
                        replaced += 1
                end
                replaceIfTarget(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        replaceIfTarget(obj)
                end
                for _, bodyName in ipairs(profile.FallbackBodyNames or {}) do
                        for _, obj in ipairs(root:GetDescendants()) do
                                if obj.Name == bodyName then
                                        local target = obj:FindFirstChild("MeshPart")
                                        if target and not seen[target] and target:IsA("MeshPart") then
                                                seen[target] = true
                                                replaceIfTarget(target)
                                        end
                                end
                        end
                end
                root:SetAttribute("__h2oDaggerMeshSkin", profile.Skin)
                root:SetAttribute("__h2oDaggerMeshSignature", profile.Signature)
                root:SetAttribute("__h2oDaggerMeshCount", replaced)
                return replaced > 0
        end

        local function getSatchelMeshProfileForAsset(cosmeticName, worldAsset)
                local profile = SATCHEL_MESH_SKIN_OVERRIDES[cosmeticName]
                if profile and worldAsset and (profile.WorldSourceMeshIds or profile.WorldReplacementMeshId or profile.WorldReplacementTextureId or profile.WorldReplacementSize or profile.WorldReplacementRotation or profile.WorldReplacementOffset) then
                        local worldProfile = table.clone(profile)
                        worldProfile.SourceMeshIds = profile.WorldSourceMeshIds or profile.SourceMeshIds
                        worldProfile.ReplacementMeshId = profile.WorldReplacementMeshId or profile.ReplacementMeshId
                        worldProfile.ReplacementTextureId = profile.WorldReplacementTextureId or profile.ReplacementTextureId
                        worldProfile.ReplacementSize = profile.WorldReplacementSize or profile.ReplacementSize
                        worldProfile.ReplacementRotation = profile.WorldReplacementRotation or profile.ReplacementRotation
                        worldProfile.ReplacementOffset = profile.WorldReplacementOffset or profile.ReplacementOffset
                        return worldProfile
                end
                return profile
        end

        local function applySatchelMeshProfile(root, profile)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                if root:GetAttribute("__h2oSatchelMeshSkin") == profile.Skin and root:GetAttribute("__h2oSatchelMeshSignature") == profile.Signature then
                        return true
                end
                for _, descendant in ipairs(root:GetDescendants()) do
                        if descendant:GetAttribute("__h2oSatchelReplacementMeshPart") then
                                descendant:Destroy()
                        end
                end
                local bodyParts, seenObjects, seenParts = {}, {}, {}
                local function collectIfTarget(obj)
                        if seenObjects[obj] or not meshMatchesAnyAssetId(obj, profile.SourceMeshIds) then
                                return
                        end
                        seenObjects[obj] = true
                        local part = getMeshLikePart(obj)
                        if part and not seenParts[part] and not part:GetAttribute("__h2oSatchelHiddenAnchor") then
                                seenParts[part] = true
                                table.insert(bodyParts, part)
                        end
                end
                collectIfTarget(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        collectIfTarget(obj)
                end
                local anchor = bodyParts[1]
                if not (anchor and anchor:IsA("BasePart") and anchor.Parent) then
                        return false
                end
                local anchorParent = anchor.Parent
                local replacement = Instance.new("Part")
                replacement.Name = "__h2oCustomSatchelReplacement"
                replacement.Size = Vector3.new(1, 1, 1)
                replacement.CFrame = averageCFrame(bodyParts)
                        * CFrame.new(profile.ReplacementOffset or Vector3.zero)
                        * rotationCFrameFromDegrees(profile.ReplacementRotation)
                replacement.Anchored = anchor.Anchored
                replacement.CanCollide = false
                replacement.CanTouch = false
                replacement.CanQuery = false
                replacement.Massless = true
                replacement.Color = Color3.fromRGB(255, 255, 255)
                pcall(function()
                        replacement.Material = anchor.Material
                end)
                pcall(function()
                        replacement.CastShadow = false
                end)
                replacement:SetAttribute("__h2oSatchelReplacementMeshPart", true)
                replacement:SetAttribute("IgnoreTransparency", true)
                addReplacementSpecialMesh(replacement, profile, Vector3.new(1, 1, 1))
                copyWrapInfo(anchor, replacement)
                replacement.Parent = anchorParent
                local weld = Instance.new("WeldConstraint")
                weld.Name = "__h2oSatchelReplacementWeld"
                weld.Part0 = anchor
                weld.Part1 = replacement
                weld.Parent = replacement
                for _, part in ipairs(bodyParts) do
                        if part and part.Parent then
                                if not part.Name:find("__h2oSatchelAnchor_", 1, true) then
                                        part.Name = "__h2oSatchelAnchor_" .. part.Name
                                end
                                hideMeshAnchor(part, "__h2oSatchelHiddenAnchor")
                        end
                end
                root:SetAttribute("__h2oSatchelMeshSkin", profile.Skin)
                root:SetAttribute("__h2oSatchelMeshSignature", profile.Signature)
                root:SetAttribute("__h2oSatchelMeshCount", 1)
                return true
        end

        local function hideRpgMeshPart(part)
                if not (part and part:IsA("BasePart")) then
                        return false
                end
                if part:GetAttribute("__h2oRpgHiddenPart") then
                        return true
                end
                part.Transparency = 1
                part.LocalTransparencyModifier = 1
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.Massless = true
                pcall(function()
                        part.CastShadow = false
                end)
                pcall(function()
                        part.Size = Vector3.new(0.001, 0.001, 0.001)
                end)
                part:SetAttribute("__h2oRpgHiddenPart", true)
                part:SetAttribute("IgnoreObject", true)
                part:SetAttribute("IgnoreTransparency", true)
                part:SetAttribute("WrapGroup", 0)
                stripPartVisuals(part, "__h2oRpgHiddenPart")
                return true
        end

        local function applyRpgMeshReplacement(obj, meshId, textureId, profile)
                local part = getMeshLikePart(obj)
                if not part or part:GetAttribute("__h2oRpgHiddenPart") then
                        return false
                end
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.Massless = true
                part:SetAttribute("__h2oCustomRpgMesh", true)
                part:SetAttribute("IgnoreTransparency", true)
                if not part:GetAttribute("__h2oRpgReplacementAdjusted") then
                        local scale = tonumber(profile and profile.ReplacementScale) or 1
                        if scale ~= 1 then
                                pcall(function()
                                        part.Size = part.Size * scale
                                end)
                        end
                        if profile and profile.ReplacementOffset then
                                pcall(function()
                                        part.CFrame = part.CFrame * CFrame.new(profile.ReplacementOffset)
                                end)
                        end
                        if profile and profile.ReplacementRotation then
                                pcall(function()
                                        part.CFrame = part.CFrame * rotationCFrameFromDegrees(profile.ReplacementRotation)
                                end)
                        end
                        part:SetAttribute("__h2oRpgReplacementAdjusted", true)
                end
                if obj:IsA("MeshPart") then
                        pcall(function()
                                obj.MeshId = meshId
                        end)
                        pcall(function()
                                obj.TextureID = textureId or ""
                        end)
                        return true
                elseif obj:IsA("SpecialMesh") then
                        pcall(function()
                                obj.MeshType = Enum.MeshType.FileMesh
                        end)
                        pcall(function()
                                obj.MeshId = meshId
                        end)
                        pcall(function()
                                obj.TextureId = textureId or ""
                        end)
                        pcall(function()
                                obj.VertexColor = Vector3.new(1, 1, 1)
                        end)
                        return true
                end
                return false
        end

        local function applyRpgMeshProfile(root, profile, options)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                options = options or {}
                if root:GetAttribute("__h2oRpgMeshSkin") == profile.Skin
                        and root:GetAttribute("__h2oRpgMeshSignature") == profile.Signature
                        and root:GetAttribute("__h2oRpgRocketVisible") == false then
                        return true
                end
                local changed, removed, seen = 0, 0, {}
                local function applyIfTarget(obj)
                        if seen[obj] then
                                return
                        end
                        if not (meshMatchesAnyAssetId(obj, profile.BodyMeshIds)
                                or meshMatchesAnyAssetId(obj, profile.JuggleMeshIds)
                                or meshMatchesAnyAssetId(obj, profile.RocketMeshIds)) then
                                return
                        end
                        seen[obj] = true
                        local part = getMeshLikePart(obj)
                        if not part then
                                return
                        end
                        if (namePathContains(obj, "rocket") and meshMatchesAnyAssetId(obj, profile.RocketMeshIds))
                                or (namePathContains(obj, "juggle") and meshMatchesAnyAssetId(obj, profile.JuggleMeshIds)) then
                                if hideRpgMeshPart(part) then
                                        removed += 1
                                end
                        elseif meshMatchesAnyAssetId(obj, profile.BodyMeshIds) then
                                if applyRpgMeshReplacement(obj, profile.BodyReplacementMeshId, profile.BodyReplacementTextureId, profile) then
                                        changed += 1
                                end
                        end
                end
                applyIfTarget(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        applyIfTarget(obj)
                end
                root:SetAttribute("__h2oRpgMeshSkin", profile.Skin)
                root:SetAttribute("__h2oRpgMeshSignature", profile.Signature)
                root:SetAttribute("__h2oRpgRocketVisible", false)
                root:SetAttribute("__h2oRpgMeshCount", changed)
                root:SetAttribute("__h2oRpgHiddenCount", removed)
                return changed > 0 or removed > 0
        end

        local function applyFistsMeshProfile(root, profile)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                if root:GetAttribute("__h2oFistsMeshSkin") == profile.Skin
                        and root:GetAttribute("__h2oFistsMeshSignature") == profile.Signature
                        and (root:GetAttribute("__h2oFistsMeshCount") or 0) > 0 then
                        return true
                end
                local applied = 0
                local function buildHand(partName, meshId, textureId, rotation)
                        local part = findDescendantByName(root, partName)
                        if not (part and part:IsA("BasePart")) then
                                return
                        end
                        for _, child in ipairs(part:GetChildren()) do
                                child:Destroy()
                        end
                        part.Transparency = 1
                        part.LocalTransparencyModifier = 1
                        part.CanCollide = false
                        part.CanTouch = false
                        part.CanQuery = false
                        part.Massless = true
                        part:SetAttribute("__h2oFistsHiddenAnchor", true)
                        part:SetAttribute("IgnoreTransparency", true)
                        local replacement = Instance.new("Part")
                        replacement.Name = "__h2oCustomFistsMesh"
                        replacement.Size = part.Size
                        replacement.CFrame = part.CFrame * rotationCFrameFromDegrees(rotation)
                        replacement.Anchored = false
                        replacement.CanCollide = false
                        replacement.CanTouch = false
                        replacement.CanQuery = false
                        replacement.Massless = true
                        replacement.Transparency = 0
                        replacement.LocalTransparencyModifier = 0
                        replacement:SetAttribute("__h2oCustomFistsMesh", true)
                        replacement:SetAttribute("IgnoreTransparency", true)
                        replacement.Parent = part
                        local mesh = Instance.new("SpecialMesh")
                        mesh.MeshType = Enum.MeshType.FileMesh
                        mesh.MeshId = meshId
                        pcall(function()
                                mesh.TextureId = textureId or ""
                        end)
                        mesh.Scale = profile.MeshScale or Vector3.new(0.1, 0.1, 0.1)
                        pcall(function()
                                mesh.VertexColor = Vector3.new(1, 1, 1)
                        end)
                        mesh.Parent = replacement
                        local weld = Instance.new("WeldConstraint")
                        weld.Name = "__h2oCustomFistsMeshWeld"
                        weld.Part0 = part
                        weld.Part1 = replacement
                        weld.Parent = replacement
                        applied += 1
                end
                buildHand(profile.LeftPartName or "LeftItem", profile.LeftMeshId, profile.LeftTextureId, profile.LeftRotation)
                buildHand(profile.RightPartName or "RightItem", profile.RightMeshId, profile.RightTextureId, profile.RightRotation)
                root:SetAttribute("__h2oFistsMeshSkin", profile.Skin)
                root:SetAttribute("__h2oFistsMeshSignature", profile.Signature)
                root:SetAttribute("__h2oFistsMeshCount", applied)
                return applied > 0
        end

        local function applyBowMeshProfile(root, profile)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                if root:GetAttribute("__h2oBowMeshSkin") == profile.Skin
                        and root:GetAttribute("__h2oBowMeshSignature") == profile.Signature
                        and (root:GetAttribute("__h2oBowMeshCount") or 0) > 0 then
                        return true
                end
                local bodyParts, arrowParts, seenParts = {}, {}, {}
                local function collectIfTarget(obj)
                        local part = getMeshLikePart(obj)
                        if not part or seenParts[part] or part:GetAttribute("__h2oBowHiddenAnchor") then
                                return
                        end
                        if meshMatchesAnyAssetId(obj, profile.BodyMeshIds) then
                                seenParts[part] = true
                                table.insert(bodyParts, part)
                        elseif meshMatchesAnyAssetId(obj, profile.ArrowMeshIds) then
                                seenParts[part] = true
                                table.insert(arrowParts, part)
                        end
                end
                collectIfTarget(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        collectIfTarget(obj)
                end
                local applied = 0
                local function buildReplacement(anchors, replacementName, meshId, textureId)
                        local anchor = anchors and anchors[1]
                        if not (anchor and anchor:IsA("BasePart")) then
                                return
                        end
                        local parent = anchor.Parent or root
                        if not parent then
                                return
                        end
                        for _, descendant in ipairs(root:GetDescendants()) do
                                if descendant:GetAttribute("__h2oBowReplacementMeshPart") and descendant.Name == replacementName then
                                        descendant:Destroy()
                                end
                        end
                        local replacement = Instance.new("Part")
                        replacement.Name = replacementName
                        replacement.Size = Vector3.new(1, 1, 1)
                        replacement.CFrame = averageCFrame(anchors)
                        replacement.Anchored = anchor.Anchored
                        replacement.CanCollide = false
                        replacement.CanTouch = false
                        replacement.CanQuery = false
                        replacement.Massless = true
                        replacement.Transparency = 0
                        replacement.LocalTransparencyModifier = 0
                        replacement:SetAttribute("__h2oBowReplacementMeshPart", true)
                        replacement:SetAttribute("IgnoreTransparency", true)
                        local mesh = Instance.new("SpecialMesh")
                        mesh.MeshType = Enum.MeshType.FileMesh
                        mesh.MeshId = meshId
                        pcall(function()
                                mesh.TextureId = textureId or ""
                        end)
                        mesh.Scale = profile.ReplacementSize or Vector3.new(0.5, 0.5, 0.5)
                        pcall(function()
                                mesh.VertexColor = Vector3.new(1, 1, 1)
                        end)
                        mesh.Parent = replacement
                        copyWrapInfo(anchor, replacement)
                        replacement.Parent = parent
                        if not replacement.Anchored then
                                local weld = Instance.new("WeldConstraint")
                                weld.Name = "__h2oBowReplacementWeld"
                                weld.Part0 = anchor
                                weld.Part1 = replacement
                                weld.Parent = replacement
                        end
                        for _, part in ipairs(anchors) do
                                hideMeshAnchor(part, "__h2oBowHiddenAnchor")
                        end
                        applied += 1
                end
                buildReplacement(bodyParts, "__h2oCustomBowBody", profile.BodyReplacementMeshId, profile.BodyReplacementTextureId)
                buildReplacement(arrowParts, "__h2oCustomBowArrow", profile.ArrowReplacementMeshId, profile.ArrowReplacementTextureId)
                root:SetAttribute("__h2oBowMeshSkin", profile.Skin)
                root:SetAttribute("__h2oBowMeshSignature", profile.Signature)
                root:SetAttribute("__h2oBowMeshCount", applied)
                return applied > 0
        end

        local function hideAssaultRifleMeshAnchor(part, anchorType)
                if not (part and part:IsA("BasePart")) then
                        return false
                end
                part:SetAttribute("__h2oAssaultRifleAnchorType", anchorType or "Part")
                hideMeshAnchor(part, "__h2oAssaultRifleHiddenAnchor")
                return true
        end

        local function createAssaultRifleReplacementMeshPart(root, anchor, replacementName, meshId, textureId, cframe, profile)
                if not (anchor and anchor:IsA("BasePart")) then
                        return false
                end
                local parent = anchor.Parent or root
                if not parent then
                        return false
                end
                local replacement = Instance.new("MeshPart")
                replacement.Name = replacementName
                replacement.Size = profile.ReplacementSize or Vector3.new(0.35, 0.35, 0.35)
                replacement.CFrame = cframe or anchor.CFrame
                replacement.Anchored = anchor.Anchored
                replacement.CanCollide = false
                replacement.CanTouch = false
                replacement.CanQuery = false
                replacement.Massless = true
                replacement.Transparency = 0
                replacement.LocalTransparencyModifier = 0
                replacement.Color = Color3.fromRGB(255, 255, 255)
                pcall(function()
                        replacement.MeshId = meshId
                end)
                pcall(function()
                        replacement.TextureID = textureId or ""
                end)
                pcall(function()
                        replacement.Material = anchor.Material
                end)
                pcall(function()
                        replacement.CastShadow = false
                end)
                replacement:SetAttribute("__h2oAssaultRifleReplacementMeshPart", true)
                replacement:SetAttribute("IgnoreTransparency", true)
                copyWrapInfo(anchor, replacement)
                replacement.Parent = parent
                if not replacement.Anchored then
                        local weld = Instance.new("WeldConstraint")
                        weld.Name = "__h2oAssaultRifleReplacementWeld"
                        weld.Part0 = anchor
                        weld.Part1 = replacement
                        weld.Parent = replacement
                end
                return true
        end

        local function applyAssaultRifleMeshProfile(root, profile)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                if root:GetAttribute("__h2oAssaultRifleMeshSkin") == profile.Skin
                        and root:GetAttribute("__h2oAssaultRifleMeshSignature") == profile.Signature
                        and (root:GetAttribute("__h2oAssaultRifleMeshCount") or 0) > 0 then
                        return true
                end
                for _, descendant in ipairs(root:GetDescendants()) do
                        if descendant:GetAttribute("__h2oAssaultRifleReplacementMeshPart") then
                                descendant:Destroy()
                        end
                end
                local bodyParts, magazineParts, reloadMagazineParts, boltParts, seenParts = {}, {}, {}, {}, {}
                local function collectIfTarget(obj)
                        local part = getMeshLikePart(obj)
                        if not part or seenParts[part] then
                                return
                        end
                        local previousType = part:GetAttribute("__h2oAssaultRifleAnchorType")
                        local isReloadMagazine = previousType == "ReloadMagazine"
                                or (meshMatchesAnyAssetId(obj, profile.ReloadMagazineMeshIds) and namePathContains(obj, "reload"))
                        if previousType == "Body" or meshMatchesAnyAssetId(obj, profile.BodyMeshIds) then
                                seenParts[part] = true
                                table.insert(bodyParts, part)
                        elseif isReloadMagazine then
                                seenParts[part] = true
                                table.insert(reloadMagazineParts, part)
                        elseif previousType == "Magazine" or meshMatchesAnyAssetId(obj, profile.MagazineMeshIds) or meshMatchesAnyAssetId(obj, profile.ReloadMagazineMeshIds) then
                                seenParts[part] = true
                                table.insert(magazineParts, part)
                        elseif previousType == "Bolt" or meshMatchesAnyAssetId(obj, profile.BoltMeshIds) then
                                seenParts[part] = true
                                table.insert(boltParts, part)
                        end
                end
                collectIfTarget(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        collectIfTarget(obj)
                end
                local bodyAnchor = bodyParts[1] or magazineParts[1] or boltParts[1]
                local magazineAnchor = magazineParts[1] or bodyAnchor
                local reloadMagazineAnchor = reloadMagazineParts[1] or magazineAnchor
                local bodyCFrame = bodyParts[1] and averageCFrame(bodyParts) or (bodyAnchor and bodyAnchor.CFrame) or CFrame.identity
                local reloadMagazineCFrame = reloadMagazineParts[1] and averageCFrame(reloadMagazineParts) or bodyCFrame
                local replacementOffset = profile.ReplacementOffset or Vector3.zero
                local magazineOffset = profile.MagazineOffset or Vector3.zero
                bodyCFrame = bodyCFrame * CFrame.new(replacementOffset)
                reloadMagazineCFrame = reloadMagazineCFrame * CFrame.new(replacementOffset)
                local applied = 0
                if createAssaultRifleReplacementMeshPart(root, bodyAnchor, "__h2oCustomAssaultRifleBody", profile.BodyReplacementMeshId, profile.BodyReplacementTextureId, bodyCFrame, profile) then
                        applied += 1
                end
                if createAssaultRifleReplacementMeshPart(root, magazineAnchor, "__h2oCustomAssaultRifleMagazine", profile.MagazineReplacementMeshId, profile.MagazineReplacementTextureId, bodyCFrame * CFrame.new(magazineOffset), profile) then
                        applied += 1
                end
                if reloadMagazineParts[1] and createAssaultRifleReplacementMeshPart(root, reloadMagazineAnchor, "__h2oCustomAssaultRifleReloadMagazine", profile.ReloadMagazineReplacementMeshId or profile.MagazineReplacementMeshId, profile.ReloadMagazineReplacementTextureId or profile.MagazineReplacementTextureId, reloadMagazineCFrame, profile) then
                        applied += 1
                end
                for _, part in ipairs(bodyParts) do
                        hideAssaultRifleMeshAnchor(part, "Body")
                end
                for _, part in ipairs(magazineParts) do
                        hideAssaultRifleMeshAnchor(part, "Magazine")
                end
                for _, part in ipairs(reloadMagazineParts) do
                        hideAssaultRifleMeshAnchor(part, "ReloadMagazine")
                end
                for _, part in ipairs(boltParts) do
                        hideAssaultRifleMeshAnchor(part, "Bolt")
                end
                root:SetAttribute("__h2oAssaultRifleMeshSkin", profile.Skin)
                root:SetAttribute("__h2oAssaultRifleMeshSignature", profile.Signature)
                root:SetAttribute("__h2oAssaultRifleMeshCount", applied)
                return applied > 0
        end

        local function offsetSniperVisibleAnchor(part, anchorType, offset)
                if not (part and part:IsA("BasePart")) then
                        return false
                end
                local originalCFrame = part:GetAttribute("__h2oSniperOriginalCFrame")
                if typeof(originalCFrame) ~= "CFrame" then
                        originalCFrame = part.CFrame
                        part:SetAttribute("__h2oSniperOriginalCFrame", originalCFrame)
                end
                part.CFrame = originalCFrame * CFrame.new(offset or Vector3.zero)
                part:SetAttribute("__h2oSniperAnchorType", anchorType or "Part")
                part:SetAttribute("__h2oSniperVisibleOffset", true)
                return true
        end

        local function hideSniperMeshAnchor(part, anchorType)
                if not (part and part:IsA("BasePart")) then
                        return false
                end
                part:SetAttribute("__h2oSniperAnchorType", anchorType or "Part")
                part:SetAttribute("WrapGroup", 0)
                hideMeshAnchor(part, "__h2oHiddenSniperMesh")
                pcall(function()
                        part.Material = Enum.Material.SmoothPlastic
                end)
                pcall(function()
                        part.Reflectance = 0
                end)
                return true
        end

        local function hideSniperMeshId(root, assetId)
                local parts = {}
                if typeof(root) ~= "Instance" or not assetId then
                        return parts
                end
                local seen = {}
                local function hideIfMatch(obj)
                        if not meshMatchesAssetId(obj, assetId) then
                                return
                        end
                        local part = getMeshLikePart(obj)
                        if part and not seen[part] then
                                seen[part] = true
                                if hideSniperMeshAnchor(part, "Remove") then
                                        table.insert(parts, part)
                                end
                        elseif obj:IsA("SpecialMesh") then
                                obj.Scale = Vector3.zero
                        end
                end
                hideIfMatch(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        hideIfMatch(obj)
                end
                return parts
        end

        local function createSniperReplacementMeshPart(root, anchor, replacementName, meshId, textureId, cframe, profile)
                if not (anchor and anchor:IsA("BasePart")) then
                        return false
                end
                local parent = anchor.Parent or root
                if not parent then
                        return false
                end
                local replacement = Instance.new("MeshPart")
                replacement.Name = replacementName
                pcall(function()
                        replacement.MeshId = meshId
                end)
                pcall(function()
                        replacement.TextureID = textureId or ""
                end)
                replacement.Size = profile.ReplacementSize or Vector3.new(0.05, 0.05, 0.05)
                replacement.CFrame = cframe or anchor.CFrame
                replacement.Anchored = anchor.Anchored
                replacement.CanCollide = false
                replacement.CanTouch = false
                replacement.CanQuery = false
                replacement.Massless = true
                replacement.Transparency = 0
                replacement.LocalTransparencyModifier = 0
                replacement.Color = Color3.fromRGB(255, 255, 255)
                pcall(function()
                        replacement.Material = anchor.Material
                end)
                pcall(function()
                        replacement.CastShadow = false
                end)
                replacement:SetAttribute("__h2oCustomSniperReplacement", true)
                replacement:SetAttribute("WrapGroup", 1)
                replacement:SetAttribute("IgnoreTransparency", true)
                pcall(function()
                        collectionService:AddTag(replacement, "Wrappable")
                end)
                replacement.Parent = parent
                if not replacement.Anchored then
                        local weld = Instance.new("WeldConstraint")
                        weld.Name = "__h2oCustomSniperReplacementWeld"
                        weld.Part0 = anchor
                        weld.Part1 = replacement
                        weld.Parent = replacement
                end
                return true
        end

        local function applySniperMultiMeshProfile(root, profile)
                for _, descendant in ipairs(root:GetDescendants()) do
                        if descendant:GetAttribute("__h2oCustomSniperReplacement") then
                                descendant:Destroy()
                        end
                end
                local bodyParts, magazineParts, bulletParts, removeParts, seenParts = {}, {}, {}, {}, {}
                local function collectIfTarget(obj)
                        local part = getMeshLikePart(obj)
                        if not part or seenParts[part] then
                                return
                        end
                        local previousType = part:GetAttribute("__h2oSniperAnchorType")
                        if previousType == "Body" or meshMatchesAnyAssetId(obj, profile.BodyMeshIds) then
                                seenParts[part] = true
                                table.insert(bodyParts, part)
                        elseif previousType == "Magazine" or meshMatchesAnyAssetId(obj, profile.MagazineMeshIds) then
                                seenParts[part] = true
                                table.insert(magazineParts, part)
                        elseif previousType == "Bullet" or meshMatchesAnyAssetId(obj, profile.BulletMeshIds) then
                                seenParts[part] = true
                                table.insert(bulletParts, part)
                        elseif previousType == "Remove" or meshMatchesAnyAssetId(obj, profile.RemoveMeshIds) then
                                seenParts[part] = true
                                table.insert(removeParts, part)
                        end
                end
                collectIfTarget(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        collectIfTarget(obj)
                end
                local bodyAnchor = bodyParts[1] or magazineParts[1]
                local magazineAnchor = magazineParts[1] or bodyAnchor
                if not bodyAnchor then
                        return false
                end
                local offset = profile.ReplacementOffset or Vector3.zero
                local bodyCFrame = (bodyParts[1] and averageCFrame(bodyParts) or bodyAnchor.CFrame) * CFrame.new(offset)
                local scopeCFrame = bodyCFrame * CFrame.new(profile.ScopeOffset or Vector3.zero)
                local magazineCFrame = bodyCFrame * CFrame.new(profile.MagazineOffset or Vector3.zero)
                local applied = 0
                if createSniperReplacementMeshPart(root, bodyAnchor, "__h2oCustomSniperReplacement", profile.BodyReplacementMeshId, profile.BodyReplacementTextureId, bodyCFrame, profile) then
                        applied += 1
                end
                if createSniperReplacementMeshPart(root, bodyAnchor, "__h2oCustomSniperScope", profile.ScopeReplacementMeshId, profile.ScopeReplacementTextureId, scopeCFrame, profile) then
                        applied += 1
                end
                if createSniperReplacementMeshPart(root, magazineAnchor, "__h2oCustomSniperMagazine", profile.MagazineReplacementMeshId, profile.MagazineReplacementTextureId, magazineCFrame, profile) then
                        applied += 1
                end
                for _, part in ipairs(bodyParts) do
                        hideSniperMeshAnchor(part, "Body")
                end
                for _, part in ipairs(magazineParts) do
                        hideSniperMeshAnchor(part, "Magazine")
                end
                for _, part in ipairs(bulletParts) do
                        offsetSniperVisibleAnchor(part, "Bullet", profile.BulletOffset or Vector3.zero)
                end
                for _, part in ipairs(removeParts) do
                        hideSniperMeshAnchor(part, "Remove")
                end
                return applied > 0
        end

        local function applySniperMeshProfile(root, profile)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                if root:GetAttribute("__h2oSniperMeshSkin") == profile.Skin
                        and root:GetAttribute("__h2oSniperMeshSignature") == profile.Signature then
                        return true
                end
                local applied
                if profile.BodyReplacementMeshId or profile.ScopeReplacementMeshId or profile.MagazineReplacementMeshId then
                        applied = applySniperMultiMeshProfile(root, profile)
                        if not applied then
                                return false
                        end
                        root:SetAttribute("__h2oSniperMeshSkin", profile.Skin)
                        root:SetAttribute("__h2oSniperMeshSignature", profile.Signature)
                        return true
                end
                local bodyParts = {}
                for _, meshId in ipairs(profile.BodyMeshIds or {}) do
                        for _, part in ipairs(hideSniperMeshId(root, meshId)) do
                                table.insert(bodyParts, part)
                        end
                end
                for _, meshId in ipairs(profile.RemoveMeshIds or {}) do
                        hideSniperMeshId(root, meshId)
                end
                local anchor = bodyParts[1]
                if not (anchor and anchor:IsA("BasePart")) then
                        return false
                end
                for _, descendant in ipairs(root:GetDescendants()) do
                        if descendant:GetAttribute("__h2oCustomSniperReplacement") then
                                descendant:Destroy()
                        end
                end
                if not createSniperReplacementMeshPart(root, anchor, "__h2oCustomSniperReplacement", profile.ReplacementMeshId, profile.ReplacementTextureId, averageCFrame(bodyParts) * CFrame.new(profile.ReplacementOffset or Vector3.zero), profile) then
                        return false
                end
                root:SetAttribute("__h2oSniperMeshSkin", profile.Skin)
                root:SetAttribute("__h2oSniperMeshSignature", profile.Signature)
                return true
        end

        local function getTripmineMeshIds(profile)
                local ids = {}
                if type(profile and profile.MeshIds) == "table" then
                        for _, meshId in ipairs(profile.MeshIds) do
                                if normalizeAssetId(meshId) ~= "" then
                                        table.insert(ids, meshId)
                                end
                        end
                elseif profile and normalizeAssetId(profile.MeshId) ~= "" then
                        table.insert(ids, profile.MeshId)
                end
                return ids
        end

        local function getTripmineExtraMeshScale(profile, worldVisual)
                if worldVisual then
                        return profile and profile.WorldExtraMeshScale or 1
                end
                return profile and profile.ExtraMeshScale or 1
        end

        local function getTripmineMeshSignature(profile, worldVisual)
                local normalized = {}
                for _, meshId in ipairs(getTripmineMeshIds(profile)) do
                        table.insert(normalized, normalizeAssetId(meshId))
                end
                return table.concat(normalized, ",") .. "|" .. tostring(getTripmineExtraMeshScale(profile, worldVisual))
        end

        local function scaleTripmineMeshVector(scale, multiplier)
                multiplier = multiplier or 1
                if typeof(scale) == "Vector3" then
                        return scale * multiplier
                end
                return Vector3.new(scale, scale, scale) * multiplier
        end

        local function isCustomTripmineMeshIgnored(inst)
                local current = inst
                while current do
                        if current:GetAttribute("__h2oHiddenTripmineMesh") then
                                return true
                        end
                        local compactName = tostring(current.Name or ""):lower():gsub("[%s_%-%p]", "")
                        if compactName:find("arm", 1, true)
                                or compactName:find("hand", 1, true)
                                or compactName:find("fake", 1, true)
                                or compactName:find("charm", 1, true)
                                or compactName:find("hitbox", 1, true) then
                                return true
                        end
                        current = current.Parent
                end
                return false
        end

        local function scoreCustomTripmineMeshTarget(root, meshLike, removedMeshId)
                if removedMeshId and meshMatchesAssetId(meshLike, removedMeshId) then
                        return nil
                end
                local part = meshLike:IsA("SpecialMesh") and meshLike.Parent or meshLike
                if not (part and part:IsA("BasePart")) or isCustomTripmineMeshIgnored(part) then
                        return nil
                end
                local score = part.Size.Magnitude
                local name = tostring(part.Name or ""):lower()
                if root:IsA("Model") and part == root.PrimaryPart then
                        score += 1000
                end
                if name:find("mesh", 1, true) then
                        score += 500
                end
                if name:find("body", 1, true) then
                        score += 250
                end
                if name:find("mine", 1, true) or name:find("trip", 1, true) then
                        score += 250
                end
                return score
        end

        local function findCustomTripmineMeshTarget(root, profile)
                if typeof(root) ~= "Instance" then
                        return nil
                end
                local best, bestScore = nil, -math.huge
                local removedMeshId = profile and (profile.RemoveMeshId or profile.HideMeshId)
                local function consider(obj)
                        if obj:IsA("SpecialMesh") or obj:IsA("MeshPart") then
                                local score = scoreCustomTripmineMeshTarget(root, obj, removedMeshId)
                                if score and score > bestScore then
                                        best = obj
                                        bestScore = score
                                end
                        end
                end
                consider(root)
                for _, descendant in ipairs(root:GetDescendants()) do
                        consider(descendant)
                end
                return best
        end

        local function removeTripmineMeshAsset(root, assetId)
                if typeof(root) ~= "Instance" or not assetId then
                        return
                end
                local remove = {}
                local function queueIfMatch(obj)
                        if meshMatchesAssetId(obj, assetId) then
                                local part = obj:IsA("SpecialMesh") and obj.Parent or obj
                                if part and part:IsA("BasePart") then
                                        table.insert(remove, part)
                                elseif obj:IsA("SpecialMesh") then
                                        table.insert(remove, obj)
                                end
                        end
                end
                queueIfMatch(root)
                for _, obj in ipairs(root:GetDescendants()) do
                        queueIfMatch(obj)
                end
                for _, obj in ipairs(remove) do
                        if obj and obj.Parent then
                                obj:SetAttribute("__h2oRemovedTripmineMesh", true)
                                obj:Destroy()
                        end
                end
        end

        local function removeCustomTripmineExtraMeshes(root)
                if typeof(root) ~= "Instance" then
                        return
                end
                for _, obj in ipairs(root:GetDescendants()) do
                        if obj:GetAttribute("__h2oCustomTripmineExtraMesh") then
                                obj:Destroy()
                        end
                end
        end

        local function applyTripminePartVisual(part, profile)
                if not (part and part:IsA("BasePart")) then
                        return
                end
                local color = profile.Color
                if color then
                        part.Color = color
                        part.BrickColor = BrickColor.new(color)
                end
                part.Material = profile.Material or Enum.Material.SmoothPlastic
                if profile.Reflectance then
                        part.Reflectance = profile.Reflectance
                end
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
                part.Massless = true
                if part:GetAttribute("WrapGroup") == nil then
                        part:SetAttribute("WrapGroup", 1)
                end
                part:SetAttribute("IgnoreTransparency", true)
                pcall(function()
                        collectionService:AddTag(part, "Wrappable")
                end)
        end

        local function addTripmineExtraMeshPart(basePart, meshId, meshScale, profile, index)
                if not (basePart and basePart:IsA("BasePart") and basePart.Parent) then
                        return nil
                end
                local overlay = Instance.new("Part")
                overlay.Name = "__h2oCustomTripmineMeshExtra" .. tostring(index or "")
                overlay.Anchored = basePart.Anchored
                overlay.CFrame = basePart.CFrame
                overlay.Size = basePart.Size
                overlay:SetAttribute("__h2oCustomTripmineMeshPart", true)
                overlay:SetAttribute("__h2oCustomTripmineExtraMesh", true)
                applyTripminePartVisual(overlay, profile)
                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Enum.MeshType.FileMesh
                mesh.MeshId = meshId
                if profile.ClearTexture then
                        pcall(function()
                                mesh.TextureId = ""
                        end)
                elseif profile.TextureId then
                        pcall(function()
                                mesh.TextureId = profile.TextureId
                        end)
                end
                mesh.Scale = meshScale
                pcall(function()
                        mesh.VertexColor = Vector3.new(1, 1, 1)
                end)
                mesh.Parent = overlay
                overlay.Parent = basePart.Parent
                local weld = Instance.new("WeldConstraint")
                weld.Name = "__h2oCustomTripmineMeshExtraWeld"
                weld.Part0 = basePart
                weld.Part1 = overlay
                weld.Parent = overlay
                return overlay
        end

        local function applyTripmineMeshProfile(root, profile, worldVisual)
                if typeof(root) ~= "Instance" or not profile then
                        return false
                end
                local meshIds = getTripmineMeshIds(profile)
                if #meshIds == 0 then
                        return false
                end
                local extraMeshScale = getTripmineExtraMeshScale(profile, worldVisual)
                local meshSignature = getTripmineMeshSignature(profile, worldVisual)
                local meshScale = (worldVisual and profile.WorldScale) or profile.Scale or 1
                if root:GetAttribute("__h2oTripmineMeshSkin") == profile.Skin
                        and root:GetAttribute("__h2oCustomTripmineMeshIds") == meshSignature
                        and root:GetAttribute("__h2oCustomTripmineMeshScale") == meshScale then
                        return true
                end
                removeCustomTripmineExtraMeshes(root)
                removeTripmineMeshAsset(root, profile.RemoveMeshId or profile.HideMeshId)
                local target = findCustomTripmineMeshTarget(root, profile)
                if not target then
                        return false
                end
                local customPart
                if target:IsA("SpecialMesh") then
                        pcall(function()
                                target.MeshType = Enum.MeshType.FileMesh
                        end)
                        target.MeshId = meshIds[1]
                        if profile.TextureId then
                                pcall(function()
                                        target.TextureId = profile.TextureId
                                end)
                        elseif profile.ClearTexture then
                                pcall(function()
                                        target.TextureId = ""
                                end)
                        end
                        target.Scale = target.Scale * meshScale
                        pcall(function()
                                target.VertexColor = Vector3.new(1, 1, 1)
                        end)
                        customPart = target.Parent
                        applyTripminePartVisual(customPart, profile)
                        for index = 2, #meshIds do
                                addTripmineExtraMeshPart(customPart, meshIds[index], scaleTripmineMeshVector(target.Scale, extraMeshScale), profile, index)
                        end
                elseif target:IsA("MeshPart") then
                        local originalSize = target.Size
                        local okMesh = pcall(function()
                                target.MeshId = meshIds[1]
                        end)
                        if profile.TextureId then
                                pcall(function()
                                        target.TextureID = profile.TextureId
                                end)
                        elseif profile.ClearTexture then
                                pcall(function()
                                        target.TextureID = ""
                                end)
                        end
                        applyTripminePartVisual(target, profile)
                        if okMesh then
                                pcall(function()
                                        target.Size = originalSize * meshScale
                                end)
                                customPart = target
                                for index = 2, #meshIds do
                                        addTripmineExtraMeshPart(target, meshIds[index], scaleTripmineMeshVector(Vector3.new(1, 1, 1), extraMeshScale), profile, index)
                                end
                        elseif target.Parent then
                                pcall(function()
                                        target.Transparency = 1
                                        target.LocalTransparencyModifier = 1
                                end)
                                local overlay = target.Parent:FindFirstChild("__h2oCustomTripmineMesh")
                                if not (overlay and overlay:IsA("BasePart")) then
                                        overlay = Instance.new("Part")
                                        overlay.Name = "__h2oCustomTripmineMesh"
                                        overlay.Anchored = target.Anchored
                                        overlay.CanCollide = false
                                        overlay.CanTouch = false
                                        overlay.CanQuery = false
                                        overlay.Massless = true
                                        overlay.Parent = target.Parent
                                end
                                overlay.Size = originalSize
                                overlay.CFrame = target.CFrame
                                applyTripminePartVisual(overlay, profile)
                                local mesh = overlay:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
                                mesh.MeshType = Enum.MeshType.FileMesh
                                mesh.MeshId = meshIds[1]
                                if profile.TextureId then
                                        pcall(function()
                                                mesh.TextureId = profile.TextureId
                                        end)
                                elseif profile.ClearTexture then
                                        pcall(function()
                                                mesh.TextureId = ""
                                        end)
                                end
                                mesh.Scale = Vector3.new(meshScale, meshScale, meshScale)
                                pcall(function()
                                        mesh.VertexColor = Vector3.new(1, 1, 1)
                                end)
                                mesh.Parent = overlay
                                overlay:SetAttribute("__h2oCustomTripmineMeshPart", true)
                                customPart = overlay
                                for index = 2, #meshIds do
                                        addTripmineExtraMeshPart(overlay, meshIds[index], scaleTripmineMeshVector(meshScale, extraMeshScale), profile, index)
                                end
                                if not overlay:FindFirstChild("__h2oCustomTripmineMeshWeld") then
                                        local weld = Instance.new("WeldConstraint")
                                        weld.Name = "__h2oCustomTripmineMeshWeld"
                                        weld.Part0 = target
                                        weld.Part1 = overlay
                                        weld.Parent = overlay
                                end
                        end
                end
                if customPart and customPart:IsA("BasePart") then
                        customPart:SetAttribute("__h2oCustomTripmineMeshPart", true)
                end
                root:SetAttribute("__h2oTripmineMeshSkin", profile.Skin)
                root:SetAttribute("__h2oCustomTripmineMeshId", meshIds[1])
                root:SetAttribute("__h2oCustomTripmineMeshIds", meshSignature)
                root:SetAttribute("__h2oCustomTripmineMeshScale", meshScale)
                return true
        end

        local function joinSignature(parts)
                return table.concat(parts, "|")
        end

        local function vecParts(v)
                if typeof(v) ~= "Vector3" then
                        v = Vector3.zero
                end
                return { tostring(v.X), tostring(v.Y), tostring(v.Z) }
        end

        local function finalizeProfiles()
                local function finalize(table, build)
                        for _, profile in pairs(table) do
                                profile.Signature = joinSignature(build(profile)) .. "|" .. tostring(profile.ReplacementVersion or 1)
                        end
                end
                finalize(DAGGERS_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { table.concat(p.SourceMeshIds or {}, ","), tostring(p.ReplacementMeshId or ""), tostring(p.ReplacementTextureId or "") }
                        table.insert(parts, table.concat(vecParts(p.ReplacementSize), ","))
                        table.insert(parts, table.concat(vecParts(p.ReplacementRotation), ","))
                        return parts
                end)
                finalize(SATCHEL_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { table.concat(p.SourceMeshIds or {}, ","), tostring(p.ReplacementMeshId or ""), tostring(p.ReplacementTextureId or "") }
                        table.insert(parts, table.concat(vecParts(p.ReplacementSize), ","))
                        table.insert(parts, table.concat(vecParts(p.ReplacementRotation), ","))
                        return parts
                end)
                finalize(RPG_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { table.concat(p.BodyMeshIds or {}, ","), table.concat(p.JuggleMeshIds or {}, ","), table.concat(p.RocketMeshIds or {}, ","), tostring(p.BodyReplacementMeshId or ""), tostring(p.BodyReplacementTextureId or ""), tostring(p.ReplacementScale or 1) }
                        table.insert(parts, table.concat(vecParts(p.ReplacementRotation), ","))
                        table.insert(parts, table.concat(vecParts(p.ReplacementOffset), ","))
                        return parts
                end)
                finalize(FISTS_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { tostring(p.LeftMeshId or ""), tostring(p.LeftTextureId or ""), tostring(p.RightMeshId or ""), tostring(p.RightTextureId or "") }
                        table.insert(parts, table.concat(vecParts(p.MeshScale), ","))
                        table.insert(parts, table.concat(vecParts(p.LeftRotation), ","))
                        table.insert(parts, table.concat(vecParts(p.RightRotation), ","))
                        return parts
                end)
                finalize(BOW_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { table.concat(p.BodyMeshIds or {}, ","), table.concat(p.ArrowMeshIds or {}, ","), tostring(p.BodyReplacementMeshId or ""), tostring(p.BodyReplacementTextureId or ""), tostring(p.ArrowReplacementMeshId or ""), tostring(p.ArrowReplacementTextureId or "") }
                        table.insert(parts, table.concat(vecParts(p.ReplacementSize), ","))
                        return parts
                end)
                finalize(ASSAULT_RIFLE_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { table.concat(p.BodyMeshIds or {}, ","), table.concat(p.BoltMeshIds or {}, ","), table.concat(p.MagazineMeshIds or {}, ","), table.concat(p.ReloadMagazineMeshIds or {}, ","), tostring(p.BodyReplacementMeshId or ""), tostring(p.BodyReplacementTextureId or ""), tostring(p.MagazineReplacementMeshId or ""), tostring(p.MagazineReplacementTextureId or ""), tostring(p.ReloadMagazineReplacementMeshId or ""), tostring(p.ReloadMagazineReplacementTextureId or "") }
                        table.insert(parts, table.concat(vecParts(p.ReplacementSize), ","))
                        table.insert(parts, table.concat(vecParts(p.ReplacementOffset), ","))
                        table.insert(parts, table.concat(vecParts(p.MagazineOffset), ","))
                        return parts
                end)
                finalize(SNIPER_MESH_SKIN_OVERRIDES, function(p)
                        local parts = { table.concat(p.BodyMeshIds or {}, ","), table.concat(p.RemoveMeshIds or {}, ","), table.concat(p.MagazineMeshIds or {}, ","), table.concat(p.BulletMeshIds or {}, ","), tostring(p.ReplacementMeshId or ""), tostring(p.ReplacementTextureId or ""), tostring(p.BodyReplacementMeshId or ""), tostring(p.BodyReplacementTextureId or ""), tostring(p.ScopeReplacementMeshId or ""), tostring(p.ScopeReplacementTextureId or ""), tostring(p.MagazineReplacementMeshId or ""), tostring(p.MagazineReplacementTextureId or "") }
                        table.insert(parts, table.concat(vecParts(p.ReplacementSize), ","))
                        table.insert(parts, table.concat(vecParts(p.ReplacementOffset), ","))
                        table.insert(parts, table.concat(vecParts(p.ScopeOffset), ","))
                        table.insert(parts, table.concat(vecParts(p.MagazineOffset), ","))
                        table.insert(parts, table.concat(vecParts(p.BulletOffset), ","))
                        return parts
                end)
        end

        finalizeProfiles()

        local function applyVirtualViewModelAssetOverrides(cosmeticName, asset, worldAsset)
                local profile = TRIPMINE_MESH_SKIN_OVERRIDES[cosmeticName]
                if profile then
                        applyTripmineMeshProfile(asset, profile)
                end
                local daggerProfile = DAGGERS_MESH_SKIN_OVERRIDES[cosmeticName]
                if daggerProfile then
                        applyDaggerMeshProfile(asset, daggerProfile)
                end
                local satchelProfile = getSatchelMeshProfileForAsset(cosmeticName, worldAsset)
                if satchelProfile then
                        applySatchelMeshProfile(asset, satchelProfile)
                end
                local rpgProfile = RPG_MESH_SKIN_OVERRIDES[cosmeticName]
                if rpgProfile then
                        applyRpgMeshProfile(asset, rpgProfile)
                end
                local fistsProfile = FISTS_MESH_SKIN_OVERRIDES[cosmeticName]
                if fistsProfile then
                        applyFistsMeshProfile(asset, fistsProfile)
                end
                local bowProfile = BOW_MESH_SKIN_OVERRIDES[cosmeticName]
                if bowProfile then
                        applyBowMeshProfile(asset, bowProfile)
                end
                local assaultRifleProfile = ASSAULT_RIFLE_MESH_SKIN_OVERRIDES[cosmeticName]
                if assaultRifleProfile then
                        applyAssaultRifleMeshProfile(asset, assaultRifleProfile)
                end
                local sniperProfile = SNIPER_MESH_SKIN_OVERRIDES[cosmeticName]
                if sniperProfile then
                        applySniperMeshProfile(asset, sniperProfile)
                end
        end

        local function shouldRebuildVirtualViewModelAsset(cosmeticName, asset, worldAsset)
                local profile = TRIPMINE_MESH_SKIN_OVERRIDES[cosmeticName]
                if profile then
                        local meshIds = getTripmineMeshIds(profile)
                        return not asset
                                or asset:GetAttribute("__h2oTripmineMeshSkin") ~= profile.Skin
                                or asset:GetAttribute("__h2oCustomTripmineMeshIds") ~= getTripmineMeshSignature(profile)
                                or asset:GetAttribute("__h2oCustomTripmineMeshScale") ~= (profile.Scale or 1)
                                or asset:GetAttribute("__h2oCustomTripmineMeshId") ~= meshIds[1]
                end
                local sniperProfile = SNIPER_MESH_SKIN_OVERRIDES[cosmeticName]
                if sniperProfile then
                        return not asset
                                or asset:GetAttribute("__h2oSniperMeshSkin") ~= sniperProfile.Skin
                                or asset:GetAttribute("__h2oSniperMeshSignature") ~= sniperProfile.Signature
                                or not asset:FindFirstChild("__h2oCustomSniperReplacement", true)
                end
                local daggerProfile = DAGGERS_MESH_SKIN_OVERRIDES[cosmeticName]
                if daggerProfile then
                        return not asset
                                or asset:GetAttribute("__h2oDaggerMeshSkin") ~= daggerProfile.Skin
                                or asset:GetAttribute("__h2oDaggerMeshSignature") ~= daggerProfile.Signature
                                or (asset:GetAttribute("__h2oDaggerMeshCount") or 0) <= 0
                end
                local satchelProfile = getSatchelMeshProfileForAsset(cosmeticName, worldAsset)
                if satchelProfile then
                        return not asset
                                or asset:GetAttribute("__h2oSatchelMeshSkin") ~= satchelProfile.Skin
                                or asset:GetAttribute("__h2oSatchelMeshSignature") ~= satchelProfile.Signature
                                or (asset:GetAttribute("__h2oSatchelMeshCount") or 0) <= 0
                end
                local rpgProfile = RPG_MESH_SKIN_OVERRIDES[cosmeticName]
                if rpgProfile then
                        return not asset
                                or asset:GetAttribute("__h2oRpgMeshSkin") ~= rpgProfile.Skin
                                or asset:GetAttribute("__h2oRpgMeshSignature") ~= rpgProfile.Signature
                                or asset:GetAttribute("__h2oRpgRocketVisible") ~= false
                                or ((asset:GetAttribute("__h2oRpgMeshCount") or 0) + (asset:GetAttribute("__h2oRpgHiddenCount") or 0)) <= 0
                end
                local fistsProfile = FISTS_MESH_SKIN_OVERRIDES[cosmeticName]
                if fistsProfile then
                        return not asset
                                or asset:GetAttribute("__h2oFistsMeshSkin") ~= fistsProfile.Skin
                                or asset:GetAttribute("__h2oFistsMeshSignature") ~= fistsProfile.Signature
                                or (asset:GetAttribute("__h2oFistsMeshCount") or 0) <= 0
                end
                local bowProfile = BOW_MESH_SKIN_OVERRIDES[cosmeticName]
                if bowProfile then
                        return not asset
                                or asset:GetAttribute("__h2oBowMeshSkin") ~= bowProfile.Skin
                                or asset:GetAttribute("__h2oBowMeshSignature") ~= bowProfile.Signature
                                or (asset:GetAttribute("__h2oBowMeshCount") or 0) <= 0
                end
                local assaultRifleProfile = ASSAULT_RIFLE_MESH_SKIN_OVERRIDES[cosmeticName]
                if assaultRifleProfile then
                        return not asset
                                or asset:GetAttribute("__h2oAssaultRifleMeshSkin") ~= assaultRifleProfile.Skin
                                or asset:GetAttribute("__h2oAssaultRifleMeshSignature") ~= assaultRifleProfile.Signature
                                or (asset:GetAttribute("__h2oAssaultRifleMeshCount") or 0) <= 0
                end
                return false
        end

    local itemLibrary = nil
    local catalogModule = nil
    local replicatedClass = nil
    local wrapController = nil
    local clientViewModelClass = nil
    local clientViewModelBaseNew = nil
    local currentVmWeapon = nil
    local constructingVirtual = false
    local virtualSkinsRegistered = false
    local classHooksInstalled = false
    local worldHooksInstalled = false
    local rpgProjectileConn = nil

    local function ensureItemLibrary()
        if itemLibrary then
            return true
        end
        pcall(function()
            local module = remote("Modules", "ItemLibrary")
            if module then
                itemLibrary = require(module)
            end
        end)
        return type(itemLibrary) == "table"
    end

    local function ensureCatalogModule()
        if type(catalogModule) == "table" and type(catalogModule.Cosmetics) == "table" then
            return true
        end
        pcall(function()
            local module = remote("Modules", "CosmeticLibrary")
            if module then
                catalogModule = require(module)
            end
        end)
        return type(catalogModule) == "table" and type(catalogModule.Cosmetics) == "table"
    end

    local function ensureReplicatedClass()
        if replicatedClass then
            return true
        end
        pcall(function()
            local module = remote("Modules", "ReplicatedClass")
            if module then
                replicatedClass = require(module)
            end
        end)
        return replicatedClass ~= nil
    end

    local function ensureWrapController()
        if wrapController then
            return true
        end
        pcall(function()
            wrapController = require(LocalPlayer.PlayerScripts.Controllers.WrapController)
        end)
        return wrapController ~= nil
    end

    local function getFighter()
        local ok, controller = pcall(function()
            return require(LocalPlayer.PlayerScripts.Controllers.FighterController)
        end)
        if ok and type(controller) == "table" then
            local ok2, fighter = pcall(function()
                return controller:GetFighter(LocalPlayer)
            end)
            if ok2 and fighter then
                return fighter
            end
            return controller.LocalFighter
        end
        return nil
    end

    local function getLocalItem(weapon)
        local fighter = getFighter()
        for _, item in pairs(fighter and fighter.Items or {}) do
            if item.Name == weapon then
                return item
            end
        end
        return nil
    end

    local function getWorldSkinName(weapon)
        local skinName = equips[weapon] and equips[weapon].Skin
        local entry = skinName and catalogEntries[skinName]
        return entry and (entry.WorldViewModelName or entry.SourceViewModelName or entry.ViewModelName or entry.Name)
    end

    local function getEquippedWeaponWrap(weapon)
        local item = getLocalItem(weapon)
        if item and item.GetWrap then
            local ok, wrap = pcall(item.GetWrap, item)
            if ok then
                return wrap
            end
        end
        local skinName = equips[weapon] and equips[weapon].Wrap
        return skinName and cloneCosmetic(skinName)
    end

    local function isLocalPlacedObject(object, weapon)
        if typeof(object) ~= "Instance" then
            return false
        end
        local userId = object:GetAttribute("PlacedByUserID")
            or object:GetAttribute("ThrownByUserID")
            or object:GetAttribute("OwnerUserID")
        if userId ~= nil then
            return tonumber(userId) == LocalPlayer.UserId
        end
        local objectId = object:GetAttribute("ObjectID")
        local item = getLocalItem(weapon)
        return objectId ~= nil and item ~= nil and item.Get ~= nil and item:Get("ObjectID") == objectId
    end

    local function getEquippedWeaponName()
        local fighter = getFighter()
        for _, item in pairs(fighter and fighter.Items or {}) do
            if item.IsEquipped then
                return item.Name
            end
        end
        return nil
    end

    local virtualViewModelClassOverrides = {
        [KNIFE_CUSTOM_SKIN] = "Knife",
        [REAVER_KNIFE_CUSTOM_SKIN] = "Knife",
        [DAGGERS_CUSTOM_SKIN] = "Keynais",
        [SNIPER_CUSTOM_SKIN] = "Keyper",
        ["Operator"] = "Sniper",
        [RPG_CUSTOM_SKIN] = "Nuke Launcher",
        [FISTS_CUSTOM_SKIN] = "Fists",
        [BOW_CUSTOM_SKIN] = "Frostbite Bow",
        [ASSAULT_RIFLE_CUSTOM_SKIN] = "AK-47",
        ["Grenade (Custom Skin)"] = "Elixir",
        ["Grenade Raze"] = "Glorious Grenade",
        ["sky"] = "Shining Star",
        ["Molotov (Custom Skin)"] = "Elixir",
        ["Satchel (Custom Skin)"] = "Elixir",
        ["Smoke Grenade (Custom Skin)"] = "Elixir",
        ["Warpstone (Custom Skin)"] = "Elixir",
        [SATCHEL_CUSTOM_SKIN] = "BaseSatchel",
        [DICE_TRIPMINE_SKIN] = "SubspaceTripmine",
        [SPIKE_TRIPMINE_SKIN] = "SubspaceTripmine",
    }

    local function resolveViewModelClassName(_, resolvedName)
        return (resolvedName and virtualViewModelClassOverrides[resolvedName]) or resolvedName
    end

    local viewModelClassCache = {}
    local function normalizeViewModelName(name)
        return tostring(name or ""):gsub("[%W_]+", ""):lower()
    end

    local function resolveViewModelClass(name)
        if not clientViewModelClass then
            return nil
        end
        local key = normalizeViewModelName(name)
        if viewModelClassCache[key] ~= nil then
            return viewModelClassCache[key] or clientViewModelClass
        end
        local targetClass = clientViewModelClass
        pcall(function()
            local vmFolder = LocalPlayer.PlayerScripts.Modules:FindFirstChild("ViewModels")
            if vmFolder then
                for _, module in pairs(vmFolder:GetDescendants()) do
                    if module:IsA("ModuleScript") and normalizeViewModelName(module.Name) == key then
                        local ok, customClass = pcall(require, module)
                        if ok and type(customClass) == "table" and type(customClass.new) == "function" then
                            targetClass = customClass
                        end
                        break
                    end
                end
            end
        end)
        viewModelClassCache[key] = targetClass
        return targetClass
    end

    local function usesSourceAnimations(cosmeticName)
        return SNIPER_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or DAGGERS_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or SATCHEL_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or RPG_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or FISTS_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or BOW_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or ASSAULT_RIFLE_MESH_SKIN_OVERRIDES[cosmeticName] ~= nil
            or cosmeticName == KNIFE_CUSTOM_SKIN
            or cosmeticName == "Grenade (Custom Skin)"
            or cosmeticName == "Molotov (Custom Skin)"
            or cosmeticName == "Satchel (Custom Skin)"
            or cosmeticName == "Smoke Grenade (Custom Skin)"
            or cosmeticName == "Warpstone (Custom Skin)"
            or cosmeticName == "sky"
    end

    local function ensureVirtualViewModel(cosmeticName, itemName, viewModelName)
        if not ensureItemLibrary() or not itemLibrary.ViewModels then
            return nil
        end
        local sourceInfo = itemLibrary.ViewModels[viewModelName]
        if not sourceInfo then
            return nil
        end
        if cosmeticName ~= viewModelName then
            local animationInfo = usesSourceAnimations(cosmeticName) and sourceInfo or itemLibrary.ViewModels[itemName]
            local baseInfo = animationInfo or sourceInfo
            local virtualInfo = table.clone(sourceInfo)
            if type(baseInfo.Animations) == "table" then
                virtualInfo.Animations = table.clone(baseInfo.Animations)
            end
            itemLibrary.ViewModels[cosmeticName] = virtualInfo
            pcall(function()
                local viewModelAssets = LocalPlayer.PlayerScripts.Assets and LocalPlayer.PlayerScripts.Assets:FindFirstChild("ViewModels")
                if not viewModelAssets then
                    return
                end
                local existingAsset = findDescendantByName(viewModelAssets, cosmeticName)
                if existingAsset then
                    if shouldRebuildVirtualViewModelAsset(cosmeticName, existingAsset, false) then
                        existingAsset:Destroy()
                    else
                        applyVirtualViewModelAssetOverrides(cosmeticName, existingAsset, false)
                        return
                    end
                end
                local sourceAsset = findDescendantByName(viewModelAssets, viewModelName)
                if sourceAsset then
                    local clonedAsset = sourceAsset:Clone()
                    clonedAsset.Name = cosmeticName
                    applyVirtualViewModelAssetOverrides(cosmeticName, clonedAsset, false)
                    clonedAsset.Parent = viewModelAssets
                end
            end)
            pcall(function()
                local throwables = LocalPlayer.PlayerScripts.Assets and LocalPlayer.PlayerScripts.Assets:FindFirstChild("Throwables")
                if not throwables then
                    return
                end
                local existingThrowable = throwables:FindFirstChild(cosmeticName)
                if existingThrowable then
                    if shouldRebuildVirtualViewModelAsset(cosmeticName, existingThrowable, true) then
                        existingThrowable:Destroy()
                    else
                        applyVirtualViewModelAssetOverrides(cosmeticName, existingThrowable, true)
                        return
                    end
                end
                local sourceThrowable = findDescendantByName(throwables, viewModelName)
                if sourceThrowable then
                    local clonedThrowable = sourceThrowable:Clone()
                    clonedThrowable.Name = cosmeticName
                    applyVirtualViewModelAssetOverrides(cosmeticName, clonedThrowable, true)
                    clonedThrowable.Parent = throwables
                end
            end)
            pcall(function()
                if itemName ~= "Jump Pad" then
                    return
                end
                local misc = LocalPlayer.PlayerScripts.Assets and LocalPlayer.PlayerScripts.Assets:FindFirstChild("Misc")
                local jumpPads = misc and misc:FindFirstChild("JumpPads")
                if not jumpPads then
                    return
                end
                local existingJumpPad = jumpPads:FindFirstChild(cosmeticName)
                if existingJumpPad then
                    if shouldRebuildVirtualViewModelAsset(cosmeticName, existingJumpPad, true) then
                        existingJumpPad:Destroy()
                    else
                        applyVirtualViewModelAssetOverrides(cosmeticName, existingJumpPad, true)
                        return
                    end
                end
                local sourceJumpPad = jumpPads:FindFirstChild(viewModelName) or jumpPads:FindFirstChild("Default")
                if sourceJumpPad then
                    local clonedJumpPad = sourceJumpPad:Clone()
                    clonedJumpPad.Name = cosmeticName
                    applyVirtualViewModelAssetOverrides(cosmeticName, clonedJumpPad, true)
                    clonedJumpPad.Parent = jumpPads
                end
            end)
        end
        return sourceInfo
    end

    local function registerVirtualWeaponSkin(cosmeticName, itemName, viewModelName, rarity, displayName, worldViewModelName)
        local viewModelInfo = ensureVirtualViewModel(cosmeticName, itemName, viewModelName)
        if not viewModelInfo then
            return
        end
        local imageInfo = cosmeticName == DICE_TRIPMINE_SKIN and itemLibrary.ViewModels and itemLibrary.ViewModels["RNG Dice"] or viewModelInfo
        local image = imageInfo.Image or ""
        local imageHighResolution = imageInfo.ImageHighResolution or imageInfo.Image or ""
        local imageOverride = CUSTOM_SKIN_IMAGE_OVERRIDES[cosmeticName]
        if imageOverride then
            image = imageOverride.Image or ""
            imageHighResolution = imageOverride.ImageHighResolution or imageOverride.Image or ""
        end
        local entry = {
            Rarity = rarity or "Contraband",
            Type = "Skin",
            DisplayName = displayName or cosmeticName,
            ViewModelName = cosmeticName,
            SourceViewModelName = viewModelName,
            WorldViewModelName = worldViewModelName or viewModelName,
            Image = image,
            ImageHighResolution = imageHighResolution,
            ImageScale = 3,
            ItemName = itemName,
            Owned = true,
            Unlocked = true,
            Locked = false,
        }
        catalogModule.Cosmetics[cosmeticName] = entry
        catalogEntries[cosmeticName] = entry
        if not table.find(typeLists.Skin, cosmeticName) then
            table.insert(typeLists.Skin, cosmeticName)
        end
        if itemLibrary.ViewModels and itemLibrary.ViewModels[cosmeticName] then
            itemLibrary.ViewModels[cosmeticName].Image = image
            itemLibrary.ViewModels[cosmeticName].ImageHighResolution = imageHighResolution
        end
    end

    local function registerVirtualSkins()
        if virtualSkinsRegistered or not catalogLoaded then
            return false
        end
        if not ensureCatalogModule() or not ensureItemLibrary() then
            return false
        end
        pcall(function()
            catalogModule.Cosmetics["Flashbang (Custom Skin)"] = nil
            if itemLibrary.ViewModels then
                itemLibrary.ViewModels["Flashbang (Custom Skin)"] = nil
            end
        end)
        registerVirtualWeaponSkin(KNIFE_CUSTOM_SKIN, "Knife", "Glast Shard", "Contraband")
        registerVirtualWeaponSkin(REAVER_KNIFE_CUSTOM_SKIN, "Knife", "Pencil", "Contraband", "reaver")
        registerVirtualWeaponSkin(DAGGERS_CUSTOM_SKIN, "Daggers", "Keynais", "Contraband")
        registerVirtualWeaponSkin("Grenade (Custom Skin)", "Grenade", "Elixir", "Contraband")
        registerVirtualWeaponSkin("Grenade Raze", "Grenade", "Glorious Grenade", "Contraband", "Raze")
        registerVirtualWeaponSkin("sky", "Flashbang", "Shining Star", "Contraband")
        registerVirtualWeaponSkin("Molotov (Custom Skin)", "Molotov", "Elixir", "Contraband", "Elixir")
        registerVirtualWeaponSkin("Satchel (Custom Skin)", "Satchel", "Elixir", "Contraband")
        registerVirtualWeaponSkin(SATCHEL_CUSTOM_SKIN, "Satchel", "Satchel", "Contraband", "Raze", SATCHEL_CUSTOM_SKIN)
        registerVirtualWeaponSkin("Smoke Grenade (Custom Skin)", "Smoke Grenade", "Elixir", "Contraband")
        registerVirtualWeaponSkin("Warpstone (Custom Skin)", "Warpstone", "Elixir", "Contraband")
        registerVirtualWeaponSkin("Scythe (Custom Skin)", "Scythe", "Scepter", "Contraband")
        registerVirtualWeaponSkin("Katana (Custom Skin)", "Katana", "Scepter", "Contraband")
        registerVirtualWeaponSkin("Spear (Custom Skin)", "Spear", "Scepter", "Contraband")
        registerVirtualWeaponSkin("Handgun (Custom Skin)", "Handgun", "Glass Cannon", "Contraband")
        registerVirtualWeaponSkin(SNIPER_CUSTOM_SKIN, "Sniper", "Keyper", "Contraband")
        registerVirtualWeaponSkin("Operator", "Sniper", "Sniper", "Contraband")
        registerVirtualWeaponSkin("Medkit (Custom Skin)", "Medkit", "RNG Dice", "Contraband")
        registerVirtualWeaponSkin(RPG_CUSTOM_SKIN, "RPG", "Nuke Launcher", "Contraband", "Raze", RPG_CUSTOM_SKIN)
        registerVirtualWeaponSkin(FISTS_CUSTOM_SKIN, "Fists", "Fists", "Contraband", "Agent")
        registerVirtualWeaponSkin(BOW_CUSTOM_SKIN, "Bow", "Frostbite Bow", "Contraband")
        registerVirtualWeaponSkin(ASSAULT_RIFLE_CUSTOM_SKIN, "Assault Rifle", "AK-47", "Contraband")
        registerVirtualWeaponSkin("Camera", "Jump Pad", "Jump Pad", "Contraband", "Camera", "Camera")
        registerVirtualWeaponSkin(DICE_TRIPMINE_SKIN, "Subspace Tripmine", "Subspace Tripmine", "Contraband", nil, DICE_TRIPMINE_SKIN)
        registerVirtualWeaponSkin(SPIKE_TRIPMINE_SKIN, "Subspace Tripmine", "Subspace Tripmine", "Contraband", "Spike", SPIKE_TRIPMINE_SKIN)
        table.sort(typeLists.Skin)
        virtualSkinsRegistered = true
        return true
    end

    local function applyLiveFistsMeshProfile(wname, viewModel)
        if wname ~= "Fists" then
            return
        end
        local skinName = equips[wname] and equips[wname].Skin
        local profile = skinName and FISTS_MESH_SKIN_OVERRIDES[skinName]
        if not profile then
            return
        end
        task.spawn(function()
            for _ = 1, 30 do
                local model
                if typeof(viewModel) == "Instance" then
                    model = viewModel
                elseif type(viewModel) == "table" then
                    model = viewModel.Model or viewModel.ItemModel
                end
                if typeof(model) == "Instance" then
                    if applyFistsMeshProfile(model, profile) then
                        return
                    end
                end
                task.wait()
            end
        end)
    end

    local function mutateItemData(self, vmref, toEnum)
        local weq = equips[self.Name]
        if not weq or not next(weq) then
            return nil
        end
        local dk = toEnum("Data")
        local data = vmref[dk] or vmref.Data or {}
        local skinName = weq.Skin
        local resolvedName = self.Name
        if skinName and catalogEntries[skinName] then
            local entry = catalogEntries[skinName]
            resolvedName = entry.ViewModelName or entry.Name or skinName
            data[toEnum("Skin")] = cloneCosmetic(skinName)
        end
        data[toEnum("Name")] = resolvedName
        if weq.Wrap and catalogEntries[weq.Wrap] then
            data[toEnum("Wrap")] = cloneCosmetic(weq.Wrap)
        end
        if weq.Charm and catalogEntries[weq.Charm] then
            data[toEnum("Charm")] = cloneCosmetic(weq.Charm)
        end
        data.Skin = nil
        data.Name = nil
        data.Wrap = nil
        data.Charm = nil
        if vmref[dk] ~= nil or vmref.Data == nil then
            vmref[dk] = data
            vmref.Data = nil
        else
            vmref.Data = data
        end
        return resolvedName
    end

    local function ensureClassHooks()
        if classHooksInstalled then
            return true
        end
        local okItem, clientItem = pcall(function()
            return require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
        end)
        if not okItem or type(clientItem) ~= "table" or type(clientItem._CreateViewModel) ~= "function" then
            return false
        end
        pcall(function()
            local vmModule = LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel")
            if vmModule then
                local vmClass = require(vmModule)
                if type(vmClass) == "table" then
                    clientViewModelClass = vmClass
                end
            end
        end)
        ensureReplicatedClass()
        ensureWrapController()
        local origCreate = clientItem._CreateViewModel
        clientItem._CreateViewModel = function(self, vmref)
            local fighter = self.ClientFighter
            local owner = fighter and fighter.Player
            currentVmWeapon = (owner == LocalPlayer) and self.Name or nil
            local directClass
            pcall(function()
                if not Toggles.skinchanger_enabled.Value or owner ~= LocalPlayer or not vmref then
                    return
                end
                if not (equips[self.Name] and next(equips[self.Name])) then
                    return
                end
                local resolvedName = mutateItemData(self, vmref, function(key)
                    return self:ToEnum(key)
                end)
                if resolvedName then
                    local className = resolveViewModelClassName(self.Name, resolvedName)
                    if className ~= resolvedName then
                        directClass = resolveViewModelClass(className)
                    end
                end
            end)
            if directClass and directClass ~= clientViewModelClass and directClass.new then
                local identity = getIdentity()
                constructingVirtual = true
                local ok, res = pcall(function()
                    setIdentity(2)
                    return directClass.new(vmref, self)
                end)
                constructingVirtual = false
                setIdentity(identity)
                currentVmWeapon = nil
                if ok then
                    applyLiveFistsMeshProfile(self.Name, res)
                    return res
                end
            end
            local res = origCreate(self, vmref)
            currentVmWeapon = nil
            pcall(function()
                if Toggles.skinchanger_enabled.Value and owner == LocalPlayer then
                    applyLiveFistsMeshProfile(self.Name, res)
                end
            end)
            return res
        end
        if clientViewModelClass then
            local cvm = clientViewModelClass
            clientViewModelBaseNew = cvm.new
            if type(cvm.new) == "function" then
                cvm.new = function(rdata, cliitm)
                    if constructingVirtual then
                        return clientViewModelBaseNew(rdata, cliitm)
                    end
                    local wplr = cliitm and cliitm.ClientFighter and cliitm.ClientFighter.Player
                    local wname = currentVmWeapon or (cliitm and cliitm.Name)
                    local className = wname
                    pcall(function()
                        if not Toggles.skinchanger_enabled.Value or wplr ~= LocalPlayer or not (equips[wname] and next(equips[wname])) or not replicatedClass then
                            return
                        end
                        local rdataResolved = mutateItemData({ Name = wname }, rdata, function(key)
                            return replicatedClass:ToEnum(key)
                        end)
                        if rdataResolved then
                            className = resolveViewModelClassName(wname, rdataResolved)
                        end
                    end)
                    local targetNew = clientViewModelBaseNew
                    local targetClass = className ~= wname and resolveViewModelClass(className)
                    if targetClass and targetClass ~= clientViewModelClass and targetClass.new then
                        targetNew = targetClass.new
                    end
                    constructingVirtual = targetNew ~= clientViewModelBaseNew
                    local ok, res = pcall(targetNew, rdata, cliitm)
                    constructingVirtual = false
                    if not ok and wplr == LocalPlayer and equips[wname] and equips[wname].Skin and replicatedClass then
                        pcall(function()
                            local dk = replicatedClass:ToEnum("Data")
                            local slot = rdata[dk] or rdata.Data or {}
                            rdata[dk] = slot
                            rdata.Data = nil
                            slot[replicatedClass:ToEnum("Name")] = wname
                            slot.Name = nil
                        end)
                        ok, res = pcall(clientViewModelBaseNew, rdata, cliitm)
                    end
                    if not ok then
                        error(res)
                    end
                    pcall(function()
                        if wplr == LocalPlayer and equips[wname] and res then
                            for _, method in ipairs({ "_UpdateWrap", "UpdateWrap", "_UpdateCharm", "UpdateCharm", "_UpdateCosmetics", "UpdateCosmetics" }) do
                                if res[method] then
                                    pcall(res[method], res)
                                end
                            end
                            applyLiveFistsMeshProfile(wname, res)
                        end
                    end)
                    return res
                end
            end
            if type(cvm.GetWrap) == "function" then
                local origGetWrap = cvm.GetWrap
                cvm.GetWrap = function(self)
                    local ok2, forced = pcall(function()
                        if not Toggles.skinchanger_enabled.Value then
                            return nil
                        end
                        local item = self.ClientItem
                        local owner = item and item.ClientFighter and item.ClientFighter.Player
                        local weq = item and owner == LocalPlayer and equips[item.Name]
                        if weq and weq.Wrap and catalogEntries[weq.Wrap] then
                            return cloneCosmetic(weq.Wrap)
                        end
                        return nil
                    end)
                    if ok2 and forced then
                        return forced
                    end
                    return origGetWrap(self)
                end
            end
            if type(cvm._UpdateWrap) == "function" and wrapController then
                local oldUpdateWrap = cvm._UpdateWrap
                local function isCustomTripmineViewModel(self)
                    if not self then
                        return false
                    end
                    if TRIPMINE_MESH_SKIN_OVERRIDES[self.Name] then
                        return true
                    end
                    local ci = self.ClientItem
                    local weapon = ci and ci.Name
                    local skinName = weapon and equips[weapon] and equips[weapon].Skin
                    return weapon == "Subspace Tripmine" and skinName ~= nil and TRIPMINE_MESH_SKIN_OVERRIDES[skinName] ~= nil
                end
                cvm._UpdateWrap = function(self, ...)
                    if isCustomTripmineViewModel(self) and self.Model then
                        local targets = {}
                        for _, descendant in ipairs(self.Model:GetDescendants()) do
                            if descendant:IsA("BasePart") and descendant:GetAttribute("__h2oCustomTripmineMeshPart") then
                                if descendant:GetAttribute("WrapGroup") == nil then
                                    descendant:SetAttribute("WrapGroup", 1)
                                end
                                descendant:SetAttribute("IgnoreTransparency", true)
                                pcall(function()
                                    collectionService:AddTag(descendant, "Wrappable")
                                end)
                                table.insert(targets, descendant)
                            end
                        end
                        if #targets > 0 then
                            local wrap = self.GetWrap and self:GetWrap() or nil
                            if self._original_wrap_properties then
                                pcall(function()
                                    wrapController.ResetWrap(wrapController, self._original_wrap_properties)
                                end)
                                self._original_wrap_properties = nil
                            end
                            if self.__h2oCustomTripmineWrapProperties then
                                pcall(function()
                                    wrapController.ResetWrap(wrapController, self.__h2oCustomTripmineWrapProperties)
                                end)
                                self.__h2oCustomTripmineWrapProperties = nil
                            end
                            if wrap then
                                self.__h2oCustomTripmineWrapProperties = wrapController:RecordOriginalWrapProperties(targets)
                                wrapController:ApplyWrap(self.__h2oCustomTripmineWrapProperties, wrap, true)
                            end
                            if self._UpdateLocalTransparencyModifiers then
                                pcall(self._UpdateLocalTransparencyModifiers, self)
                            end
                            return
                        end
                    end
                    return oldUpdateWrap(self, ...)
                end
            end
        end
        pcall(function()
            local cent = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientEntity)
            if type(cent) == "table" and cent._PlayFinisher then
                local ofin = cent._PlayFinisher
                cent._PlayFinisher = function(self, fname, ...)
                    local ewep = getEquippedWeaponName()
                    local fin = ewep and equips[ewep] and equips[ewep].Finisher
                    return ofin(self, fin or fname, ...)
                end
            end
        end)
        pcall(function()
            if ensureItemLibrary() and type(itemLibrary.GetViewModelImageFromWeaponData) == "function" then
                local ogvi = itemLibrary.GetViewModelImageFromWeaponData
                itemLibrary.GetViewModelImageFromWeaponData = function(self, wdata, hires)
                    if not wdata then
                        return ogvi(self, wdata, hires)
                    end
                    local weq = equips[wdata.Name]
                    if weq and weq.Skin then
                        local entry = catalogEntries[weq.Skin]
                        if entry then
                            local vmName = entry.ViewModelName or entry.Name
                            local srcName = entry.SourceViewModelName or vmName
                            local sinfo = self.ViewModels and (self.ViewModels[vmName] or self.ViewModels[srcName])
                            local key = hires and "ImageHighResolution" or "Image"
                            if sinfo then
                                return sinfo[key] or sinfo.Image
                            end
                            return entry[key] or entry.Image or ""
                        end
                    end
                    return ogvi(self, wdata, hires)
                end
            end
        end)
        classHooksInstalled = true
        return true
    end

    local function hideOriginalTripmineVisual(object)
        if typeof(object) ~= "Instance" then
            return
        end
        local function hide(inst)
            if inst:GetAttribute("__h2oPlacedSkin") or (inst.Parent and inst.Parent:GetAttribute("__h2oPlacedSkin")) then
                return
            end
            if inst:IsA("BasePart") then
                inst.Transparency = 1
                inst.LocalTransparencyModifier = 1
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                inst.Transparency = 1
            elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
                inst.Enabled = false
            end
        end
        for _, descendant in ipairs(object:GetDescendants()) do
            hide(descendant)
        end
        if not object:GetAttribute("__h2oHideOriginalTripmineLoop") then
            object:SetAttribute("__h2oHideOriginalTripmineLoop", true)
            task.spawn(function()
                for _ = 1, 80 do
                    if not object.Parent then
                        break
                    end
                    for _, descendant in ipairs(object:GetDescendants()) do
                        hide(descendant)
                    end
                    task.wait(0.1)
                end
                if object.Parent then
                    object:SetAttribute("__h2oHideOriginalTripmineLoop", nil)
                end
            end)
        end
    end

    local function prunePlacedTripmineVisualToCustomMesh(visual)
        if typeof(visual) ~= "Instance" then
            return
        end
        local primaryPart
        for _, descendant in ipairs(visual:GetDescendants()) do
            if descendant:IsA("BasePart") then
                if descendant:GetAttribute("__h2oCustomTripmineMeshPart") then
                    primaryPart = primaryPart or descendant
                else
                    descendant:Destroy()
                end
            end
        end
        if visual:IsA("Model") and primaryPart then
            visual.PrimaryPart = primaryPart
        end
    end

    local function forcePlacedSkinVisualVisible(visual)
        if typeof(visual) ~= "Instance" then
            return
        end
        local function show(inst)
            if inst:IsA("BasePart") and inst:GetAttribute("__h2oCustomTripmineMeshPart") then
                inst.Transparency = 0
                inst.LocalTransparencyModifier = 0
            elseif (inst:IsA("Decal") or inst:IsA("Texture")) and inst.Parent and inst.Parent:GetAttribute("__h2oCustomTripmineMeshPart") then
                inst.Transparency = 0
            end
        end
        for _, descendant in ipairs(visual:GetDescendants()) do
            show(descendant)
        end
        if not visual:GetAttribute("__h2oShowPlacedSkinLoop") then
            visual:SetAttribute("__h2oShowPlacedSkinLoop", true)
            task.spawn(function()
                for _ = 1, 100 do
                    if not visual.Parent then
                        break
                    end
                    for _, descendant in ipairs(visual:GetDescendants()) do
                        show(descendant)
                    end
                    task.wait(0.1)
                end
                if visual.Parent then
                    visual:SetAttribute("__h2oShowPlacedSkinLoop", nil)
                end
            end)
        end
    end

    local function pivotPlacedTripmineVisual(visual, hitbox, profile)
        if not (visual and visual:IsA("Model") and hitbox and hitbox:IsA("BasePart")) then
            return
        end
        pcall(function()
            local boundsCFrame, boundsSize = visual:GetBoundingBox()
            local centerOffset = visual:GetPivot():ToObjectSpace(boundsCFrame)
            local groundOffset = profile and profile.WorldGroundOffset or 0
            local targetCenterOffsetY = (-hitbox.Size.Y * 0.5) + (boundsSize.Y * 0.5) + groundOffset
            local targetBoundsCFrame = hitbox.CFrame * CFrame.new(0, targetCenterOffsetY, 0)
            visual:PivotTo(targetBoundsCFrame * centerOffset:Inverse())
        end)
    end

    local function applyPlacedTripmineWrap(visual)
        if not wrapController or typeof(visual) ~= "Instance" then
            return
        end
        local wrap = getEquippedWeaponWrap("Subspace Tripmine")
        pcall(function()
            local originalWrapProperties = wrapController:RecordOriginalWrapProperties(visual)
            wrapController:ApplyWrap(originalWrapProperties, wrap, true)
        end)
    end

    local function tryApplyRpgProjectileSkin(inst)
        local profile = RPG_MESH_SKIN_OVERRIDES[RPG_CUSTOM_SKIN]
        if not (profile and typeof(inst) == "Instance") then
            return
        end
        if getWorldSkinName("RPG") ~= RPG_CUSTOM_SKIN then
            return
        end
        pcall(function()
            local viewModels = workspace:FindFirstChild("ViewModels")
            if viewModels and inst:IsDescendantOf(viewModels) then
                return
            end
        end)
        if inst:GetAttribute("__h2oRpgProjectileSkinChecked") then
            return
        end
        local shouldApply = false
        if inst:IsA("MeshPart") or inst:IsA("SpecialMesh") then
            shouldApply = meshMatchesAnyAssetId(inst, profile.RocketMeshIds) or meshMatchesAnyAssetId(inst, profile.JuggleMeshIds)
        elseif inst:IsA("Model") then
            shouldApply = namePathContains(inst, "rocket") or namePathContains(inst, "projectile")
        end
        if not shouldApply then
            return
        end
        inst:SetAttribute("__h2oRpgProjectileSkinChecked", true)
        applyRpgMeshProfile(inst, profile, { ShowRocket = true, ForceRocket = true })
    end

    local function ensureWorldHooks()
        if worldHooksInstalled then
            return
        end
        worldHooksInstalled = true
        rpgProjectileConn = workspace.DescendantAdded:Connect(function(inst)
            task.defer(tryApplyRpgProjectileSkin, inst)
        end)
        maid(rpgProjectileConn)
        task.defer(function()
            for _, inst in ipairs(workspace:GetDescendants()) do
                tryApplyRpgProjectileSkin(inst)
            end
        end)
        pcall(function()
            local components = LocalPlayer.PlayerScripts.Modules:FindFirstChild("GameComponents")
            if not components then
                return
            end
            local jumpPads = require(components:WaitForChild("JumpPads", 10))
            if type(jumpPads) == "table" and not jumpPads.__h2oSkinHook then
                jumpPads.__h2oSkinHook = true
                local oldObjectAdded = jumpPads._ObjectAdded
                jumpPads._ObjectAdded = function(self, object)
                    pcall(function()
                        if Toggles.skinchanger_enabled.Value then
                            local skinName = getWorldSkinName("Jump Pad")
                            if skinName and isLocalPlacedObject(object, "Jump Pad") then
                                object:SetAttribute("ViewModelName", skinName)
                            end
                        end
                    end)
                    return oldObjectAdded(self, object)
                end
            end
        end)
        pcall(function()
            local components = LocalPlayer.PlayerScripts.Modules:FindFirstChild("GameComponents")
            if not components then
                return
            end
            local tripmines = require(components:WaitForChild("SubspaceTripmines", 10))
            if type(tripmines) ~= "table" or tripmines.__h2oSkinHook then
                return
            end
            tripmines.__h2oSkinHook = true
            local oldObjectAdded = tripmines._ObjectAdded
            tripmines._ObjectAdded = function(self, object)
                pcall(function()
                    if not Toggles.skinchanger_enabled.Value then
                        return
                    end
                    local skinName = getWorldSkinName("Subspace Tripmine")
                    local placedSkinName = skinName == "RNG Dice" and DICE_TRIPMINE_SKIN or skinName
                    local meshProfile = placedSkinName and TRIPMINE_MESH_SKIN_OVERRIDES[placedSkinName]
                    if meshProfile and isLocalPlacedObject(object, "Subspace Tripmine") then
                        task.defer(function()
                            if not object.Parent or object:FindFirstChild("__h2oPlacedSkin") then
                                return
                            end
                            hideOriginalTripmineVisual(object)
                            local throwables = LocalPlayer.PlayerScripts.Assets:FindFirstChild("Throwables")
                            local viewModels = LocalPlayer.PlayerScripts.Assets:FindFirstChild("ViewModels")
                            local sourceName = meshProfile.BaseAssetName or "Subspace Tripmine"
                            local source = (throwables and findDescendantByName(throwables, sourceName)) or (viewModels and findDescendantByName(viewModels, sourceName))
                            local hitbox = object:FindFirstChild("Hitbox", true)
                            if not source or not hitbox or not hitbox:IsA("BasePart") then
                                return
                            end
                            local visual = source:Clone()
                            if not applyTripmineMeshProfile(visual, meshProfile, true) then
                                visual:Destroy()
                                return
                            end
                            prunePlacedTripmineVisualToCustomMesh(visual)
                            if visual:IsA("BasePart") then
                                local model = Instance.new("Model")
                                model.Name = visual.Name
                                visual.Parent = model
                                model.PrimaryPart = visual
                                visual = model
                            end
                            if not visual:IsA("Model") then
                                return
                            end
                            for _, descendant in pairs(visual:GetDescendants()) do
                                if descendant.Name == "_right_arm" or descendant.Name == "_left_arm" or descendant.Name == "_fake" then
                                    descendant:Destroy()
                                end
                            end
                            visual.Name = "__h2oPlacedSkin"
                            visual:SetAttribute("__h2oPlacedSkin", true)
                            visual.Parent = object
                            hideOriginalTripmineVisual(object)
                            pivotPlacedTripmineVisual(visual, hitbox, meshProfile)
                            forcePlacedSkinVisualVisible(visual)
                            for _, part in pairs(visual:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.Anchored = false
                                    part.CanCollide = false
                                    part.CanTouch = false
                                    part.CanQuery = false
                                    part.Massless = true
                                    local weld = Instance.new("WeldConstraint")
                                    weld.Part0 = hitbox
                                    weld.Part1 = part
                                    weld.Parent = part
                                end
                            end
                            applyPlacedTripmineWrap(visual)
                            forcePlacedSkinVisualVisible(visual)
                        end)
                    end
                end)
                return oldObjectAdded(self, object)
            end
        end)
        pcall(function()
            local components = LocalPlayer.PlayerScripts.Modules:FindFirstChild("GameComponents")
            if not components then
                return
            end
            local fireHitboxes = require(components:WaitForChild("FireHitboxes", 10))
            local fireAssets = LocalPlayer.PlayerScripts.Assets:WaitForChild("Misc", 10):WaitForChild("FireHitboxes", 10)
            if not fireAssets:FindFirstChild("Elixir") then
                local elixirEffect = LocalPlayer.PlayerScripts.Assets.Misc:FindFirstChild("ElixirExplosionEffect")
                local defaultFire = fireAssets:FindFirstChild("Default")
                if elixirEffect and defaultFire then
                    local elixirFire = defaultFire:Clone()
                    elixirFire.Name = "Elixir"
                    for _, effect in pairs(elixirFire:GetDescendants()) do
                        if effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") then
                            effect:Destroy()
                        end
                    end
                    local primary = elixirFire:FindFirstChild("Primary")
                    local attachment = elixirEffect:FindFirstChild("Attachment")
                    if primary and attachment then
                        attachment:Clone().Parent = primary
                    end
                    elixirFire.Parent = fireAssets
                end
            end
            local function replaceFireVisual(object)
                pcall(function()
                    if not Toggles.skinchanger_enabled.Value then
                        return
                    end
                    local skinName = getWorldSkinName("Molotov")
                    if not skinName or not isLocalPlacedObject(object, "Molotov") then
                        return
                    end
                    object:SetAttribute("ViewModelName", skinName)
                    task.spawn(function()
                        local entry
                        for _ = 1, 20 do
                            entry = fireHitboxes._fire_hitboxes and fireHitboxes._fire_hitboxes[object]
                            if entry and entry.Visual then
                                break
                            end
                            task.wait()
                        end
                        if not entry or not entry.Visual or not object.Parent then
                            return
                        end
                        local source = fireAssets:FindFirstChild(skinName) or fireAssets:FindFirstChild("Default")
                        if not source then
                            return
                        end
                        local visual = source:Clone()
                        visual.Name = skinName
                        visual.PrimaryPart = visual:FindFirstChild("Primary")
                        if not visual.PrimaryPart then
                            return
                        end
                        visual.PrimaryPart.Size = object.Size
                        visual:PivotTo(object.CFrame)
                        visual.Parent = workspace
                        for _, sound in ipairs({ entry.Sound1, entry.Sound2 }) do
                            if sound then
                                sound.Parent = visual.PrimaryPart
                            end
                        end
                        local oldVisual = entry.Visual
                        entry.Visual = visual
                        oldVisual:Destroy()
                    end)
                end)
            end
            collectionService:GetInstanceAddedSignal("FireHitbox"):Connect(replaceFireVisual)
            for _, object in pairs(collectionService:GetTagged("FireHitbox")) do
                task.defer(replaceFireVisual, object)
            end
        end)
        pcall(function()
            local smokeModule = LocalPlayer.PlayerScripts.Modules:FindFirstChild("SmokeCloud")
            if not smokeModule then
                return
            end
            local smokeCloud = require(smokeModule)
            if type(smokeCloud) ~= "table" or type(smokeCloud.new) ~= "function" or smokeCloud.__h2oSkinHook then
                return
            end
            smokeCloud.__h2oSkinHook = true
            local oldNew = smokeCloud.new
            smokeCloud.new = function(...)
                local args = { ... }
                local cloud = oldNew(...)
                task.defer(function()
                    pcall(function()
                        if not Toggles.skinchanger_enabled.Value then
                            return
                        end
                        local skinName = getWorldSkinName("Smoke Grenade")
                        if skinName ~= "Elixir" or type(cloud) ~= "table" then
                            return
                        end
                        local ownerObject
                        for _, value in ipairs(args) do
                            if typeof(value) == "Instance" and isLocalPlacedObject(value, "Smoke Grenade") then
                                ownerObject = value
                                break
                            end
                        end
                        local model = cloud.Model
                        if not ownerObject then
                            for _, value in pairs(cloud) do
                                if typeof(value) == "Instance" and isLocalPlacedObject(value, "Smoke Grenade") then
                                    ownerObject = value
                                    break
                                end
                            end
                        end
                        if not ownerObject and typeof(model) == "Instance" and isLocalPlacedObject(model, "Smoke Grenade") then
                            ownerObject = model
                        end
                        if not ownerObject and typeof(model) == "Instance" then
                            local item = getLocalItem("Smoke Grenade")
                            local localObjectId = item and item.Get and item:Get("ObjectID")
                            local cloudObjectId = rawget(cloud, "ObjectID") or rawget(cloud, "_object_id")
                            if localObjectId ~= nil and cloudObjectId == localObjectId then
                                ownerObject = model
                            end
                        end
                        if not ownerObject or typeof(model) ~= "Instance" or not model.Parent then
                            return
                        end
                        if model:FindFirstChild("__h2oSmokeSkin") then
                            return
                        end
                        for _, descendant in pairs(model:GetDescendants()) do
                            if descendant:IsA("BasePart") then
                                descendant.LocalTransparencyModifier = 1
                            end
                        end
                        local throwables = LocalPlayer.PlayerScripts.Assets:FindFirstChild("Throwables")
                        local source = throwables and throwables:FindFirstChild(skinName)
                        if not source then
                            return
                        end
                        local visual = source:Clone()
                        visual.Name = "__h2oSmokeSkin"
                        local anchor = model:IsA("BasePart") and model or model:FindFirstChildWhichIsA("BasePart", true)
                        if not anchor then
                            anchor = Instance.new("Part")
                            anchor.Name = "__h2oSmokeAnchor"
                            anchor.Size = Vector3.new(0.1, 0.1, 0.1)
                            anchor.Transparency = 1
                            anchor.Anchored = true
                            anchor.CanCollide = false
                            anchor.CanTouch = false
                            anchor.CanQuery = false
                            anchor.CFrame = model:IsA("Model") and model:GetPivot() or CFrame.new()
                            anchor.Parent = model
                        end
                        visual.Parent = model
                        visual:PivotTo(anchor.CFrame)
                        for _, part in pairs(visual:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.Anchored = false
                                part.CanCollide = false
                                part.CanTouch = false
                                part.CanQuery = false
                                part.Massless = true
                                local weld = Instance.new("WeldConstraint")
                                weld.Part0 = anchor
                                weld.Part1 = part
                                weld.Parent = part
                            end
                        end
                    end)
                end)
                return cloud
            end
        end)
    end

        local function fireEquipRemote(weapon, ctype, cname)
                pcall(function()
                        local eq = remote("Remotes", "Data", "EquipCosmetic")
                        if eq then
                                eq:FireServer(weapon, ctype, cname, {})
                        end
                end)
        end

        local function setEquip(weapon, ctype, cname)
                if cname == "None" or cname == "" then
                        local slots = equips[weapon]
                        if slots then
                                slots[ctype] = nil
                                if not next(slots) then
                                        equips[weapon] = nil
                                end
                        end
                else
                        equips[weapon] = equips[weapon] or {}
                        equips[weapon][ctype] = cname
                end
                syncDataField()
        end

        local function cosmeticMatchesWeapon(entry, weapon)
                if not entry then
                        return false
                end
                local itemName = entry.ItemName or entry.WeaponName or entry.Weapon or entry.Item
                if itemName then
                        return tostring(itemName):lower() == tostring(weapon or ""):lower()
                end
                return entry.Type ~= "Skin"
        end

        local function pickRandomCosmetic(ctype, weapon)
                local pool = {}
                for _, name in ipairs(typeLists[ctype] or {}) do
                        local entry = catalogEntries[name]
                        if entry and cosmeticMatchesWeapon(entry, weapon) then
                                table.insert(pool, name)
                        end
                end
                if #pool == 0 then
                        return nil
                end
                return pool[math.random(1, #pool)]
        end

        local function refreshCosmeticDropdown()
                local list = { "None", "Random" }
                local ctype = Options.skinchanger_type.Value
                local weapon = Options.skinchanger_weapon.Value
                for _, name in ipairs(typeLists[ctype] or {}) do
                        local entry = catalogEntries[name]
                        if entry and cosmeticMatchesWeapon(entry, weapon) then
                                table.insert(list, name)
                        end
                end
                Options.skinchanger_cosmetic:SetValues(list)
                local weq = weapon and equips[weapon]
                local current = weq and weq[ctype]
                Options.skinchanger_cosmetic:SetValue(current or "None")
        end

        local function isValidViewModel(viewModel)
                return type(viewModel) == "table"
                        and viewModel._destroyed ~= true
                        and typeof(viewModel.Model) == "Instance"
                        and typeof(viewModel.ItemModel) == "Instance"
        end

        local function forceUpdate(weapon, ctype)
                task.spawn(function()
                        replicateData()
                        local selected = equips[weapon] and equips[weapon][ctype]
                        local fighter = getFighter()
                        if not fighter then
                                return
                        end
                        local item
                        for _, fighterItem in pairs(fighter.Items or {}) do
                                if fighterItem.Name == weapon then
                                        item = fighterItem
                                        break
                                end
                        end
                        if not item then
                                return
                        end
                        local wasEquipped = fighter.EquippedItem == item or item.IsEquipped == true
                        local function refreshHotbar()
                                pcall(function()
                                        local hotbar = fighter.FighterInterface and fighter.FighterInterface.Hotbar
                                        for _, hotbarSlot in pairs(hotbar and hotbar._hotbar_slots or {}) do
                                                if hotbarSlot.ClientItem == item then
                                                        if hotbarSlot._Setup then
                                                                hotbarSlot:_Setup()
                                                        end
                                                        if hotbarSlot.UpdateVisuals then
                                                                hotbarSlot:UpdateVisuals()
                                                        end
                                                        break
                                                end
                                        end
                                end)
                        end
                        pcall(function()
                                if item.Set then
                                        item:Set(ctype, selected and cloneCosmetic(selected))
                                end
                        end)
                        pcall(function()
                                if item.Data then
                                        item.Data[ctype] = selected and cloneCosmetic(selected)
                                end
                        end)
                        local oldViewModel = item.ViewModel
                        if oldViewModel and oldViewModel._serial and replicatedClass and clientViewModelClass then
                                pcall(function()
                                        local serial = table.clone(oldViewModel._serial)
                                        local dataKey = replicatedClass:ToEnum("Data")
                                        local data = table.clone(serial.Data or serial[dataKey] or {})
                                        serial[dataKey] = data
                                        serial.Data = nil
                                        local cosmetics = equips[weapon] or {}
                                        for _, cosmeticType in ipairs({ "Skin", "Wrap", "Charm" }) do
                                                local cosmeticName = cosmetics[cosmeticType]
                                                local cosmetic = cosmeticName and cloneCosmetic(cosmeticName)
                                                data[replicatedClass:ToEnum(cosmeticType)] = cosmetic
                                                data[cosmeticType] = nil
                                                if oldViewModel.Data then
                                                        oldViewModel.Data[cosmeticType] = cosmetic
                                                end
                                        end
                                        local skinEntry = cosmetics.Skin and catalogEntries[cosmetics.Skin]
                                        local resolvedName = skinEntry and (skinEntry.ViewModelName or skinEntry.Name) or weapon
                                        data[replicatedClass:ToEnum("Name")] = resolvedName
                                        data.Name = nil
                                        local className = resolveViewModelClassName(weapon, resolvedName)
                                        local targetClass = resolveViewModelClass(className) or clientViewModelClass
                                        local identity = getIdentity()
                                        constructingVirtual = targetClass ~= clientViewModelClass
                                        local ok, newViewModel = pcall(function()
                                                setIdentity(2)
                                                return targetClass.new(serial, item)
                                        end)
                                        constructingVirtual = false
                                        setIdentity(identity)
                                        if (not ok or not isValidViewModel(newViewModel)) and resolvedName ~= weapon then
                                                pcall(function()
                                                        if type(newViewModel) == "table" and newViewModel.Destroy then
                                                                newViewModel:Destroy()
                                                        end
                                                end)
                                                data[replicatedClass:ToEnum("Name")] = weapon
                                                data.Name = nil
                                                ok, newViewModel = pcall(function()
                                                        setIdentity(2)
                                                        return (clientViewModelBaseNew or clientViewModelClass.new)(serial, item)
                                                end)
                                                setIdentity(identity)
                                        end
                                        if ok and isValidViewModel(newViewModel) then
                                                pcall(function()
                                                        if wasEquipped and oldViewModel.Unequip then
                                                                oldViewModel:Unequip()
                                                        end
                                                end)
                                                item.ViewModel = newViewModel
                                                pcall(function()
                                                        if wasEquipped and newViewModel.Equip then
                                                                newViewModel:Equip(true)
                                                        end
                                                end)
                                                pcall(function()
                                                        if oldViewModel ~= newViewModel and oldViewModel.Destroy then
                                                                oldViewModel:Destroy()
                                                        end
                                                end)
                                                refreshHotbar()
                                        elseif type(newViewModel) == "table" and newViewModel.Destroy then
                                                pcall(newViewModel.Destroy, newViewModel)
                                        end
                                end)
                        end
                        for _, obj in ipairs({ item, item.ViewModel }) do
                                if obj then
                                        for _, method in ipairs({ "_UpdateWrap", "UpdateWrap", "_UpdateCharm", "UpdateCharm", "_UpdateCosmetics", "UpdateCosmetics", "_RefreshViewModel", "RefreshViewModel", "UpdateViewModel" }) do
                                                pcall(function()
                                                        if obj[method] then
                                                                obj[method](obj)
                                                        end
                                                end)
                                        end
                                end
                        end
                        task.wait(0.1)
                        replicateData()
                        refreshHotbar()
                end)
        end

        local function applySelection()
                if not Toggles.skinchanger_enabled.Value then
                        notify("enable the skin changer first", 4)
                        return
                end
                local cname = Options.skinchanger_cosmetic.Value
                local ctype = Options.skinchanger_type.Value
                if cname == "Random" and not Toggles.skinchanger_all.Value then
                        local weapon = Options.skinchanger_weapon.Value
                        cname = pickRandomCosmetic(ctype, weapon) or "None"
                        if cname == "None" then
                                notify("no cosmetics available for " .. tostring(weapon), 4)
                                return
                        end
                elseif cname ~= "Random" and cname ~= "None" and not catalogEntries[cname] then
                        notify("cosmetic not found in catalog", 4)
                        return
                end
                if Toggles.skinchanger_all.Value then
                        for _, weapon in ipairs(weaponList) do
                                local pick = cname == "Random" and pickRandomCosmetic(ctype, weapon) or cname
                                setEquip(weapon, ctype, pick)
                                if pick == "None" or isGenuinelyOwned(pick) then
                                        fireEquipRemote(weapon, ctype, pick)
                                end
                                forceUpdate(weapon, ctype)
                        end
                        replicateData()
                        notify(cname == "None" and ("cleared " .. ctype:lower() .. " on all weapons") or ("equipped " .. cname .. " on all weapons"), 4)
                else
                        local weapon = Options.skinchanger_weapon.Value
                        if not weapon then
                                return
                        end
                        setEquip(weapon, ctype, cname)
                        if cname == "None" or isGenuinelyOwned(cname) then
                                fireEquipRemote(weapon, ctype, cname)
                        end
                        replicateData()
                        forceUpdate(weapon, ctype)
                        notify(cname == "None" and ("cleared " .. ctype:lower() .. " on " .. weapon) or ("equipped " .. cname .. " on " .. weapon), 4)
                end
                refreshCosmeticDropdown()
        end

        SkinGroup:AddButton({
                Text = "equip",
                Func = applySelection,
        })
        SkinGroup:AddButton({
                Text = "unequip",
                Func = function()
                        Options.skinchanger_cosmetic:SetValue("None")
                        applySelection()
                end,
        })
        SkinGroup:AddButton({
                Text = "clear all",
                Func = function()
                        table.clear(equips)
                        syncDataField()
                        for _, weapon in ipairs(weaponList) do
                                for _, ctype in ipairs(cosmeticTypes) do
                                        fireEquipRemote(weapon, ctype, "None")
                                end
                        end
                        replicateData()
                        refreshCosmeticDropdown()
                        notify("all equips cleared", 4)
                end,
        })

        SkinGroup:AddInput("skinchanger_data", {
                Default = "",
                Text = "config data",
                Placeholder = "auto managed",
                Tooltip = "serialized equips - synced into your configs automatically",
        })

        local function enable()
                if not loadCatalog() then
                        notify("cosmetic library not found", 4)
                        return
                end
                registerVirtualSkins()
                ensureDataController()
                ensureClassHooks()
                ensureWorldHooks()
                refreshCosmeticDropdown()
                replicateData()
                local total = 0
                for _ in pairs(catalogEntries) do
                        total += 1
                end
                notify("skin changer ready - " .. total .. " cosmetics unlocked", 4)
        end

        Options.skinchanger_type:OnChanged(function()
                refreshCosmeticDropdown()
        end)
        Options.skinchanger_weapon:OnChanged(function()
                refreshCosmeticDropdown()
        end)
        Toggles.skinchanger_enabled:OnChanged(function()
                if Toggles.skinchanger_enabled.Value then
                        enable()
                else
                        replicateData()
                end
        end)
        Options.skinchanger_data:OnChanged(function()
                decodeEquips(Options.skinchanger_data.Value)
                if Toggles.skinchanger_enabled.Value then
                        refreshCosmeticDropdown()
                        replicateData()
                end
        end)

        task.spawn(function()
                for _ = 1, 20 do
                        if loadCatalog() then
                                registerVirtualSkins()
                                if Toggles.skinchanger_enabled.Value then
                                        refreshCosmeticDropdown()
                                end
                                return
                        end
                        task.wait(1)
                end
        end)
end

do
        local VmGroup = h2o.Tabs.visuals:AddLeftGroupbox("viewmodel", "hand")

        VmGroup:AddToggle("vm_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "viewmodel modifications",
        })
        VmGroup:AddDropdown("vm_disable", {
                Values = { "sway", "tilt", "bobbing", "muzzle flash", "idle animation", "jump animation", "slide animation", "equip animation", "shoot animation", "aiming animation", "sprint animation", "reload animation" },
                Default = {},
                Multi = true,
                Text = "disable",
                Searchable = true,
        })
        VmGroup:AddToggle("vm_fps", { Text = "override fps", Default = false })
        VmGroup:AddSlider("vm_fps_value", { Text = "fps", Min = 1, Max = 240, Default = 60, Rounding = 0 })
        VmGroup:AddSlider("vm_recoil", { Text = "recoil percent", Min = 0, Max = 100, Default = 100, Rounding = 0, Suffix = "%" })
        VmGroup:AddToggle("vm_chams", { Text = "chams", Default = false })
        VmGroup:AddLabel("cham color"):AddColorPicker("vm_chams_color", { Default = Color3.fromRGB(255, 255, 255), Title = "cham color" })
        VmGroup:AddSlider("vm_chams_fill", { Text = "fill transparency", Min = 0, Max = 100, Default = 2, Rounding = 0, Suffix = "%" })
        VmGroup:AddToggle("vm_offset", { Text = "offset", Default = false })
        VmGroup:AddSlider("vm_offset_x", { Text = "x", Min = -10, Max = 10, Default = 0, Rounding = 1 })
        VmGroup:AddSlider("vm_offset_y", { Text = "y", Min = -10, Max = 10, Default = 0, Rounding = 1 })
        VmGroup:AddSlider("vm_offset_z", { Text = "z", Min = -10, Max = 10, Default = 0, Rounding = 1 })

        local OverrideGroup = h2o.Tabs.visuals:AddLeftGroupbox("override", "paintbrush")

        OverrideGroup:AddToggle("vm_override", { Text = "viewmodel appearance", Default = false })
        OverrideGroup:AddLabel("color"):AddColorPicker("vm_override_color", { Default = Color3.fromRGB(255, 255, 255), Title = "viewmodel color" })
        OverrideGroup:AddDropdown("vm_override_material", {
                Values = materialList,
                Default = "ForceField",
                Text = "material",
                Searchable = true,
        })
        OverrideGroup:AddSlider("vm_override_transparency", { Text = "transparency", Min = 0, Max = 100, Default = 100, Rounding = 0, Suffix = "%" })
        OverrideGroup:AddToggle("vm_arm", { Text = "arm appearance", Default = false })
        OverrideGroup:AddLabel("arm color"):AddColorPicker("vm_arm_color", { Default = Color3.fromRGB(255, 255, 255), Title = "arm color" })
        OverrideGroup:AddDropdown("vm_arm_material", {
                Values = materialList,
                Default = "ForceField",
                Text = "arm material",
                Searchable = true,
        })
        OverrideGroup:AddSlider("vm_arm_transparency", { Text = "arm transparency", Min = 0, Max = 100, Default = 100, Rounding = 0, Suffix = "%" })
        OverrideGroup:AddToggle("vm_wireframe", { Text = "wireframe", Default = false })
        OverrideGroup:AddToggle("vm_notextures", { Text = "disable textures", Default = false })
        OverrideGroup:AddToggle("vm_noclothes", { Text = "disable clothes", Default = false })

        local ResizerGroup = h2o.Tabs.visuals:AddLeftGroupbox("resizer", "scaling")

        ResizerGroup:AddToggle("resizer_enabled", { Text = "enabled", Default = false, Tooltip = "scales your viewmodel" })
        ResizerGroup:AddSlider("resizer_size", { Text = "size", Min = 0.1, Max = 10, Default = 1, Rounding = 1 })

        local ItemGroup = h2o.Tabs.visuals:AddLeftGroupbox("item", "sword")

        ItemGroup:AddToggle("item_status", {
                Text = "override weapon status",
                Default = false,
                Tooltip = "changes the rarity status on all items client-side",
        })
        ItemGroup:AddDropdown("item_status_value", {
                Values = { "Prime", "Contraband" },
                Default = "Prime",
                Text = "status",
        })

        local TracerGroup = h2o.Tabs.visuals:AddLeftGroupbox("custom tracers", "route")

        TracerGroup:AddToggle("tracer_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "custom beam tracers on your shots",
        })
        TracerGroup:AddLabel("color"):AddColorPicker("tracer_color", {
                Default = Color3.fromRGB(97, 131, 255),
                Title = "tracer color",
        })

        local CrosshairGroup = h2o.Tabs.visuals:AddLeftGroupbox("crosshair", "crosshair")

        CrosshairGroup:AddToggle("crosshair_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "custom drawing crosshair",
        })
        CrosshairGroup:AddToggle("crosshair_outline", { Text = "outline", Default = false })
        CrosshairGroup:AddSlider("crosshair_rotation", { Text = "rotation", Min = 0, Max = 360, Default = 0, Rounding = 0, Suffix = " deg" })
        CrosshairGroup:AddSlider("crosshair_speed", { Text = "speed", Min = 0, Max = 5, Default = 0.2, Rounding = 1, Suffix = " rps" })
        CrosshairGroup:AddSlider("crosshair_bounce", { Text = "bounce", Min = 0, Max = 50, Default = 0, Rounding = 0, Suffix = " px" })
        CrosshairGroup:AddSlider("crosshair_bouncespeed", { Text = "bounce speed", Min = 0.1, Max = 5, Default = 1, Rounding = 1, Suffix = "x" })
        CrosshairGroup:AddSlider("crosshair_offset", { Text = "offset", Min = 0, Max = 50, Default = 5, Rounding = 0, Suffix = " px" })
        CrosshairGroup:AddSlider("crosshair_length", { Text = "length", Min = 1, Max = 80, Default = 20, Rounding = 0, Suffix = " px" })
        CrosshairGroup:AddSlider("crosshair_thickness", { Text = "thickness", Min = 1, Max = 10, Default = 2, Rounding = 0, Suffix = " px" })
        CrosshairGroup:AddDropdown("crosshair_position", {
                Values = { "-", "position on target", "position on barrel" },
                Default = "-",
                Text = "position",
        })
        CrosshairGroup:AddToggle("crosshair_hidegame", { Text = "disable game crosshair", Default = false })

        local AudioGroup = h2o.Tabs.visuals:AddRightGroupbox("audio", "volume-2")

        AudioGroup:AddToggle("shootsound_enabled", {
                Text = "change shoot sound",
                Default = false,
                Tooltip = "replaces your weapon shot sounds",
        })
        AudioGroup:AddDropdown("shootsound_name", {
                Values = { "disable", "neverlose", "gamesense", "skeet", "rust", "bell", "bubble", "minecraft", "osu", "tf2", "custom" },
                Default = "disable",
                Text = "sound",
        })
        AudioGroup:AddInput("shootsound_id", {
                Default = "4049646104",
                Numeric = true,
                Text = "custom id",
                Placeholder = "rbxassetid",
        })
        AudioGroup:AddSlider("shootsound_speed", { Text = "speed", Min = 0.1, Max = 5, Default = 1, Rounding = 1 })
        AudioGroup:AddSlider("shootsound_volume", { Text = "volume", Min = 0, Max = 5, Default = 0.3, Rounding = 1 })
        AudioGroup:AddSlider("shootsound_start", { Text = "start position", Min = 0, Max = 10, Default = 0, Rounding = 1 })
        AudioGroup:AddButton({
                Text = "preview shoot sound",
                Func = function()
                        playCustomSound(
                                normalizeSoundId(Options.shootsound_name.Value, Options.shootsound_id.Value),
                                Options.shootsound_volume.Value,
                                Options.shootsound_speed.Value,
                                Options.shootsound_start.Value
                        )
                end,
        })
        AudioGroup:AddDivider()
        AudioGroup:AddToggle("hitsound_enabled", {
                Text = "hit sounds",
                Default = false,
                Tooltip = "plays a sound when you hit someone",
        })
        AudioGroup:AddSlider("hitsound_volume", { Text = "hit volume", Min = 0, Max = 5, Default = 0.5, Rounding = 1 })
        AudioGroup:AddDropdown("hitsound_name", {
                Values = { "neverlose", "gamesense", "skeet", "rust", "bell", "bubble", "minecraft", "osu", "tf2", "custom" },
                Default = "neverlose",
                Text = "hit sound",
        })
        AudioGroup:AddInput("hitsound_id", {
                Default = "",
                Numeric = true,
                Text = "hit custom id",
                Placeholder = "rbxassetid",
        })
        AudioGroup:AddToggle("hitsound_remove", { Text = "remove hit sound", Default = false })
        AudioGroup:AddButton({
                Text = "preview hit sound",
                Func = function()
                        playCustomSound(
                                normalizeSoundId(Options.hitsound_name.Value, Options.hitsound_id.Value),
                                Options.hitsound_volume.Value,
                                1,
                                0
                        )
                end,
        })

        local HitFxGroup = h2o.Tabs.visuals:AddRightGroupbox("hit effects", "zap")

        HitFxGroup:AddToggle("hitfx_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "custom effects when you deal damage",
        })
        HitFxGroup:AddToggle("hitfx_weld", { Text = "weld to player", Default = false })
        HitFxGroup:AddDropdown("hitfx_selected", {
                Values = { "Aura", "Blades", "Confetti", "Cyclone", "Dots", "Emission", "Electricity", "Filled Circle", "Lighting", "Portal", "Petals", "Plasma", "Ring", "Ripple", "Spiral", "Stars", "Sun Rays", "Tornado", "Thunder", "Wind", "Zap", "bubble", "clone", "explosion", "fortnite damage", "phantom forces", "slashes" },
                Default = {},
                Multi = true,
                Text = "effects",
                Searchable = true,
        })
        HitFxGroup:AddDropdown("hitfx_material", {
                Values = materialList,
                Default = "ForceField",
                Text = "preferred material",
                Searchable = true,
        })
        HitFxGroup:AddToggle("hitfx_disablemarker", { Text = "disable hit marker", Default = false })
        HitFxGroup:AddToggle("hitfx_disablenumbers", { Text = "disable damage numbers", Default = false })

        local HudGroup = h2o.Tabs.visuals:AddRightGroupbox("target hud", "layout-panel-top")

        HudGroup:AddToggle("targethud_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "shows a hud for your closest target",
        })

        local IndicatorGroup = h2o.Tabs.visuals:AddRightGroupbox("indicators", "list")

        IndicatorGroup:AddToggle("indicator_manipulated", { Text = "manipulated", Default = false })
        IndicatorGroup:AddToggle("indicator_ammo", { Text = "ammo", Default = false })
        IndicatorGroup:AddSlider("indicator_offsetx", { Text = "offset x", Min = -200, Max = 200, Default = 0, Rounding = 0, Suffix = " px" })
        IndicatorGroup:AddSlider("indicator_offsety", { Text = "offset y", Min = -200, Max = 200, Default = 25, Rounding = 0, Suffix = " px" })
        IndicatorGroup:AddDropdown("indicator_style", {
                Values = { "lower", "upper" },
                Default = "lower",
                Text = "text style",
        })

        local TargetGroup = h2o.Tabs.visuals:AddRightGroupbox("target visuals", "focus")

        TargetGroup:AddToggle("targetvis_tracer", { Text = "tracer", Default = false })
        TargetGroup:AddLabel("color"):AddColorPicker("targetvis_tracer_color", { Default = Color3.fromRGB(255, 255, 255), Title = "tracer color" })
        TargetGroup:AddToggle("targetvis_highlight", { Text = "highlight", Default = false })
        TargetGroup:AddLabel("highlight color"):AddColorPicker("targetvis_highlight_color", { Default = Color3.fromRGB(255, 255, 255), Title = "highlight color" })
        TargetGroup:AddDropdown("targetvis_culling", {
                Values = { "AlwaysOnTop", "Ocluded" },
                Default = "AlwaysOnTop",
                Text = "culling mode",
        })

        local XrayGroup = h2o.Tabs.visuals:AddRightGroupbox("xray", "scan")

        XrayGroup:AddToggle("xray_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "makes world geometry transparent",
        })
        XrayGroup:AddSlider("xray_transparency", { Text = "transparency", Min = 0, Max = 1, Default = 0.5, Rounding = 1 })

        local vmPivots = {}
        local vmWireframeAdornments = {}
        local vmHooksInstalled = false

        Toggles.vm_offset:OnChanged(function()
                if not Toggles.vm_offset.Value then
                        for model, pivot in pairs(vmPivots) do
                                pcall(function()
                                        model:PivotTo(pivot)
                                end)
                        end
                        table.clear(vmPivots)
                end
        end)

        local function getLocalViewmodels()
                local folder = workspace:FindFirstChild("ViewModels")
                local result = {}
                if folder then
                        for _, model in ipairs(folder:GetChildren()) do
                                if model:IsA("Model") and model.Name:sub(1, #LocalPlayer.Name + 3) == (LocalPlayer.Name .. " - ") then
                                        table.insert(result, model)
                                end
                        end
                end
                return result
        end

        local function isArmPart(part)
                return part.Name:lower():find("arm") ~= nil
        end

        local function shouldBlockAnimation(key)
                if not Toggles.vm_enabled.Value then
                        return false
                end
                local selected = Options.vm_disable.Value or {}
                local k = tostring(key or ""):lower()
                local map = {
                        ["idle animation"] = "idle",
                        ["jump animation"] = "jump",
                        ["slide animation"] = "slide",
                        ["equip animation"] = "equip",
                        ["shoot animation"] = "shoot",
                        ["aiming animation"] = "aim",
                        ["sprint animation"] = "sprint",
                        ["reload animation"] = "reload",
                }
                for option, pattern in pairs(map) do
                        if selected[option] and (k:find(pattern, 1, true) or (option == "shoot animation" and (k:find("fire", 1, true) or k:find("attack", 1, true)))) then
                                return true
                        end
                end
                return false
        end

        local function ensureViewmodelHooks()
                if vmHooksInstalled then
                        return
                end
                task.spawn(function()
                        while not vmHooksInstalled and not h2o.Unloaded do
                                pcall(function()
                                        local clientItem = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem)
                                        if type(clientItem) == "table" then
                                                if type(clientItem.PlayAnimation) == "function" and not clientItem.__h2oPlayAnim then
                                                        local orig = clientItem.PlayAnimation
                                                        clientItem.__h2oPlayAnim = orig
                                                        clientItem.PlayAnimation = function(self, key, ...)
                                                                if shouldBlockAnimation(key) then
                                                                        return
                                                                end
                                                                return orig(self, key, ...)
                                                        end
                                                end
                                                if type(clientItem.MuzzleFlash) == "function" and not clientItem.__h2oMuzzle then
                                                        local orig = clientItem.MuzzleFlash
                                                        clientItem.__h2oMuzzle = orig
                                                        clientItem.MuzzleFlash = function(self, ...)
                                                                if Toggles.vm_enabled.Value and (Options.vm_disable.Value or {})["muzzle flash"] then
                                                                        return
                                                                end
                                                                return orig(self, ...)
                                                        end
                                                end
                                                if type(clientItem.Update) == "function" and not clientItem.__h2oUpdate then
                                                        local orig = clientItem.Update
                                                        clientItem.__h2oUpdate = orig
                                                        clientItem.Update = function(self, ...)
                                                                local results = { orig(self, ...) }
                                                                pcall(function()
                                                                        if Toggles.vm_enabled.Value and Options.vm_recoil.Value < 100 then
                                                                                local rv = self.CurrentRecoilValue
                                                                                if rv ~= nil then
                                                                                        self.CurrentRecoilValue = rv * (Options.vm_recoil.Value / 100)
                                                                                end
                                                                        end
                                                                end)
                                                                return unpack(results)
                                                        end
                                                end
                                                vmHooksInstalled = true
                                        end
                                end)
                                task.wait(1)
                        end
                end)
        end

        local function clearWireframes()
                for _, adorn in pairs(vmWireframeAdornments) do
                        pcall(function()
                                adorn:Destroy()
                        end)
                end
                table.clear(vmWireframeAdornments)
        end

        local function addWireframe(part)
                if vmWireframeAdornments[part] or not part:IsA("BasePart") then
                        return
                end
                pcall(function()
                        local adorn = Instance.new("WireframeHandleAdornment")
                        local s = part.Size / 2
                        local c = {
                                Vector3.new(-s.X, -s.Y, -s.Z),
                                Vector3.new(s.X, -s.Y, -s.Z),
                                Vector3.new(s.X, s.Y, -s.Z),
                                Vector3.new(-s.X, s.Y, -s.Z),
                                Vector3.new(-s.X, -s.Y, s.Z),
                                Vector3.new(s.X, -s.Y, s.Z),
                                Vector3.new(s.X, s.Y, s.Z),
                                Vector3.new(-s.X, s.Y, s.Z),
                        }
                        local edges = { { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
                        adorn.Adornee = part
                        adorn.Color3 = Color3.fromRGB(255, 255, 255)
                        adorn.Transparency = 0.2
                        adorn.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                        for _, e in ipairs(edges) do
                                adorn:AddLine(c[e[1]], c[e[2]])
                        end
                        vmWireframeAdornments[part] = adorn
                end)
        end

        local function applyViewmodelVisuals()
                pcall(function()
                        local models = getLocalViewmodels()
                        for _, model in ipairs(models) do
                                if Toggles.vm_enabled.Value and Toggles.vm_offset.Value then
                                        if not vmPivots[model] then
                                                vmPivots[model] = model:GetPivot()
                                        end
                                        model:PivotTo(vmPivots[model] * CFrame.new(Options.vm_offset_x.Value, Options.vm_offset_y.Value, Options.vm_offset_z.Value))
                                end
                                for _, part in ipairs(model:GetDescendants()) do
                                        if part:IsA("BasePart") then
                                                local arm = isArmPart(part)
                                                if Toggles.vm_enabled.Value and Toggles.vm_chams.Value then
                                                        part.Material = Enum.Material.ForceField
                                                        part.Color = Options.vm_chams_color.Value
                                                        part.Transparency = Options.vm_chams_fill.Value / 100
                                                end
                                                if Toggles.vm_override.Value and not arm then
                                                        part.Color = Options.vm_override_color.Value
                                                        part.Material = Enum.Material[Options.vm_override_material.Value]
                                                        part.Transparency = Options.vm_override_transparency.Value / 100
                                                end
                                                if Toggles.vm_arm.Value and arm then
                                                        part.Color = Options.vm_arm_color.Value
                                                        part.Material = Enum.Material[Options.vm_arm_material.Value]
                                                        part.Transparency = Options.vm_arm_transparency.Value / 100
                                                end
                                                if Toggles.vm_notextures.Value then
                                                        if part:IsA("MeshPart") then
                                                                part.TextureID = ""
                                                        end
                                                        local mesh = part:FindFirstChildOfClass("SpecialMesh")
                                                        if mesh then
                                                                mesh.TextureId = ""
                                                        end
                                                end
                                                if Toggles.vm_wireframe.Value and not arm then
                                                        addWireframe(part)
                                                end
                                        elseif Toggles.vm_notextures.Value and (part:IsA("Texture") or part:IsA("Decal")) then
                                                part.Transparency = 1
                                        elseif Toggles.vm_noclothes.Value and (part:IsA("Shirt") or part:IsA("Pants") or part:IsA("ShirtGraphic")) then
                                                pcall(function()
                                                        part:Destroy()
                                                end)
                                        elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") then
                                                if Toggles.vm_enabled.Value and (Options.vm_disable.Value or {})["muzzle flash"] then
                                                        part.Enabled = false
                                                end
                                        end
                                end
                        end
                end)
        end

        local function restoreViewmodel()
                clearWireframes()
                table.clear(vmPivots)
        end

        task.spawn(function()
                while not h2o.Unloaded do
                        task.wait(0.12)
                        pcall(function()
                                if Toggles.vm_fps.Value then
                                        if setfpscap then
                                                setfpscap(Options.vm_fps_value.Value)
                                        end
                                end
                                if Toggles.vm_enabled.Value then
                                        ensureViewmodelHooks()
                                        local camera = workspace.CurrentCamera
                                        if camera then
                                                local selected = Options.vm_disable.Value or {}
                                                if selected["sway"] then
                                                        pcall(function()
                                                                camera._sway_spring.Target = Vector3.zero
                                                        end)
                                                end
                                                if selected["tilt"] then
                                                        pcall(function()
                                                                camera._tilt_spring.Target = Vector3.zero
                                                        end)
                                                end
                                                if selected["bobbing"] then
                                                        pcall(function()
                                                                camera._bobbing_speed_spring.Target = Vector3.zero
                                                                camera._bobbing_value_spring.Target = Vector3.zero
                                                        end)
                                                end
                                        end
                                end
                                applyViewmodelVisuals()
                                if not Toggles.vm_wireframe.Value then
                                        clearWireframes()
                                end
                        end)
                end
        end)

        maid(restoreViewmodel)

        local resizerOriginals = {}

        local function scaleViewmodels()
                pcall(function()
                        local mult = Options.resizer_size.Value
                        for _, model in ipairs(getLocalViewmodels()) do
                                if not resizerOriginals[model] then
                                        local sizes, cf = {}, {}
                                        for _, part in ipairs(model:GetDescendants()) do
                                                if part:IsA("BasePart") then
                                                        sizes[part] = part.Size
                                                        cf[part] = part.CFrame
                                                end
                                        end
                                        resizerOriginals[model] = { sizes = sizes, cf = cf, pivot = model:GetPivot() }
                                end
                                local data = resizerOriginals[model]
                                for part, origSize in pairs(data.sizes) do
                                        if part.Parent then
                                                part.Size = origSize * mult
                                                local rel = data.pivot:ToObjectSpace(data.cf[part])
                                                part.CFrame = data.pivot * CFrame.new(rel.Position * mult) * rel.Rotation
                                        end
                                end
                        end
                end)
        end

        local function restoreResizer()
                for model, data in pairs(resizerOriginals) do
                        pcall(function()
                                for part, size in pairs(data.sizes) do
                                        if part.Parent then
                                                part.Size = size
                                                part.CFrame = data.cf[part]
                                        end
                                end
                        end)
                end
                table.clear(resizerOriginals)
        end

        Toggles.resizer_enabled:OnChanged(function()
                if not Toggles.resizer_enabled.Value then
                        restoreResizer()
                end
        end)
        Options.resizer_size:OnChanged(function()
                if Toggles.resizer_enabled.Value then
                        scaleViewmodels()
                end
        end)
        maid(restoreResizer)

        local statusOriginals = {}

        task.spawn(function()
                while not h2o.Unloaded do
                        task.wait(0.75)
                        pcall(function()
                                if Toggles.item_status.Value then
                                        local itemLibrary = require(game:GetService("ReplicatedStorage").Modules.ItemLibrary)
                                        if type(itemLibrary) == "table" and type(itemLibrary.Items) == "table" then
                                                for name, info in pairs(itemLibrary.Items) do
                                                        if type(info) == "table" then
                                                                if statusOriginals[name] == nil then
                                                                        statusOriginals[name] = info.Status
                                                                end
                                                                info.Status = Options.item_status_value.Value
                                                        end
                                                end
                                        end
                                end
                        end)
                end
        end)

        local snapshotSounds = {}
        local shootHookInstalled = false

        local function ensureShootSoundHook()
                if shootHookInstalled then
                        return
                end
                task.spawn(function()
                        while not shootHookInstalled and not h2o.Unloaded do
                                pcall(function()
                                        local gun = require(LocalPlayer.PlayerScripts.Modules.ItemTypes.Gun)
                                        if type(gun) == "table" and type(gun._ShootEffect) == "function" and not gun.__h2oShootHook then
                                                local original = gun._ShootEffect
                                                gun.__h2oShootHook = original
                                                gun._ShootEffect = function(self, ...)
                                                        if Toggles.shootsound_enabled.Value then
                                                                local roots = { workspace:FindFirstChild("ViewModels"), workspace.CurrentCamera, SoundService }
                                                                for _, root in ipairs(roots) do
                                                                        if root then
                                                                                for _, s in ipairs(root:GetDescendants()) do
                                                                                        if s:IsA("Sound") and not s:GetAttribute("h2oCustomSound") then
                                                                                                snapshotSounds[s] = s.Volume
                                                                                        end
                                                                                end
                                                                        end
                                                                end
                                                                playCustomSound(
                                                                        normalizeSoundId(Options.shootsound_name.Value, Options.shootsound_id.Value),
                                                                        Options.shootsound_volume.Value,
                                                                        Options.shootsound_speed.Value,
                                                                        Options.shootsound_start.Value
                                                                )
                                                        end
                                                        local results = { original(self, ...) }
                                                        if Toggles.shootsound_enabled.Value then
                                                                for _, root in ipairs({ workspace:FindFirstChild("ViewModels"), workspace.CurrentCamera, SoundService }) do
                                                                        if root then
                                                                                for _, s in ipairs(root:GetDescendants()) do
                                                                                        if s:IsA("Sound") and not s:GetAttribute("h2oCustomSound") and s.IsPlaying then
                                                                                                local vol = snapshotSounds[s] or s.Volume
                                                                                                s.Volume = 0
                                                                                                task.delay(0.4, function()
                                                                                                        s.Volume = vol
                                                                                                end)
                                                                                        end
                                                                                end
                                                                        end
                                                                end
                                                                table.clear(snapshotSounds)
                                                        end
                                                        return unpack(results)
                                                end
                                                shootHookInstalled = true
                                        end
                                end)
                                task.wait(1)
                        end
                end)
        end

        local function getMuzzleWorld()
                local folder = workspace:FindFirstChild("ViewModels")
                if folder then
                        for _, model in ipairs(folder:GetChildren()) do
                                if model:IsA("Model") and model.Name:sub(1, #LocalPlayer.Name + 3) == (LocalPlayer.Name .. " - ") then
                                        local part = model:FindFirstChild("Muzzle")
                                                or model:FindFirstChild("Barrel")
                                                or model:FindFirstChild("Handle")
                                        if part then
                                                if part:IsA("BasePart") then
                                                        return part.Position
                                                elseif part:IsA("Attachment") then
                                                        return part.WorldPosition
                                                end
                                        end
                                        local ok, pos = pcall(function()
                                                return model:GetPivot().Position
                                        end)
                                        if ok then
                                                return pos
                                        end
                                end
                        end
                end
                local root = getRoot()
                return root and root.Position
        end

        local function drawTracer(startPos, endPos)
                if not startPos or not endPos then
                        return
                end
                if (endPos - startPos).Magnitude < 0.5 then
                        return
                end
                local color = Options.tracer_color.Value
                local p1 = Instance.new("Part")
                p1.Anchored = true
                p1.CanCollide = false
                p1.Transparency = 1
                p1.Size = Vector3.new(0.1, 0.1, 0.1)
                p1.CFrame = CFrame.new(startPos)
                p1.Parent = workspace
                local p2 = p1:Clone()
                p2.CFrame = CFrame.new(endPos)
                p2.Parent = p1.Parent
                local beam = Instance.new("Beam")
                beam.Attachment0 = Instance.new("Attachment", p1)
                beam.Attachment1 = Instance.new("Attachment", p2)
                beam.Width0 = 0.35
                beam.Width1 = 0.08
                beam.LightEmission = 1
                beam.Brightness = 8
                beam.FaceCamera = true
                beam.Color = ColorSequence.new(color)
                beam.Parent = p1
                Debris:AddItem(p1, 1)
                Debris:AddItem(p2, 1)
        end

        local tracerHookInstalled = false

        local function ensureTracerHook()
                if tracerHookInstalled then
                        return
                end
                task.spawn(function()
                        while not tracerHookInstalled and not h2o.Unloaded do
                                pcall(function()
                                        local gun = require(LocalPlayer.PlayerScripts.Modules.ItemTypes.Gun)
                                        if type(gun) == "table" and type(gun._Tracers) == "function" and not gun.__h2oTracerHook then
                                                local original = gun._Tracers
                                                gun.__h2oTracerHook = original
                                                gun._Tracers = function(self, data, ...)
                                                        pcall(original, self, data, ...)
                                                        if Toggles.tracer_enabled.Value and type(data) == "table" and data.IsLocal then
                                                                local drewRays = false
                                                                local rays = data.RaycastResults or data.Rays or data.Raycasts
                                                                if type(rays) == "table" then
                                                                        for _, ray in ipairs(rays) do
                                                                                if type(ray) == "table" then
                                                                                        local sp = ray.StartPosition or ray.Position
                                                                                        local ep = ray.Position or ray.EndPosition
                                                                                        if sp and ep then
                                                                                                drewRays = true
                                                                                                drawTracer(sp, ep)
                                                                                        end
                                                                                end
                                                                        end
                                                                end
                                                                if not drewRays then
                                                                        local endPos = data.Position or data.EndPosition or data.HitPosition
                                                                        if endPos then
                                                                                drawTracer(getMuzzleWorld(), endPos)
                                                                        end
                                                                end
                                                        end
                                                end
                                                tracerHookInstalled = true
                                        end
                                end)
                                task.wait(1)
                        end
                end)
        end

        local hitmarkerHookReady = false

        local function ensureHitmarkerHook()
                if hitmarkerHookReady then
                        return
                end
                pcall(function()
                        local itemInterface = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ItemInterface)
                        if type(itemInterface) == "table" and type(itemInterface.DamageEffect) == "function" and not itemInterface.__h2oDamageEffectHook then
                                local original = itemInterface.DamageEffect
                                itemInterface.__h2oDamageEffectHook = original
                                itemInterface.DamageEffect = function(self, ...)
                                        if Toggles.hitfx_enabled.Value and Toggles.hitfx_disablemarker.Value then
                                                return
                                        end
                                        return original(self, ...)
                                end
                                hitmarkerHookReady = true
                        end
                end)
        end

        local hitsoundHookReady = false

        local function ensureHitSoundHook()
                if hitsoundHookReady then
                        return
                end
                pcall(function()
                        local clientViewModel = require(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientViewModel)
                        if type(clientViewModel) == "table" and type(clientViewModel.PlayHitmarkerSound) == "function" and not clientViewModel.__h2oHitmarkerHook then
                                local original = clientViewModel.PlayHitmarkerSound
                                clientViewModel.__h2oHitmarkerHook = original
                                clientViewModel.PlayHitmarkerSound = function(self, ...)
                                        if Toggles.hitsound_enabled.Value then
                                                playCustomSound(
                                                        normalizeSoundId(Options.hitsound_name.Value, Options.hitsound_id.Value),
                                                        Options.hitsound_volume.Value,
                                                        1,
                                                        0
                                                )
                                                if Toggles.hitsound_remove.Value then
                                                        return
                                                end
                                        end
                                        return original(self, ...)
                                end
                                hitsoundHookReady = true
                        end
                end)
        end

        Toggles.hitsound_enabled:OnChanged(function()
                if Toggles.hitsound_enabled.Value then
                        ensureHitSoundHook()
                end
        end)
        Toggles.shootsound_enabled:OnChanged(function()
                if Toggles.shootsound_enabled.Value then
                        ensureShootSoundHook()
                end
        end)

        local function resolveHitPosition(source)
                if typeof(source) == "Instance" then
                        if source:IsA("BasePart") then
                                return source, source.Position
                        end
                        if source:IsA("Attachment") then
                                return source.Parent, source.WorldPosition
                        end
                        local part = source:FindFirstChildWhichIsA("BasePart", true)
                        return part, part and part.Position
                elseif typeof(source) == "Vector3" then
                        return nil, source
                end
                return nil, nil
        end

        local function createDamageText(position, damage)
                pcall(function()
                        local anchor = Instance.new("Part")
                        anchor.Anchored = true
                        anchor.CanCollide = false
                        anchor.Transparency = 1
                        anchor.Size = Vector3.new(0.2, 0.2, 0.2)
                        anchor.Position = position
                        anchor.Parent = workspace
                        local billboard = Instance.new("BillboardGui")
                        billboard.Size = UDim2.new(0, 100, 0, 32)
                        billboard.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 1.5, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Adornee = anchor
                        billboard.Parent = anchor
                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.Font = Enum.Font.SourceSansBold
                        label.TextSize = 24
                        label.Text = "-" .. tostring(math.floor(damage + 0.5))
                        label.TextColor3 = Color3.fromRGB(255, 80, 80)
                        label.TextStrokeTransparency = 0.2
                        label.Parent = billboard
                        TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Linear), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
                        TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Linear), { Position = position + Vector3.new(0, 2.2, 0) }):Play()
                        Debris:AddItem(anchor, 1)
                end)
        end

        local function createHitEffect(source, damage)
                if not Toggles.hitfx_enabled.Value then
                        return false
                end
                local part, position = resolveHitPosition(source)
                if not position then
                        local target = getClosestTargetPart()
                        if target then
                                position = target.Position
                                part = target
                        else
                                position = getMuzzleWorld()
                        end
                end
                if not position then
                        return false
                end
                pcall(function()
                        local selected = Options.hitfx_selected.Value or {}
                        local material = Enum.Material[Options.hitfx_material.Value] or Enum.Material.ForceField

                        local root = Instance.new("Part")
                        root.Name = "h2oHitEffect"
                        root.Size = Vector3.new(0.25, 0.25, 0.25)
                        root.Transparency = 1
                        root.Anchored = not (Toggles.hitfx_weld.Value and part)
                        root.CFrame = CFrame.new(position)
                        root.Parent = workspace
                        if Toggles.hitfx_weld.Value and part then
                                local weld = Instance.new("WeldConstraint")
                                weld.Part0 = root
                                weld.Part1 = part
                                weld.Parent = root
                        end

                        local emitter = Instance.new("ParticleEmitter")
                        emitter.Texture = "rbxassetid://243660364"
                        emitter.LightEmission = 1
                        emitter.Lifetime = NumberRange.new(0.35, 0.7)
                        emitter.Speed = NumberRange.new(6, 16)
                        emitter.SpreadAngle = Vector2.new(360, 360)
                        emitter.Size = NumberSequence.new(0.25, 0)
                        emitter.Color = ColorSequence.new(Options.tracer_color.Value)
                        emitter.Parent = root
                        emitter:Emit(selected["explosion"] and 36 or 18)

                        if not next(selected) or selected["Ring"] or selected["Filled Circle"] or selected["Ripple"] then
                                local ring = Instance.new("Part")
                                ring.Name = "h2oHitRing"
                                ring.Shape = Enum.PartType.Ball
                                ring.Material = material
                                ring.Color = Options.tracer_color.Value
                                ring.Anchored = true
                                ring.CanCollide = false
                                ring.Size = Vector3.new(0.25, 0.25, 0.25)
                                ring.CFrame = CFrame.new(position)
                                ring.Transparency = selected["Filled Circle"] and 0.35 or 0.65
                                ring.Parent = workspace
                                TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                        Size = Vector3.new(4.25, 4.25, 4.25),
                                        Transparency = 1,
                                }):Play()
                                Debris:AddItem(ring, 0.55)
                        end

                        if selected["Blades"] or selected["slashes"] or selected["Zap"] then
                                for _ = 1, 4 do
                                        local slash = Instance.new("Part")
                                        slash.Name = "h2oSlash"
                                        slash.Material = Enum.Material.Neon
                                        slash.Color = Options.tracer_color.Value
                                        slash.Anchored = true
                                        slash.CanCollide = false
                                        slash.Size = Vector3.new(0.06, 0.06, 2.5)
                                        slash.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
                                        slash.Parent = workspace
                                        Debris:AddItem(slash, 0.25)
                                end
                        end

                        if selected["fortnite damage"] or selected["phantom forces"] then
                                createDamageText(position, damage)
                        end

                        Debris:AddItem(root, 2)
                end)
                return false
        end

        table.insert(h2o.DamageListeners, function(source, damage)
                local blocked = false
                pcall(function()
                        if Toggles.hitfx_enabled.Value and Toggles.hitfx_disablenumbers.Value then
                                blocked = true
                        end
                        createHitEffect(source, damage)
                end)
                return blocked
        end)

        Toggles.hitfx_enabled:OnChanged(function()
                if Toggles.hitfx_enabled.Value then
                        ensureDamageHook()
                        ensureHitmarkerHook()
                end
        end)
        Toggles.hitfx_disablemarker:OnChanged(function()
                if Toggles.hitfx_disablemarker.Value then
                        ensureHitmarkerHook()
                end
        end)
        ensureDamageHook()
        ensureHitmarkerHook()
        ensureShootSoundHook()
        ensureTracerHook()
        ensureHitSoundHook()

        local hudGui, hudFrame, hudName, hudBarFill

        local function buildHud()
                if hudGui then
                        return
                end
                hudGui = Instance.new("ScreenGui")
                hudGui.Name = "h2oTargetHud"
                hudGui.ResetOnSpawn = false
                hudGui.DisplayOrder = 999
                hudFrame = Instance.new("Frame")
                hudFrame.Size = UDim2.new(0, 220, 0, 64)
                hudFrame.Position = UDim2.new(0.5, 130, 0.5, -140)
                hudFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
                hudFrame.BackgroundTransparency = 0.2
                hudFrame.BorderSizePixel = 0
                hudFrame.Visible = false
                hudFrame.Parent = hudGui
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 8)
                corner.Parent = hudFrame
                hudName = Instance.new("TextLabel")
                hudName.Size = UDim2.new(1, -16, 0, 26)
                hudName.Position = UDim2.new(0, 8, 0, 6)
                hudName.BackgroundTransparency = 1
                hudName.Font = Enum.Font.GothamBold
                hudName.TextSize = 16
                hudName.TextColor3 = Color3.fromRGB(240, 240, 255)
                hudName.TextXAlignment = Enum.TextXAlignment.Left
                hudName.Text = "target"
                hudName.Parent = hudFrame
                local barBackground = Instance.new("Frame")
                barBackground.Size = UDim2.new(1, -16, 0, 12)
                barBackground.Position = UDim2.new(0, 8, 0, 40)
                barBackground.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
                barBackground.BorderSizePixel = 0
                barBackground.Parent = hudFrame
                local barCorner = Instance.new("UICorner")
                barCorner.CornerRadius = UDim.new(0, 4)
                barCorner.Parent = barBackground
                hudBarFill = Instance.new("Frame")
                hudBarFill.Size = UDim2.new(1, 0, 1, 0)
                hudBarFill.BackgroundColor3 = Color3.fromRGB(90, 220, 140)
                hudBarFill.BorderSizePixel = 0
                hudBarFill.Parent = barBackground
                local fillCorner = Instance.new("UICorner")
                fillCorner.CornerRadius = UDim.new(0, 4)
                fillCorner.Parent = hudBarFill
                hudGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        task.spawn(function()
                while not h2o.Unloaded do
                        task.wait(0.1)
                        pcall(function()
                                if Toggles.targethud_enabled.Value then
                                        buildHud()
                                        local target = getClosestTargetPart()
                                        if target then
                                                local humanoid = target.Parent and target.Parent:FindFirstChildOfClass("Humanoid")
                                                if humanoid then
                                                        hudGui.Enabled = true
                                                        hudFrame.Visible = true
                                                        hudName.Text = target.Parent.Name
                                                        local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                                                        hudBarFill.Size = UDim2.new(ratio, 0, 1, 0)
                                                        hudBarFill.BackgroundColor3 = Color3.fromRGB(255 - ratio * 165, 90 + ratio * 130, 140 - ratio * 40)
                                                        return
                                                end
                                        end
                                end
                                if hudFrame then
                                        hudFrame.Visible = false
                                end
                        end)
                end
        end)
        maid(function()
                if hudGui then
                        hudGui:Destroy()
                end
        end)

        local crosshairLines, crosshairOutlines = {}, {}
        local targetTracerLine, targetHighlightSquare = nil, nil

        local function getDrawings(pool, index)
                local line = pool[index]
                if not line then
                        line = Drawing.new("Line")
                        line.Visible = false
                        pool[index] = line
                end
                return line
        end

        local function hideDrawings(pool)
                for _, drawing in pairs(pool) do
                        pcall(function()
                                drawing.Visible = false
                        end)
                end
        end

        local function ensureTargetDrawings()
                if not targetTracerLine then
                        targetTracerLine = Drawing.new("Line")
                        targetTracerLine.Thickness = 2
                        targetTracerLine.Visible = false
                end
                if not targetHighlightSquare then
                        targetHighlightSquare = Drawing.new("Square")
                        targetHighlightSquare.Thickness = 2
                        targetHighlightSquare.Filled = false
                        targetHighlightSquare.Visible = false
                end
        end

        local lastHideScan = 0

        RunService.RenderStepped:Connect(function()
                if h2o.Unloaded then
                        return
                end
                pcall(function()
                        if Toggles.crosshair_enabled.Value then
                                local camera = workspace.CurrentCamera
                                if not camera then
                                        return
                                end
                                local center
                                local mode = Options.crosshair_position.Value
                                if mode == "position on target" then
                                        local part = getClosestTargetPart()
                                        if part then
                                                local pos = camera:WorldToViewportPoint(part.Position)
                                                center = Vector2.new(pos.X, pos.Y)
                                        end
                                elseif mode == "position on barrel" then
                                        local muzzle = getMuzzleWorld()
                                        if muzzle then
                                                local pos = camera:WorldToViewportPoint(muzzle)
                                                center = Vector2.new(pos.X, pos.Y)
                                        end
                                end
                                if not center then
                                        local mouse = UserInputService:GetMouseLocation()
                                        center = Vector2.new(mouse.X, mouse.Y)
                                end
                                local rot = Options.crosshair_rotation.Value + tick() * 360 * Options.crosshair_speed.Value
                                local bounce = math.sin(tick() * 8 * Options.crosshair_bouncespeed.Value) * Options.crosshair_bounce.Value
                                local gap = Options.crosshair_offset.Value + bounce
                                local length = Options.crosshair_length.Value
                                local thickness = Options.crosshair_thickness.Value
                                local color = Color3.fromRGB(255, 255, 255)
                                for i = 0, 3 do
                                        local dir = math.rad(rot + i * 90)
                                        local dirVec = Vector2.new(math.cos(dir), math.sin(dir))
                                        local from = center + dirVec * gap
                                        local to = center + dirVec * (gap + length)
                                        local line = getDrawings(crosshairLines, i)
                                        line.From = from
                                        line.To = to
                                        line.Color = color
                                        line.Thickness = thickness
                                        line.Visible = true
                                        if Toggles.crosshair_outline.Value then
                                                local outline = getDrawings(crosshairOutlines, i)
                                                outline.From = from
                                                outline.To = to
                                                outline.Color = Color3.fromRGB(0, 0, 0)
                                                outline.Thickness = thickness + 2
                                                outline.Visible = true
                                        end
                                end
                                if not Toggles.crosshair_outline.Value then
                                        hideDrawings(crosshairOutlines)
                                end
                        else
                                hideDrawings(crosshairLines)
                                hideDrawings(crosshairOutlines)
                        end

                        if Toggles.crosshair_hidegame.Value and os.clock() - lastHideScan > 1 then
                                lastHideScan = os.clock()
                                pcall(function()
                                        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                                        if gui then
                                                for _, obj in ipairs(gui:GetDescendants()) do
                                                        if obj.Name:lower():find("crosshair") then
                                                                if obj:IsA("ScreenGui") then
                                                                        obj.Enabled = false
                                                                elseif obj:IsA("GuiObject") then
                                                                        obj.Visible = false
                                                                end
                                                        end
                                                end
                                        end
                                end)
                        end

                        if Toggles.targetvis_tracer.Value or Toggles.targetvis_highlight.Value then
                                local camera = workspace.CurrentCamera
                                local part = getClosestTargetPart()
                                ensureTargetDrawings()
                                local targetVisible = false
                                if camera and part then
                                        local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                                        if onScreen or Options.targetvis_culling.Value == "AlwaysOnTop" then
                                                targetVisible = true
                                                local targetPos = Vector2.new(pos.X, pos.Y)
                                                if Toggles.targetvis_tracer.Value then
                                                        local muzzle = getMuzzleWorld()
                                                        local fromPos = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                                                        if muzzle then
                                                                local mp = camera:WorldToViewportPoint(muzzle)
                                                                if mp and mp.Z > 0 then
                                                                        fromPos = Vector2.new(mp.X, mp.Y)
                                                                end
                                                        end
                                                        targetTracerLine.From = fromPos
                                                        targetTracerLine.To = targetPos
                                                        targetTracerLine.Color = Options.targetvis_tracer_color.Value
                                                        targetTracerLine.Visible = true
                                                else
                                                        targetTracerLine.Visible = false
                                                end
                                                if Toggles.targetvis_highlight.Value then
                                                        targetHighlightSquare.Color = Options.targetvis_highlight_color.Value
                                                        targetHighlightSquare.Size = Vector2.new(22, 22)
                                                        targetHighlightSquare.Position = targetPos - Vector2.new(11, 11)
                                                        targetHighlightSquare.Visible = true
                                                else
                                                        targetHighlightSquare.Visible = false
                                                end
                                        end
                                end
                                if not targetVisible then
                                        targetTracerLine.Visible = false
                                        targetHighlightSquare.Visible = false
                                end
                        end
                end)
        end)
        maid(function()
                hideDrawings(crosshairLines)
                hideDrawings(crosshairOutlines)
                if targetTracerLine then
                        pcall(function()
                                targetTracerLine:Remove()
                        end)
                end
                if targetHighlightSquare then
                        pcall(function()
                                targetHighlightSquare:Remove()
                        end)
                end
        end)

        local indicatorTexts = {}

        task.spawn(function()
                while not h2o.Unloaded do
                        task.wait(0.05)
                        pcall(function()
                                local lines = {}
                                if Toggles.indicator_manipulated.Value and Toggles.antiaim_enabled.Value then
                                        table.insert(lines, "manipulated")
                                end
                                if Toggles.indicator_ammo.Value then
                                        local fighter = getLocalFighter()
                                        if fighter and fighter.EquippedItem then
                                                local ok, ammo = pcall(function()
                                                        return tostring(fighter.EquippedItem:Get("Ammo")) .. ", " .. tostring(fighter.EquippedItem:Get("AmmoReserve"))
                                                end)
                                                if ok then
                                                        table.insert(lines, ammo)
                                                end
                                        end
                                end
                                if #lines == 0 then
                                        for _, text in pairs(indicatorTexts) do
                                                pcall(function()
                                                        text.Visible = false
                                                end)
                                        end
                                        return
                                end
                                local mouse = UserInputService:GetMouseLocation()
                                local origin = Vector2.new(mouse.X + Options.indicator_offsetx.Value, mouse.Y + Options.indicator_offsety.Value)
                                for i, line in ipairs(lines) do
                                        if Options.indicator_style.Value == "upper" then
                                                line = line:upper()
                                        end
                                        local text = indicatorTexts[i]
                                        if not text then
                                                text = Drawing.new("Text")
                                                text.Size = 13
                                                text.Center = false
                                                text.Outline = true
                                                indicatorTexts[i] = text
                                        end
                                        text.Text = line
                                        text.Position = origin + Vector2.new(0, (i - 1) * 14)
                                        text.Color = Color3.fromRGB(255, 255, 255)
                                        text.Visible = true
                                end
                                for i = #lines + 1, #indicatorTexts do
                                        indicatorTexts[i].Visible = false
                                end
                        end)
                end
        end)
        maid(function()
                for _, text in pairs(indicatorTexts) do
                        pcall(function()
                                text:Remove()
                        end)
                end
        end)

        local xrayModified = {}

        local function xrayApply(value)
                pcall(function()
                        for part in pairs(xrayModified) do
                                if part.Parent then
                                        part.LocalTransparencyModifier = value
                                end
                        end
                end)
        end

        local function xrayScan()
                pcall(function()
                        for _, desc in ipairs(workspace:GetDescendants()) do
                                if desc:IsA("BasePart") and not desc:IsDescendantOf(LocalPlayer.Character) then
                                        xrayModified[desc] = true
                                        desc.LocalTransparencyModifier = Options.xray_transparency.Value
                                end
                        end
                end)
        end

        local xrayConn = nil
        Toggles.xray_enabled:OnChanged(function()
                if Toggles.xray_enabled.Value then
                        xrayScan()
                        xrayConn = workspace.DescendantAdded:Connect(function(desc)
                                if desc:IsA("BasePart") then
                                        xrayModified[desc] = true
                                        desc.LocalTransparencyModifier = Options.xray_transparency.Value
                                end
                        end)
                else
                        if xrayConn then
                                xrayConn:Disconnect()
                                xrayConn = nil
                        end
                        xrayApply(0)
                        table.clear(xrayModified)
                end
        end)
        Options.xray_transparency:OnChanged(function()
                if Toggles.xray_enabled.Value then
                        xrayApply(Options.xray_transparency.Value)
                end
        end)
        maid(function()
                if xrayConn then
                        xrayConn:Disconnect()
                end
                xrayApply(0)
                table.clear(xrayModified)
        end)
end

do
        local MovementGroup = h2o.Tabs.character:AddLeftGroupbox("movement", "gauge")

        MovementGroup:AddToggle("move_velocity", { Text = "velocity", Default = false, Tooltip = "overrides your movement speed" })
        MovementGroup:AddSlider("move_velocity_speed", { Text = "velocity speed", Min = 0, Max = 250, Default = 50, Rounding = 0, Suffix = " studs/s" })
        MovementGroup:AddToggle("move_slideboost", { Text = "slide boost", Default = false })
        MovementGroup:AddSlider("move_slideboost_value", { Text = "slide boost", Min = 1, Max = 5, Default = 1, Rounding = 1, Suffix = "x" })
        MovementGroup:AddToggle("move_djheight", { Text = "double jump height", Default = false })
        MovementGroup:AddSlider("move_djheight_value", { Text = "double jump height", Min = 1, Max = 10, Default = 1, Rounding = 1, Suffix = "x" })
        MovementGroup:AddToggle("move_maulslam", { Text = "maul slam multiplier", Default = false })
        MovementGroup:AddSlider("move_maulslam_value", { Text = "maul slam multiplier", Min = 1, Max = 10, Default = 1, Rounding = 1, Suffix = "x" })
        MovementGroup:AddToggle("move_infdj", { Text = "infinite double jump", Default = false })

        local slideOriginals = {}
        local itemOriginals = {}
        local djHookInstalled = false

        local function restoreSlideBoost()
                pcall(function()
                        local fighter = getLocalFighter()
                        if fighter and slideOriginals[fighter] then
                                fighter:Set("SlidingSpeedMax", slideOriginals[fighter])
                                slideOriginals[fighter] = nil
                        end
                end)
        end

        local function restoreItemInfo()
                pcall(function()
                        local fighter = getLocalFighter()
                        local item = fighter and fighter.EquippedItem
                        if item and item.Info and itemOriginals[item] then
                                for key, value in pairs(itemOriginals[item]) do
                                        item.Info[key] = value
                                end
                                itemOriginals[item] = nil
                        end
                end)
        end

        local function ensureDoubleJumpHook()
                if djHookInstalled then
                        return
                end
                pcall(function()
                        local mech = require(LocalPlayer.PlayerScripts.Controllers.MechanicsController)
                        if type(mech) == "table" and type(mech.DoubleJump) == "function" and not mech.__h2oDoubleJump then
                                local original = mech.DoubleJump
                                mech.__h2oDoubleJump = original
                                mech.DoubleJump = function(self, ...)
                                        local results = { original(self, ...) }
                                        if Toggles.move_djheight.Value then
                                                pcall(function()
                                                        local fighter = self.LocalFighter or getLocalFighter()
                                                        local root = (fighter and fighter.Entity and fighter.Entity.RootPart) or getRoot()
                                                        if root then
                                                                local v = root.AssemblyLinearVelocity
                                                                root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y * Options.move_djheight_value.Value, v.Z)
                                                        end
                                                end)
                                        end
                                        return unpack(results)
                                end
                                djHookInstalled = true
                        end
                end)
        end

        local moveAccum = 0
        maid(RunService.Heartbeat:Connect(function(dt)
                if h2o.Unloaded then
                        return
                end
                moveAccum += dt
                if moveAccum < 0.15 then
                        return
                end
                moveAccum = 0
                pcall(function()
                        if Toggles.move_velocity.Value and isAlive() then
                                local root = getRoot()
                                local humanoid = getHumanoid()
                                if root and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
                                        local v = root.AssemblyLinearVelocity
                                        local dir = humanoid.MoveDirection
                                        root.AssemblyLinearVelocity = Vector3.new(dir.X * Options.move_velocity_speed.Value, v.Y, dir.Z * Options.move_velocity_speed.Value)
                                end
                        end
                        if Toggles.move_slideboost.Value or Toggles.move_maulslam.Value or Toggles.move_infdj.Value then
                                local fighter = getLocalFighter()
                                if fighter then
                                        if Toggles.move_slideboost.Value then
                                                if slideOriginals[fighter] == nil then
                                                        local ok, base = pcall(function()
                                                                return fighter:Get("SlidingSpeedMax")
                                                        end)
                                                        if ok and base then
                                                                slideOriginals[fighter] = base
                                                        end
                                                end
                                                if slideOriginals[fighter] then
                                                        pcall(function()
                                                                fighter:Set("SlidingSpeedMax", slideOriginals[fighter] * Options.move_slideboost_value.Value)
                                                        end)
                                                end
                                        end
                                        local item = fighter.EquippedItem
                                        if item and item.Info then
                                                if Toggles.move_maulslam.Value then
                                                        if itemOriginals[item] == nil then
                                                                itemOriginals[item] = {}
                                                        end
                                                        if itemOriginals[item].SlamDamage == nil and item.Info.SlamDamage then
                                                                itemOriginals[item].SlamDamage = item.Info.SlamDamage
                                                                itemOriginals[item].SlamRadius = item.Info.SlamRadius
                                                        end
                                                        if itemOriginals[item].SlamDamage then
                                                                item.Info.SlamDamage = itemOriginals[item].SlamDamage * Options.move_maulslam_value.Value
                                                                item.Info.SlamRadius = itemOriginals[item].SlamRadius * Options.move_maulslam_value.Value
                                                        end
                                                end
                                                if Toggles.move_infdj.Value and item.Info.MaxDoubleJumps then
                                                        item.Info.MaxDoubleJumps = math.huge
                                                end
                                        end
                                end
                        end
                        if Toggles.move_djheight.Value then
                                ensureDoubleJumpHook()
                        end
                end)
        end))

        Toggles.move_slideboost:OnChanged(function()
                if not Toggles.move_slideboost.Value then
                        restoreSlideBoost()
                end
        end)
        Toggles.move_maulslam:OnChanged(function()
                if not Toggles.move_maulslam.Value then
                        restoreItemInfo()
                end
        end)
        maid(function()
                restoreSlideBoost()
                restoreItemInfo()
        end)

        local AirJumpGroup = h2o.Tabs.character:AddLeftGroupbox("air jump", "arrow-up")

        AirJumpGroup:AddToggle("airjump_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "jump in mid air by holding space",
        })
        AirJumpGroup:AddSlider("airjump_velocity", { Text = "velocity", Min = 50, Max = 300, Default = 50, Rounding = 0 })

        maid(UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then
                        return
                end
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Space then
                        task.spawn(function()
                                while UserInputService:IsKeyDown(Enum.KeyCode.Space) and Toggles.airjump_enabled.Value and not h2o.Unloaded do
                                        if isAlive() then
                                                local root = getRoot()
                                                if root then
                                                        local v = root.AssemblyLinearVelocity
                                                        root.AssemblyLinearVelocity = Vector3.new(v.X, Options.airjump_velocity.Value, v.Z)
                                                end
                                        end
                                        RunService.Heartbeat:Wait()
                                end
                        end)
                end
        end))

        local PhaseGroup = h2o.Tabs.character:AddLeftGroupbox("phase", "ghost")

        PhaseGroup:AddToggle("phase_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "walk through walls",
        })
        PhaseGroup:AddDropdown("phase_mode", {
                Values = { "Character", "CFrame", "Motor", "FFlag" },
                Default = "Character",
                Text = "mode",
        })
        PhaseGroup:AddSlider("phase_wallsize", { Text = "wall size", Min = 1, Max = 20, Default = 5, Rounding = 0, Suffix = " studs" })

        local phaseModified = {}
        local phaseFFlagSet = false
        local phaseConn = nil

        local function phaseRestore()
                for part in pairs(phaseModified) do
                        pcall(function()
                                if part.Parent then
                                        part.CanCollide = true
                                end
                        end)
                end
                table.clear(phaseModified)
                if phaseFFlagSet and setfflag then
                        pcall(setfflag, "AssemblyExtentsExpansionStudHundredth", "30")
                        phaseFFlagSet = false
                end
        end

        Toggles.phase_enabled:OnChanged(function()
                if Toggles.phase_enabled.Value then
                        phaseConn = RunService.Stepped:Connect(function()
                                if not isAlive() then
                                        return
                                end
                                local root = getRoot()
                                local char = LocalPlayer.Character
                                if not root or not char then
                                        return
                                end
                                local mode = Options.phase_mode.Value
                                if mode == "Character" then
                                        for _, part in ipairs(char:GetDescendants()) do
                                                if part:IsA("BasePart") and part.CanCollide then
                                                        part.CanCollide = false
                                                        phaseModified[part] = true
                                                end
                                        end
                                elseif mode == "CFrame" or mode == "Motor" then
                                        local head = char:FindFirstChild("Head")
                                        local humanoid = getHumanoid()
                                        if head and humanoid and humanoid.MoveDirection.Magnitude > 0 then
                                                local rayParams = RaycastParams.new()
                                                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                                                rayParams.FilterDescendantsInstances = { char, workspace.CurrentCamera }
                                                rayParams.RespectCanCollide = true
                                                local ray = workspace:Raycast(head.Position, humanoid.MoveDirection * 1.1, rayParams)
                                                if ray then
                                                        local instance = ray.Instance
                                                        if instance and instance:IsA("BasePart") then
                                                                local axis = math.abs(ray.Normal.X) > math.abs(ray.Normal.Z) and "X" or "Z"
                                                                if instance.Size[axis] <= Options.phase_wallsize.Value then
                                                                        local dest = root.CFrame + ray.Normal * (-(Options.phase_wallsize.Value) - (root.Size.X / 1.5))
                                                                        local parts = workspace:GetPartBoundsInBox(dest, Vector3.one)
                                                                        if #parts <= 0 then
                                                                                root.CFrame = dest
                                                                        end
                                                                end
                                                        end
                                                end
                                        end
                                elseif mode == "FFlag" then
                                        if not phaseFFlagSet and setfflag then
                                                pcall(setfflag, "AssemblyExtentsExpansionStudHundredth", "-10000")
                                                phaseFFlagSet = true
                                        end
                                end
                        end)
                else
                        if phaseConn then
                                phaseConn:Disconnect()
                                phaseConn = nil
                        end
                        phaseRestore()
                end
        end)
        Options.phase_mode:OnChanged(function()
                phaseRestore()
        end)
        maid(function()
                if phaseConn then
                        phaseConn:Disconnect()
                end
                phaseRestore()
        end)

        local playSelected, stopAnimation

        local AnimGroup = h2o.Tabs.character:AddLeftGroupbox("animation player", "play")

        local animations = {
                Bodybuilder = "3994130516",
                ["Crawling in a Circle"] = "116935126100338",
                ["Dolphin Dance"] = "5938365243",
                Dance = "507771019",
                ["Dance Break"] = "94258912028011",
                ["French Confidence"] = "116968182519797",
                Floss = "72174079036035",
                ["Frosty Flair"] = "10214406616",
                ["Full Wiggle"] = "86520127496722",
                ["Ghost Floating"] = "75911227509248",
                Gun = "81100102810594",
                ["Gangnam Style"] = "78801539668900",
                ["Hip Bounce"] = "123602332785269",
                ["Hype Dance"] = "93079641847306",
                ["Kicking Feet"] = "109814083870185",
                ["Line Dance"] = "4049646104",
                ["Lay Floating"] = "126579240140537",
                ["Let's Drive"] = "17360720445",
                ["Long Legs"] = "82416741608012",
                ["Rock Out"] = "18225077553",
                Samba = "6869813008",
                ["Still Standing"] = "11435177473",
                Spiral = "81926730031709",
                ["Solar System"] = "118314972618293",
                Twirl = "3716633898",
                ["Take Me Under"] = "6797938823",
                ["The Worm"] = "99563207397301",
                ["Take the L"] = "110664723286332",
                Zesty = "102901317133934",
        }

        local animationList = {
                "Bodybuilder", "Custom", "Crawling in a Circle", "Dolphin Dance", "Dance", "Dance Break",
                "French Confidence", "Floss", "Frosty Flair", "Full Wiggle", "Ghost Floating", "Gangnam Style",
                "Gun", "Hip Bounce", "Hype Dance", "Kicking Feet", "Line Dance", "Lay Floating", "Let's Drive",
                "Long Legs", "Rock Out", "Samba", "Still Standing", "Spiral", "Solar System", "Twirl",
                "Take Me Under", "The Worm", "Take the L", "Zesty",
        }

        AnimGroup:AddDropdown("anim_selected", {
                Values = animationList,
                Default = "Floss",
                Text = "animation",
                Searchable = true,
        })
        AnimGroup:AddInput("anim_custom", {
                Default = "",
                Numeric = true,
                Text = "custom animation",
                Placeholder = "id... (ex: 4049646104)",
        })
        AnimGroup:AddSlider("anim_speed", { Text = "speed", Min = 0.1, Max = 5, Default = 1, Rounding = 1 })
        AnimGroup:AddSlider("anim_start", { Text = "start", Min = 0, Max = 99, Default = 0, Rounding = 0, Suffix = "%", Compact = true })
        AnimGroup:AddSlider("anim_end", { Text = "end", Min = 1, Max = 100, Default = 100, Rounding = 0, Suffix = "%", Compact = true })
        AnimGroup:AddButton({
                Text = "play animation",
                Func = function()
                        playSelected()
                end,
        })
        AnimGroup:AddButton({
                Text = "stop animation",
                Func = function()
                        stopAnimation()
                end,
        })

        local currentTrack, currentAnimation = nil, nil
        local replayToken = 0

        stopAnimation = function()
                replayToken += 1
                pcall(function()
                        if currentTrack then
                                currentTrack:Stop(0.1)
                                currentTrack:Destroy()
                        end
                        if currentAnimation then
                                currentAnimation:Destroy()
                        end
                end)
                currentTrack, currentAnimation = nil, nil
        end

        playSelected = function()
                stopAnimation()
                local token = replayToken
                task.spawn(function()
                        pcall(function()
                                local character = LocalPlayer.Character
                                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                                local animator = humanoid and character:FindFirstChildOfClass("Animator")
                                if not animator then
                                        return
                                end
                                local id
                                if Options.anim_selected.Value == "Custom" then
                                        id = tostring(Options.anim_custom.Value):match("%d+")
                                else
                                        id = animations[Options.anim_selected.Value]
                                end
                                if not id then
                                        return
                                end
                                local animation = Instance.new("Animation")
                                animation.AnimationId = "rbxassetid://" .. id
                                currentAnimation = animation
                                local track = animator:LoadAnimation(animation)
                                track.Priority = Enum.AnimationPriority.Action4
                                track.Looped = true
                                currentTrack = track
                                track:Play(0.1, 1, Options.anim_speed.Value)
                                task.spawn(function()
                                        while token == replayToken and not h2o.Unloaded and track and track.Parent do
                                                local length = track.Length
                                                if length > 0 then
                                                        local startPercent = Options.anim_start.Value / 100
                                                        local endPercent = Options.anim_end.Value / 100
                                                        if endPercent <= startPercent then
                                                                endPercent = math.min(startPercent + 0.01, 1)
                                                        end
                                                        local timePos = track.TimePosition
                                                        if timePos < length * startPercent or timePos > length * endPercent then
                                                                track.TimePosition = length * startPercent
                                                        end
                                                end
                                                if not track.IsPlaying then
                                                        track:Play(0.05, 1, Options.anim_speed.Value)
                                                end
                                                pcall(function()
                                                        track:AdjustSpeed(Options.anim_speed.Value)
                                                end)
                                                RunService.Heartbeat:Wait()
                                        end
                                end)
                        end)
                end)
        end

        Options.anim_selected:OnChanged(function()
                playSelected()
        end)
        Options.anim_custom:OnChanged(function()
                if Options.anim_selected.Value == "Custom" then
                        playSelected()
                end
        end)
        Options.anim_speed:OnChanged(function()
                pcall(function()
                        if currentTrack then
                                currentTrack:AdjustSpeed(Options.anim_speed.Value)
                        end
                end)
        end)
        maid(function()
                stopAnimation()
        end)

        local TimerGroup = h2o.Tabs.character:AddLeftGroupbox("timer", "timer")

        TimerGroup:AddToggle("timer_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "extra physics steps per frame",
        })
        TimerGroup:AddSlider("timer_value", { Text = "value", Min = 1, Max = 3, Default = 1, Rounding = 1 })

        if setfflag then
                Toggles.timer_enabled:OnChanged(function()
                        if Toggles.timer_enabled.Value then
                                pcall(setfflag, "SimEnableStepPhysics", "True")
                                pcall(setfflag, "SimEnableStepPhysicsSelective", "True")
                        end
                end)
        end

        local timerConn = RunService.RenderStepped:Connect(function(dt)
                if h2o.Unloaded then
                        return
                end
                pcall(function()
                        if Toggles.timer_enabled.Value and Options.timer_value.Value > 1 then
                                local root = getRoot()
                                if root then
                                        RunService:Pause()
                                        workspace:StepPhysics(dt * (Options.timer_value.Value - 1), { root })
                                        RunService:Run()
                                end
                        end
                end)
        end)
        maid(timerConn)

        local FlyGroup = h2o.Tabs.character:AddRightGroupbox("fly", "plane")

        FlyGroup:AddToggle("fly_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "WASD + Space/E up + Ctrl/Q down",
        })
        FlyGroup:AddSlider("fly_speed", { Text = "fly speed", Min = 50, Max = 200, Default = 50, Rounding = 0, Suffix = " studs/s" })

        local flyGyro, flyVelocity = nil, nil
        local flyKeys = { W = false, S = false, A = false, D = false, Up = false, Down = false }

        local function startFly()
                local root = getRoot()
                local humanoid = getHumanoid()
                if not root or not humanoid then
                        return
                end
                pcall(function()
                        if flyGyro then
                                flyGyro:Destroy()
                        end
                        if flyVelocity then
                                flyVelocity:Destroy()
                        end
                end)
                flyGyro = Instance.new("BodyGyro")
                flyGyro.P = 9e4
                flyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                flyGyro.CFrame = root.CFrame
                flyGyro.Parent = root
                flyVelocity = Instance.new("BodyVelocity")
                flyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                flyVelocity.Velocity = Vector3.zero
                flyVelocity.Parent = root
                humanoid.PlatformStand = true
        end

        local function stopFly()
                pcall(function()
                        if flyGyro then
                                flyGyro:Destroy()
                        end
                        if flyVelocity then
                                flyVelocity:Destroy()
                        end
                end)
                flyGyro, flyVelocity = nil, nil
                local humanoid = getHumanoid()
                if humanoid then
                        humanoid.PlatformStand = false
                end
                local camera = workspace.CurrentCamera
                if camera then
                        camera.CameraType = Enum.CameraType.Custom
                end
        end

        local keyMap = {
                [Enum.KeyCode.W] = "W",
                [Enum.KeyCode.S] = "S",
                [Enum.KeyCode.A] = "A",
                [Enum.KeyCode.D] = "D",
                [Enum.KeyCode.Space] = "Up",
                [Enum.KeyCode.E] = "Up",
                [Enum.KeyCode.LeftControl] = "Down",
                [Enum.KeyCode.Q] = "Down",
        }

        maid(UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then
                        return
                end
                local key = keyMap[input.KeyCode]
                if key then
                        flyKeys[key] = true
                end
        end))
        maid(UserInputService.InputEnded:Connect(function(input)
                local key = keyMap[input.KeyCode]
                if key then
                        flyKeys[key] = false
                end
        end))

        Toggles.fly_enabled:OnChanged(function()
                if Toggles.fly_enabled.Value then
                        startFly()
                else
                        stopFly()
                end
        end)
        maid(LocalPlayer.CharacterAdded:Connect(function()
                if Toggles.fly_enabled.Value then
                        task.wait(0.25)
                        if Toggles.fly_enabled.Value then
                                startFly()
                        end
                end
        end))
        maid(stopFly)

        local flyConn = RunService.RenderStepped:Connect(function()
                if h2o.Unloaded then
                        return
                end
                pcall(function()
                        if not Toggles.fly_enabled.Value then
                                return
                        end
                        if not (flyGyro and flyGyro.Parent and flyVelocity and flyVelocity.Parent) then
                                startFly()
                                return
                        end
                        local humanoid = getHumanoid()
                        if humanoid then
                                humanoid.PlatformStand = true
                        end
                        local camera = workspace.CurrentCamera
                        local root = getRoot()
                        if not camera or not root then
                                return
                        end
                        pcall(function()
                                camera.CameraType = Enum.CameraType.Track
                        end)
                        flyGyro.CFrame = camera.CFrame
                        local move = camera.CFrame.LookVector * ((flyKeys.W and 1 or 0) - (flyKeys.S and 1 or 0))
                                + camera.CFrame.RightVector * ((flyKeys.D and 1 or 0) - (flyKeys.A and 1 or 0))
                                + Vector3.yAxis * ((flyKeys.Up and 1 or 0) - (flyKeys.Down and 1 or 0))
                        if move.Magnitude > 0 then
                                flyVelocity.Velocity = move.Unit * Options.fly_speed.Value
                        else
                                flyVelocity.Velocity = Vector3.zero
                        end
                end)
        end)
        maid(flyConn)

        local NoclipGroup = h2o.Tabs.character:AddRightGroupbox("noclip", "door-open")

        NoclipGroup:AddToggle("noclip_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "walk through walls",
        })

        local noclipConn = nil
        Toggles.noclip_enabled:OnChanged(function()
                if Toggles.noclip_enabled.Value then
                        noclipConn = RunService.Stepped:Connect(function()
                                local char = LocalPlayer.Character
                                if char then
                                        for _, part in ipairs(char:GetDescendants()) do
                                                if part:IsA("BasePart") and part.CanCollide then
                                                        part.CanCollide = false
                                                end
                                        end
                                end
                        end)
                elseif noclipConn then
                        noclipConn:Disconnect()
                        noclipConn = nil
                        local char = LocalPlayer.Character
                        if char then
                                for _, part in ipairs(char:GetDescendants()) do
                                        if part:IsA("BasePart") then
                                                part.CanCollide = true
                                        end
                                end
                        end
                end
        end)
        maid(function()
                if noclipConn then
                        noclipConn:Disconnect()
                end
                local char = LocalPlayer.Character
                if char then
                        for _, part in ipairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                        part.CanCollide = true
                                end
                        end
                end
        end)

        local ThirdPersonGroup = h2o.Tabs.character:AddRightGroupbox("third person", "user")

        ThirdPersonGroup:AddToggle("thirdperson_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "forces third person camera",
        })
        ThirdPersonGroup:AddDropdown("thirdperson_mode", {
                Values = { "ThirdPerson", "ThirdPerson Mirrored" },
                Default = "ThirdPerson",
                Text = "mode",
        })
        ThirdPersonGroup:AddToggle("thirdperson_unlock", { Text = "unlock mouse", Default = false })

        local thirdPersonThread = nil
        local thirdPersonGeneration = 0

        Toggles.thirdperson_enabled:OnChanged(function()
                thirdPersonGeneration += 1
                local myGeneration = thirdPersonGeneration
                if Toggles.thirdperson_enabled.Value then
                        thirdPersonThread = task.spawn(function()
                                while Toggles.thirdperson_enabled.Value and not h2o.Unloaded and thirdPersonGeneration == myGeneration do
                                        pcall(function()
                                                local controller = require(LocalPlayer.PlayerScripts.Controllers.CameraController)
                                                local state = controller.CameraState
                                                if Options.thirdperson_mode.Value == "ThirdPerson Mirrored" then
                                                        state:_SetPOVState(state.States.ThirdPersonMirrored)
                                                else
                                                        state:_SetPOVState(state.States.ThirdPerson)
                                                end
                                                if Toggles.thirdperson_unlock.Value then
                                                        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                                                end
                                        end)
                                        task.wait(0.1)
                                end
                        end)
                else
                        pcall(function()
                                if thirdPersonThread then
                                        task.cancel(thirdPersonThread)
                                end
                        end)
                        thirdPersonThread = nil
                        pcall(function()
                                local controller = require(LocalPlayer.PlayerScripts.Controllers.CameraController)
                                controller.CameraState:_SetPOVState(controller.CameraState.States.FirstPerson)
                                UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
                        end)
                end
        end)
        maid(function()
                pcall(function()
                        if thirdPersonThread then
                                task.cancel(thirdPersonThread)
                        end
                end)
        end)

        local KatanaGroup = h2o.Tabs.character:AddRightGroupbox("anti katana", "shield")

        KatanaGroup:AddToggle("antikatana_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "blocks your shots while enemies deflect with katana",
        })
        KatanaGroup:AddToggle("antikatana_sound", {
                Text = "deflect sound",
                Default = true,
                Tooltip = "plays a sound when shots are blocked",
        })

        local katanaState = { enabled = false, deflecting = {}, hooksReady = false }
        local deflectSound = nil

        local function stopDeflectSound()
                if deflectSound then
                        pcall(function()
                                deflectSound:Stop()
                                deflectSound:Destroy()
                        end)
                        deflectSound = nil
                end
        end

        local function markEnemyDeflect(self)
                pcall(function()
                        local fighter = rawget(self, "ClientFighter") or self.ClientFighter
                        if not fighter or fighter.IsLocalPlayer then
                                return
                        end
                        local player = fighter.Player
                        local key = player and player.UserId or fighter:Get("ObjectID")
                        if key then
                                local duration = 1
                                pcall(function()
                                        duration = self.Info.DeflectDuration or 1
                                end)
                                katanaState.deflecting[key] = tick() + duration + 0.12
                                task.delay(duration + 0.2, function()
                                        katanaState.deflecting[key] = nil
                                end)
                        end
                end)
        end

        local function hasActiveDeflect()
                local now = tick()
                for key, expiry in pairs(katanaState.deflecting) do
                        if expiry > now then
                                return true
                        else
                                katanaState.deflecting[key] = nil
                        end
                end
                return false
        end

        local function setupKatanaHooks()
                if katanaState.hooksReady then
                        return
                end
                local katanaHooked, fireHooked = false, false
                pcall(function()
                        local katanaModule = require(LocalPlayer.PlayerScripts.Modules.Items.Katana)
                        local katanaClass = type(katanaModule) == "table" and katanaModule or nil
                        if katanaClass and type(katanaClass.ReplicateFromServer) == "function" and not katanaClass.__h2oKatanaHook then
                                local original = katanaClass.ReplicateFromServer
                                katanaClass.__h2oKatanaHook = original
                                katanaClass.ReplicateFromServer = function(self, action, ...)
                                        pcall(function()
                                                if katanaState.enabled and tostring(self.Name) == "Katana" then
                                                        local actionName = tostring(action)
                                                        local ok, enumName = pcall(function()
                                                                return self:FromEnum(action)
                                                        end)
                                                        if ok and enumName then
                                                                actionName = tostring(enumName)
                                                        end
                                                        actionName = actionName:lower()
                                                        if actionName == "startaiming" or actionName == "startblocking" or actionName == "deflect" or actionName == "startdeflect" or actionName:find("deflect", 1, true) then
                                                                markEnemyDeflect(self)
                                                        end
                                                end
                                        end)
                                        return original(self, action, ...)
                                end
                                katanaHooked = true
                        end
                end)
                pcall(function()
                        local gunModule = require(LocalPlayer.PlayerScripts.Modules.ItemTypes.Gun)
                        if type(gunModule) == "table" and type(gunModule.StartShooting) == "function" and not gunModule.__h2oStartShootingHook then
                                local original = gunModule.StartShooting
                                gunModule.__h2oStartShootingHook = original
                                gunModule.StartShooting = function(self, ...)
                                        if katanaState.enabled and hasActiveDeflect() then
                                                if Toggles.antikatana_sound.Value and not deflectSound then
                                                        deflectSound = Instance.new("Sound")
                                                        deflectSound.SoundId = "rbxassetid://1848354536"
                                                        deflectSound.Volume = 0.6
                                                        deflectSound.Looped = true
                                                        deflectSound.Parent = workspace
                                                        deflectSound:Play()
                                                end
                                                return
                                        end
                                        if katanaState.enabled then
                                                stopDeflectSound()
                                        end
                                        return original(self, ...)
                                end
                                fireHooked = true
                        end
                end)
                if katanaHooked and fireHooked then
                        katanaState.hooksReady = true
                end
        end

        Toggles.antikatana_enabled:OnChanged(function()
                katanaState.enabled = Toggles.antikatana_enabled.Value
                if katanaState.enabled then
                        task.spawn(function()
                                while katanaState.enabled and not h2o.Unloaded and not katanaState.hooksReady do
                                        setupKatanaHooks()
                                        task.wait(0.5)
                                end
                        end)
                else
                        katanaState.deflecting = {}
                        stopDeflectSound()
                end
        end)
        maid(function()
                katanaState.enabled = false
                stopDeflectSound()
        end)

        local StaffGroup = h2o.Tabs.character:AddRightGroupbox("staff detector", "radar")

        StaffGroup:AddToggle("staff_enabled", {
                Text = "enabled",
                Default = false,
                Tooltip = "detects group staff in the server",
        })
        StaffGroup:AddDropdown("staff_mode", {
                Values = { "Notify", "ServerHop", "Uninject" },
                Default = "Notify",
                Text = "action",
        })

        local staffDetected = false

        local function serverHop()
                task.spawn(function()
                        local attempted = {}
                        local visited = {}
                        pcall(function()
                                if writefile and isfile and isfile("h2o/serverhop.txt") then
                                        for id in readfile("h2o/serverhop.txt"):gmatch("[^/]+") do
                                                visited[id] = true
                                        end
                                end
                        end)
                        visited[game.JobId] = true
                        local cursor = ""
                        for _ = 1, 5 do
                                local ok, response = pcall(function()
                                        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=2&excludeFullGames=true&limit=100"):format(game.PlaceId)
                                        if cursor ~= "" then
                                                url = url .. "&cursor=" .. cursor
                                        end
                                        return game:HttpGet(url)
                                end)
                                if not ok then
                                        return
                                end
                                pcall(function()
                                        local decoded = HttpService:JSONDecode(response)
                                        for _, server in ipairs(decoded.data or {}) do
                                                local maxPlayers = server.maxPlayers or Players.MaxPlayers
                                                if server.playing < maxPlayers and not visited[server.id] and not attempted[server.id] then
                                                        attempted[server.id] = true
                                                        pcall(function()
                                                                if writefile then
                                                                        local list = {}
                                                                        for id in pairs(visited) do
                                                                                table.insert(list, id)
                                                                        end
                                                                        writefile("h2o/serverhop.txt", table.concat(list, "/"))
                                                                end
                                                        end)
                                                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                                                        return
                                                end
                                        end
                                        cursor = decoded.nextPageCursor or ""
                                end)
                                if cursor == "" then
                                        break
                                end
                                task.wait(0.5)
                        end
                end)
        end

        local function staffAction()
                if Options.staff_mode.Value == "ServerHop" then
                        notify("staff detected - server hopping", 10)
                        serverHop()
                elseif Options.staff_mode.Value == "Uninject" then
                        notify("staff detected - uninjecting", 5)
                        Library:Unload()
                else
                        notify("staff detected in this game", 10)
                end
        end

        local function isStaffRole(roleName)
                local lower = tostring(roleName):lower()
                return lower:find("mod", 1, true)
                        or lower:find("staff", 1, true)
                        or lower:find("contributor", 1, true)
                        or lower:find("script", 1, true)
                        or lower:find("build", 1, true)
        end

        local function checkStaff()
                if staffDetected or game.GameId ~= 6035872082 or game.CreatorType ~= Enum.CreatorType.Group then
                        return
                end
                task.spawn(function()
                        pcall(function()
                                local groupId = game.CreatorId
                                for _, plr in ipairs(Players:GetPlayers()) do
                                        if plr ~= LocalPlayer then
                                                local ok, role = pcall(function()
                                                        return plr:GetRoleInGroup(groupId)
                                                end)
                                                if ok and isStaffRole(role) then
                                                        staffDetected = true
                                                        staffAction()
                                                        return
                                                end
                                        end
                                end
                        end)
                end)
        end

        Toggles.staff_enabled:OnChanged(function()
                if Toggles.staff_enabled.Value then
                        checkStaff()
                else
                        staffDetected = false
                end
        end)
        maid(Players.PlayerAdded:Connect(function(plr)
                task.delay(3, function()
                        if Toggles.staff_enabled.Value and not staffDetected then
                                checkStaff()
                        end
                end)
        end))
end

do
        local MenuGroup = h2o.Tabs.settings:AddLeftGroupbox("menu", "wrench")

        MenuGroup:AddDropdown("notify_side", {
                Values = { "Left", "Right" },
                Default = "Right",
                Text = "notification side",
        })
        MenuGroup:AddDivider()
        MenuGroup:AddLabel("menu bind"):AddKeyPicker("MenuKeybind", {
                Default = "RightShift",
                NoUI = true,
                Text = "menu keybind",
        })
        MenuGroup:AddButton({
                Text = "unload",
                Func = function()
                        Library:Unload()
                end,
        })

        Library.ToggleKeybind = Options.MenuKeybind

        Options.notify_side:OnChanged(function()
                Library:SetNotifySide(Options.notify_side.Value)
        end)
end

do
        local StartupGroup = h2o.Tabs.settings:AddLeftGroupbox("startup", "rocket")

        local function sourceStatus()
                if h2o.StartupState.path ~= "" then
                        return "rerun source: file path"
                elseif h2o.StartupState.url ~= "" then
                        return "rerun source: url"
                elseif h2o.SourceCached then
                        return "rerun source: cached script"
                end
                return "rerun source: unavailable"
        end

        StartupGroup:AddToggle("startup_rerun", {
                Text = "re-run after teleport",
                Default = h2o.StartupState.rerun,
                Tooltip = "automatically re-executes h2o after any game teleport",
        })
        StartupGroup:AddToggle("startup_silent", {
                Text = "silent load",
                Default = h2o.StartupState.silent,
                Tooltip = "menu stays hidden the next time the script loads - open it with your menu keybind",
        })
        StartupGroup:AddDivider()
        local SourceLabel = StartupGroup:AddLabel(sourceStatus(), true)
        local SourceInput = StartupGroup:AddInput("startup_source", {
                Default = h2o.StartupState.path ~= "" and h2o.StartupState.path or h2o.StartupState.url,
                Text = "rerun source",
                Placeholder = "script url or local file path",
                Tooltip = "where h2o is re-loaded from after a teleport - click test to confirm it",
        })
        StartupGroup:AddButton({
                Text = "test rerun source",
                Func = function()
                        local status = h2o.SetRerunSource(SourceInput.Value)
                        SourceLabel:SetText(sourceStatus())
                        notify(status, 5)
                end,
        })

        Toggles.startup_rerun:OnChanged(function()
                h2o.StartupState.rerun = Toggles.startup_rerun.Value
                h2o.SaveStartupState()
                if Toggles.startup_rerun.Value then
                        if not h2o.QueueTeleport then
                                notify("executor does not support queue_on_teleport", 5)
                        elseif sourceStatus() == "rerun source: unavailable" then
                                notify("no rerun source - paste your script url or file path below", 6)
                        end
                end
        end)
        Toggles.startup_silent:OnChanged(function()
                h2o.StartupState.silent = Toggles.startup_silent.Value
                h2o.SaveStartupState()
                if Toggles.startup_silent.Value then
                        notify("menu will start hidden on next load", 4)
                end
        end)
        Options.startup_source:OnChanged(function()
                if Options.startup_source.Value == "" and (h2o.StartupState.path ~= "" or h2o.StartupState.url ~= "") then
                        h2o.SetRerunSource("")
                        SourceLabel:SetText(sourceStatus())
                        notify("rerun source cleared", 4)
                end
        end)
end

SaveManager:LoadAutoloadConfig()

if not h2o.StartupState.silent then
        Library:Notify({
                Title = h2o.Name,
                Description = "loaded - press RightShift to toggle the menu",
                Time = 4,
        })
end
