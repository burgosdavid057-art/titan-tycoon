--!strict
-- WheelController.luau — UI de la rueda gacha (tecla R) + inventario de
-- compañeros con equipar/desequipar. La animación de giro es cosmética:
-- el resultado real ya viene decidido por el servidor.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local WheelController = {}

local COLOR_BG = Color3.fromRGB(22, 22, 28)
local COLOR_PANEL = Color3.fromRGB(30, 30, 38)
local COLOR_GOLD = Color3.fromRGB(235, 195, 90)
local COLOR_TEXT = Color3.fromRGB(235, 235, 235)

local gui: ScreenGui
local panel: Frame
local resultLabel: TextLabel
local spinBtn: TextButton
local pityLabel: TextLabel
local inventory: ScrollingFrame
local lastState: any = nil
local spinning = false

local function new(className: string, props: { [string]: any }, parent: Instance?): Instance
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(el: Instance, radius: number)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, el)
end

local function nombreDe(comp: any): (string, number)
	local pool = (Config.Companions.Pool :: any)[comp.rareza]
	if pool then
		for _, def in pool do
			if def.id == comp.id then
				return def.nombre, def.dps
			end
		end
	end
	return comp.id, 0
end

----------------------------------------------------------------
-- Inventario
----------------------------------------------------------------

local function refreshInventory()
	for _, child in inventory:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if not lastState then
		return
	end

	local equipped = 0
	for _, comp in lastState.companeros do
		if comp.equipado then
			equipped += 1
		end
	end

	pityLabel.Text = ("Pity: %d/%d   ·   Equipados: %d/%d"):format(
		lastState.pity, lastState.pityMax, equipped, lastState.maxEquipados)

	-- ordenar: equipados primero, luego por rareza descendente
	local rarityOrder: { [string]: number } = {}
	for i, r in Config.Rarities do
		rarityOrder[r.id] = i
	end
	local sorted: { any } = table.clone(lastState.companeros)
	table.sort(sorted, function(a, b)
		if a.equipado ~= b.equipado then
			return a.equipado
		end
		return (rarityOrder[a.rareza] or 0) > (rarityOrder[b.rareza] or 0)
	end)

	for _, comp in sorted do
		local rarity = Config.getRarity(comp.rareza)
		local color = rarity and rarity.color or COLOR_TEXT
		local nombre, dps = nombreDe(comp)

		local row = new("Frame", {
			Size = UDim2.new(1, -6, 0, 44),
			BackgroundColor3 = COLOR_PANEL,
			BorderSizePixel = 0,
		}, inventory) :: Frame
		corner(row, 6)

		new("TextLabel", {
			Position = UDim2.new(0, 8, 0, 4),
			Size = UDim2.new(1, -110, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = nombre,
		}, row)

		new("TextLabel", {
			Position = UDim2.new(0, 8, 0, 22),
			Size = UDim2.new(1, -110, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(170, 170, 180),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ((rarity and rarity.nombre) or comp.rareza) .. "  ·  " .. dps .. " DPS",
		}, row)

		local isEquip = not comp.equipado
		local btn = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 90, 0, 28),
			BackgroundColor3 = isEquip and COLOR_GOLD or Color3.fromRGB(90, 90, 100),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(20, 20, 20),
			Text = isEquip and "Equipar" or "Quitar",
			BorderSizePixel = 0,
		}, row) :: TextButton
		corner(btn, 6)
		btn.Activated:Connect(function()
			Remotes.CompanionAction:FireServer({
				action = isEquip and "equip" or "unequip",
				uid = comp.uid,
			})
		end)
	end

	inventory.CanvasSize = UDim2.new(0, 0, 0, #sorted * 48)
end

----------------------------------------------------------------
-- Giro
----------------------------------------------------------------

local function playSpinAnimation(result: any)
	spinning = true
	spinBtn.Text = "..."

	-- ciclo de colores de rareza acelerando hacia el resultado
	task.spawn(function()
		local steps = 18
		for i = 1, steps do
			local r = Config.Rarities[(i % #Config.Rarities) + 1]
			resultLabel.TextColor3 = r.color
			resultLabel.Text = r.nombre .. "..."
			task.wait(0.05 + (i / steps) ^ 2 * 0.15)
		end

		local rarity = Config.getRarity(result.rareza)
		resultLabel.TextColor3 = rarity and rarity.color or COLOR_TEXT
		resultLabel.Text = ("%s  (%s · %d DPS)"):format(result.nombre, (rarity and rarity.nombre) or result.rareza, result.dps)

		spinning = false
		spinBtn.Text = "GIRAR  ⛁" .. Config.Wheel.CostoTirada
	end)
end

----------------------------------------------------------------
-- Panel
----------------------------------------------------------------

local function buildPanel()
	panel = new("Frame", {
		Name = "WheelPanel",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(0, 330, 0, 460),
		BackgroundColor3 = COLOR_BG,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
	}, gui) :: Frame
	corner(panel, 12)

	new("TextLabel", {
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = COLOR_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "RUEDA DE COMPAÑEROS",
	}, panel)

	resultLabel = new("TextLabel", {
		Position = UDim2.new(0, 14, 0, 40),
		Size = UDim2.new(1, -28, 0, 34),
		BackgroundColor3 = COLOR_PANEL,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(150, 150, 160),
		Text = "Gira para conseguir un compañero",
	}, panel) :: TextLabel
	corner(resultLabel, 8)

	spinBtn = new("TextButton", {
		Position = UDim2.new(0, 14, 0, 82),
		Size = UDim2.new(1, -28, 0, 38),
		BackgroundColor3 = COLOR_GOLD,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(20, 20, 20),
		Text = "GIRAR  ⛁" .. Config.Wheel.CostoTirada,
		BorderSizePixel = 0,
	}, panel) :: TextButton
	corner(spinBtn, 8)
	spinBtn.Activated:Connect(function()
		if not spinning then
			Remotes.SpinWheel:FireServer()
		end
	end)

	pityLabel = new("TextLabel", {
		Position = UDim2.new(0, 14, 0, 124),
		Size = UDim2.new(1, -28, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(170, 170, 180),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, panel) :: TextLabel

	inventory = new("ScrollingFrame", {
		Position = UDim2.new(0, 14, 0, 146),
		Size = UDim2.new(1, -28, 1, -160),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
	}, panel) :: ScrollingFrame
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, inventory)

	-- botón flotante (abajo izquierda)
	local openBtn = new("TextButton", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(0, 130, 0, 40),
		BackgroundColor3 = COLOR_PANEL,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLOR_GOLD,
		Text = "Rueda  [R]",
		BorderSizePixel = 0,
	}, gui) :: TextButton
	corner(openBtn, 10)

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refreshInventory()
		end
	end
	openBtn.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.R then
			toggle()
		end
	end)
end

----------------------------------------------------------------

function WheelController.Init()
	gui = new("ScreenGui", {
		Name = "WheelGui",
		ResetOnSpawn = false,
	}, player:WaitForChild("PlayerGui")) :: ScreenGui

	buildPanel()

	Remotes.WheelResult.OnClientEvent:Connect(function(result)
		if result.error then
			resultLabel.TextColor3 = Color3.fromRGB(220, 90, 70)
			resultLabel.Text = result.error
			return
		end
		playSpinAnimation(result)
	end)

	Remotes.CompanionsUpdate.OnClientEvent:Connect(function(state)
		lastState = state
		if panel.Visible then
			refreshInventory()
		end
	end)

	print("[WheelController] listo — R abre la rueda")
end

return WheelController
