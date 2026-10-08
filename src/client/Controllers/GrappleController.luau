--!strict
-- GrappleController.luau — Mecánica central: gancho doble estilo equipo de maniobras.
--
-- Controles (estilo equipo de maniobras del anime):
--   Q            dispara/suelta gancho izquierdo (toggle)
--   E            dispara/suelta gancho derecho
--   *El gancho TE JALA SOLO hacia el punto de anclaje*
--   Shift        GAS: acelera fuerte hacia la cámara y recoge el cable x1.7
--   Espacio      suelta ambos ganchos (para salir volando con el impulso)
--   WASD         control aéreo mientras cuelgas
--
-- Física: SpringConstraint por gancho con FreeLength que se encoge solo
-- (atracción automática); VectorForce para gas y control aéreo.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local G = Config.Grapple

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local GrappleController = {}

type Hook = {
	anchorPart: Part,
	targetAtt: Attachment,
	spring: SpringConstraint,
	beam: Beam,
	rootAtt: Attachment,
}

local hooks: { [string]: Hook? } = { Left = nil, Right = nil }
local character: Model? = nil
local rootPart: BasePart? = nil
local humanoid: Humanoid? = nil
local moveForce: VectorForce? = nil

-- carpeta para los anclajes en el mundo
local anchorsFolder = Instance.new("Folder")
anchorsFolder.Name = "GrappleAnchors"
anchorsFolder.Parent = Workspace

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function anyHookActive(): boolean
	return hooks.Left ~= nil or hooks.Right ~= nil
end

local function setGrapplingAttribute()
	if character then
		character:SetAttribute("Grappling", anyHookActive())
	end
end

local function releaseHook(side: string)
	local hook = hooks[side]
	if not hook then
		return
	end
	hooks[side] = nil
	hook.spring:Destroy()
	hook.beam:Destroy()
	hook.targetAtt:Destroy()
	hook.anchorPart:Destroy()
	hook.rootAtt:Destroy()
	setGrapplingAttribute()
end

local function releaseAll()
	releaseHook("Left")
	releaseHook("Right")
end

local function fireHook(side: string)
	if not rootPart or not character or hooks[side] then
		return
	end

	-- raycast desde la cámara hacia donde apunta el mouse/centro
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, anchorsFolder }

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * G.MaxDistance, params)
	if not result then
		return -- nada a la vista dentro del alcance
	end

	-- punta del gancho visible en el punto de impacto
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor_" .. side
	anchor.Shape = Enum.PartType.Ball
	anchor.Size = Vector3.new(0.9, 0.9, 0.9)
	anchor.Position = result.Position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Color = Color3.fromRGB(255, 255, 255)
	anchor.Material = Enum.Material.Neon
	anchor.Parent = anchorsFolder

	local targetAtt = Instance.new("Attachment")
	targetAtt.Parent = anchor

	-- attachment en el torso, desplazado al hombro correspondiente
	local sideOffset = (side == "Left") and -0.9 or 0.9
	local rootAtt = Instance.new("Attachment")
	rootAtt.Name = "GrappleAtt_" .. side
	rootAtt.Position = Vector3.new(sideOffset, 0.6, 0)
	rootAtt.Parent = rootPart

	local dist = (result.Position - rootPart.Position).Magnitude

	local spring = Instance.new("SpringConstraint")
	spring.Attachment0 = rootAtt
	spring.Attachment1 = targetAtt
	spring.Stiffness = G.Stiffness
	spring.Damping = G.Damping
	spring.FreeLength = dist * 0.9 -- tenso al enganchar: arranca jalando ya
	spring.LimitsEnabled = false
	spring.Visible = false
	spring.Parent = rootPart

	-- cable visual
	local beam = Instance.new("Beam")
	beam.Attachment0 = rootAtt
	beam.Attachment1 = targetAtt
	beam.Color = ColorSequence.new(G.RopeColor)
	beam.Width0 = G.RopeWidth
	beam.Width1 = G.RopeWidth
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = rootPart

	hooks[side] = {
		anchorPart = anchor,
		targetAtt = targetAtt,
		spring = spring,
		beam = beam,
		rootAtt = rootAtt,
	}
	setGrapplingAttribute()

	-- pequeño salto de estado para despegar del suelo al engancharse
	if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

----------------------------------------------------------------
-- Loop de física: recoger cable, gas y control aéreo
----------------------------------------------------------------

local function onHeartbeat(dt: number)
	if not rootPart or not moveForce then
		return
	end

	-- atracción AUTOMÁTICA: el cable se encoge solo y te jala al anclaje
	-- (con gas/Shift, mucho más rápido — como en el anime)
	local reelMult = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and G.GasReelMult or 1
	for _, side in { "Left", "Right" } do
		local hook = hooks[side]
		if hook then
			hook.spring.FreeLength = math.max(G.MinLength, hook.spring.FreeLength - G.ReelSpeed * reelMult * dt)
		end
	end

	-- fuerzas acumuladas (gas + control aéreo)
	local totalForce = Vector3.zero

	if anyHookActive() then
		-- gas: Shift impulsa hacia donde mira la cámara
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			local lookDir = camera.CFrame.LookVector
			totalForce += (lookDir + Vector3.new(0, G.GasUpFactor, 0)).Unit * G.GasForce
		end

		-- control aéreo WASD relativo a la cámara
		local moveDir = Vector3.zero
		local camCF = camera.CFrame
		local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
		local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
		if flatLook.Magnitude > 0 then
			flatLook = flatLook.Unit
		end
		if flatRight.Magnitude > 0 then
			flatRight = flatRight.Unit
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDir += flatLook
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDir -= flatLook
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDir += flatRight
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDir -= flatRight
		end
		if moveDir.Magnitude > 0 then
			totalForce += moveDir.Unit * G.AirControlForce
		end
	end

	moveForce.Force = totalForce
end

----------------------------------------------------------------
-- Ciclo de vida del personaje
----------------------------------------------------------------

local function onCharacterAdded(char: Model)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid = char:WaitForChild("Humanoid") :: Humanoid

	-- attachment + fuerza para gas/control aéreo
	local att = Instance.new("Attachment")
	att.Name = "GrappleForceAtt"
	att.Parent = rootPart

	local vf = Instance.new("VectorForce")
	vf.Attachment0 = att
	vf.RelativeTo = Enum.ActuatorRelativeTo.World
	vf.Force = Vector3.zero
	vf.Parent = rootPart
	moveForce = vf

	if humanoid then
		humanoid.Died:Connect(releaseAll)
	end
end

local function onCharacterRemoving()
	releaseAll()
	character = nil
	rootPart = nil
	humanoid = nil
	moveForce = nil
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

function GrappleController.Init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q then
			-- toggle: disparar o soltar
			if hooks.Left then
				releaseHook("Left")
			else
				fireHook("Left")
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			if hooks.Right then
				releaseHook("Right")
			else
				fireHook("Right")
			end
		elseif input.KeyCode == Enum.KeyCode.Space then
			-- soltar todo: sales disparado con el impulso que llevas
			if anyHookActive() then
				releaseAll()
			end
		end
	end)

	RunService.Heartbeat:Connect(onHeartbeat)

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	print("[GrappleController] listo — Q/E ganchos (auto-jalan), Shift gas, Espacio soltar")
end

return GrappleController
