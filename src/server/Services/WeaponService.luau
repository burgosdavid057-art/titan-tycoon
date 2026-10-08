--!strict
-- WeaponService.luau — le pone las dos espadas de maniobras a cada jugador
-- al aparecer (parts soldados a las manos; los ven todos los jugadores).
-- En fase de assets se reemplazan por meshes reales sin tocar nada más.

local Players = game:GetService("Players")

local WeaponService = {}

local function makeBlade(hand: BasePart, side: number): ()
	-- hoja
	local blade = Instance.new("Part")
	blade.Name = "Espada"
	blade.Size = Vector3.new(0.22, 3.6, 0.5)
	blade.Color = Color3.fromRGB(215, 220, 230)
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = hand.CFrame * CFrame.new(side * 0.1, -2.4, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = blade
	weld.Parent = blade

	-- empuñadura
	local grip = Instance.new("Part")
	grip.Name = "Empunadura"
	grip.Size = Vector3.new(0.3, 0.9, 0.3)
	grip.Color = Color3.fromRGB(40, 40, 45)
	grip.Material = Enum.Material.SmoothPlastic
	grip.CanCollide = false
	grip.Massless = true
	grip.CFrame = hand.CFrame * CFrame.new(side * 0.1, -0.4, 0)

	local weld2 = Instance.new("WeldConstraint")
	weld2.Part0 = hand
	weld2.Part1 = grip
	weld2.Parent = grip

	blade.Parent = hand.Parent
	grip.Parent = hand.Parent
end

local function equip(char: Model)
	-- esperar a que el rig esté completo
	char:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.3)

	-- R15 usa RightHand/LeftHand; R6 usa Right Arm/Left Arm
	local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local leftHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
	if rightHand then
		makeBlade(rightHand :: BasePart, 1)
	end
	if leftHand then
		makeBlade(leftHand :: BasePart, -1)
	end
end

function WeaponService.Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			task.spawn(equip, char)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(char)
			task.spawn(equip, char)
		end)
		if player.Character then
			task.spawn(equip, player.Character)
		end
	end
	print("[WeaponService] listo — espadas dobles equipadas")
end

return WeaponService
