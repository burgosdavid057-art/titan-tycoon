--!strict
-- CombatController.luau — corte con espada (click izquierdo).
-- Raycast desde la cámara hacia el crosshair; si toca un titán, avisa al
-- servidor (que valida distancia/cooldown). Alterna animación izq/der.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AnimationController = require(script.Parent.AnimationController)

local C = Config.Combat

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local CombatController = {}

local lastSwing = 0
local swingLeft = true
local slashSound: Sound? = nil

-- número de daño flotante en el mundo
local function showDamageNumber(position: Vector3, damage: number, esNuca: boolean)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.1, 0.1, 0.1)
	holder.Position = position + Vector3.new(math.random(-2, 2), 1, math.random(-2, 2))
	holder.Parent = Workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 120, 0, 40)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = esNuca and 30 or 20
	label.TextColor3 = esNuca and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(255, 90, 70)
	label.TextStrokeTransparency = 0.4
	label.Text = esNuca and ("¡NUCA! " .. damage) or tostring(damage)
	label.Parent = gui
	gui.Parent = holder

	TweenService:Create(gui, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
		StudsOffset = Vector3.new(0, 5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.8), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(holder, 0.9)
end

local function trySlash()
	local now = os.clock()
	if now - lastSwing < C.Cooldown then
		return
	end
	lastSwing = now

	-- animación (alterna espada izq/der; IDs reales en fase 4)
	AnimationController.Play(swingLeft and "SlashLeft" or "SlashRight")
	swingLeft = not swingLeft

	-- sonido de corte siempre (feedback aunque no le des a nada)
	if slashSound then
		slashSound.PlaybackSpeed = 0.9 + math.random() * 0.25
		slashSound:Play()
	end

	local titansFolder = Workspace:FindFirstChild("Titans")
	if not titansFolder then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { titansFolder }

	local result = Workspace:Raycast(ray.Origin, ray.Direction * C.RayLength, params)
	if not result then
		return
	end

	local titanModel = result.Instance:FindFirstAncestorOfClass("Model")
	if titanModel then
		Remotes.MeleeHit:FireServer(titanModel, result.Instance.Name)
		-- feedback inmediato: número de daño en el punto del golpe
		local esNuca = result.Instance.Name == "Nuca"
		local damage = C.Damage * (esNuca and C.NapeMultiplier or 1)
		showDamageNumber(result.Position, damage, esNuca)
	end
end

function CombatController.Init()
	-- crosshair al centro (para saber a dónde apuntas gancho y espadas)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatGui"
	gui.ResetOnSpawn = false
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.new(0, 6, 0, 6)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = 0.2
	dot.BorderSizePixel = 0
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	dot.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	-- sonido de corte (espada clásica de Roblox, gratis)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://12222216"
	sound.Volume = 0.5
	sound.Parent = camera
	slashSound = sound

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			trySlash()
		end
	end)

	-- feedback en consola (fase 3 = UI real)
	Remotes.TitanKilled.OnClientEvent:Connect(function(typeId, recompensa)
		print(("[Combat] ¡%s eliminado! +%d monedas, +%d esencia"):format(
			tostring(typeId), recompensa.monedas, recompensa.esencia))
	end)
	Remotes.BossKilled.OnClientEvent:Connect(function(info)
		print(("[Combat] ¡JEFE eliminado! Nivel %d (%d/%d jefes para el siguiente)"):format(
			info.nivel, info.progreso, info.necesarios))
	end)
	Remotes.WaveStarted.OnClientEvent:Connect(function(wave, count, isBoss)
		print(("[Oleada %d] %d titanes%s"):format(wave, count, isBoss and " — ¡VIENE UN JEFE!" or ""))
	end)

	print("[CombatController] listo — click izquierdo para cortar (la nuca hace x" .. C.NapeMultiplier .. ")")
end

return CombatController
