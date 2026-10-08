--!strict
-- UIController.luau — HUD construido por código (sin assets de Studio):
--   · Monedas / Esencia / Nivel con barra de progreso de jefes
--   · Banner de oleadas y toasts de recompensa
--   · Panel de aldea (tecla B): comprar/mejorar edificios, muro, reparar
-- Estilo oscuro con acentos dorado (monedas) y morado (esencia).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local UIController = {}

local COLOR_BG = Color3.fromRGB(22, 22, 28)
local COLOR_PANEL = Color3.fromRGB(30, 30, 38)
local COLOR_GOLD = Color3.fromRGB(235, 195, 90)
local COLOR_PURPLE = Color3.fromRGB(185, 110, 255)
local COLOR_TEXT = Color3.fromRGB(235, 235, 235)
local COLOR_GREEN = Color3.fromRGB(100, 200, 90)
local COLOR_RED = Color3.fromRGB(220, 90, 70)

----------------------------------------------------------------
-- Helpers de construcción
----------------------------------------------------------------

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

local function fmt(n: number): string
	if n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 10_000 then
		return string.format("%.1fk", n / 1_000)
	end
	return tostring(n)
end

local function bindAttr(attr: string, fn: (value: any) -> ())
	fn(player:GetAttribute(attr))
	player:GetAttributeChangedSignal(attr):Connect(function()
		fn(player:GetAttribute(attr))
	end)
end

----------------------------------------------------------------
-- Estado
----------------------------------------------------------------

local gui: ScreenGui
local villagePanel: Frame
local villageContent: Frame
local lastVillageState: any = nil

----------------------------------------------------------------
-- HUD superior
----------------------------------------------------------------

local function buildHUD()
	-- monedas + esencia (arriba derecha)
	local currencies = new("Frame", {
		Name = "Currencies",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.new(0, 190, 0, 74),
		BackgroundColor3 = COLOR_BG,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, gui) :: Frame
	corner(currencies, 10)

	local monedasLabel = new("TextLabel", {
		Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = COLOR_GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "⛁ 0",
	}, currencies) :: TextLabel

	local esenciaLabel = new("TextLabel", {
		Position = UDim2.new(0, 12, 0, 38),
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextColor3 = COLOR_PURPLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "◆ 0",
	}, currencies) :: TextLabel

	bindAttr("Monedas", function(v)
		monedasLabel.Text = "⛁ " .. fmt(tonumber(v) or 0)
	end)
	bindAttr("Esencia", function(v)
		esenciaLabel.Text = "◆ " .. fmt(tonumber(v) or 0)
	end)

	-- nivel + progreso de jefes (arriba centro)
	local levelFrame = new("Frame", {
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 280, 0, 52),
		BackgroundColor3 = COLOR_BG,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, gui) :: Frame
	corner(levelFrame, 10)

	local levelLabel = new("TextLabel", {
		Position = UDim2.new(0, 12, 0, 4),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = COLOR_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Nivel 1",
	}, levelFrame) :: TextLabel

	local barBg = new("Frame", {
		Position = UDim2.new(0, 12, 0, 30),
		Size = UDim2.new(1, -24, 0, 12),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
		BorderSizePixel = 0,
	}, levelFrame) :: Frame
	corner(barBg, 6)

	local barFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLOR_RED,
		BorderSizePixel = 0,
	}, barBg) :: Frame
	corner(barFill, 6)

	local function refreshLevel()
		local nivel = tonumber(player:GetAttribute("Nivel")) or 1
		local prog = tonumber(player:GetAttribute("JefesProgreso")) or 0
		local need = tonumber(player:GetAttribute("JefesNecesarios")) or 1
		levelLabel.Text = ("Nivel %d   ·   Jefes %d/%d"):format(nivel, prog, need)
		barFill.Size = UDim2.fromScale(math.clamp(prog / math.max(need, 1), 0, 1), 1)
	end
	bindAttr("Nivel", refreshLevel)
	bindAttr("JefesProgreso", refreshLevel)
	bindAttr("JefesNecesarios", refreshLevel)
end

----------------------------------------------------------------
-- Banner de oleada + toasts
----------------------------------------------------------------

local function showBanner(text: string, color: Color3, duration: number)
	local banner = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Size = UDim2.new(0, 500, 0, 44),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = color,
		TextStrokeTransparency = 0.5,
		Text = text,
	}, gui) :: TextLabel

	task.delay(duration, function()
		local tween = TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		banner:Destroy()
	end)
end

local toastOffset = 0
local function showToast(text: string, color: Color3)
	toastOffset += 1
	local myOffset = toastOffset
	local toast = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 94 + (myOffset % 5) * 26),
		Size = UDim2.new(0, 220, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = color,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = text,
	}, gui) :: TextLabel

	local tween = TweenService:Create(toast, TweenInfo.new(1.6, Enum.EasingStyle.Quad), {
		Position = toast.Position + UDim2.new(0, 0, 0, -18),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		toast:Destroy()
	end)
end

----------------------------------------------------------------
-- Eventos + Rebirth
----------------------------------------------------------------

local eventLabel: TextLabel? = nil
local eventEndsAt = 0

local function buildEventBar()
	local label = new("TextLabel", {
		Name = "EventBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.new(0, 420, 0, 24),
		BackgroundColor3 = Color3.fromRGB(90, 25, 25),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 160, 140),
		Text = "",
		Visible = false,
	}, gui) :: TextLabel
	corner(label, 8)
	eventLabel = label

	-- countdown
	task.spawn(function()
		while true do
			task.wait(1)
			if label.Visible then
				local remaining = eventEndsAt - os.clock()
				if remaining <= 0 then
					label.Visible = false
				else
					local base = label:GetAttribute("BaseText")
					label.Text = ("%s   ·   %d:%02d"):format(
						tostring(base), math.floor(remaining / 60), math.floor(remaining % 60))
				end
			end
		end
	end)
end

local function buildHelpPanel()
	local help = new("Frame", {
		Name = "HelpPanel",
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 250, 0, 205),
		BackgroundColor3 = COLOR_BG,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, gui) :: Frame
	corner(help, 10)

	new("TextLabel", {
		Position = UDim2.new(0, 12, 0, 6),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextColor3 = COLOR_GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "CONTROLES · v0.7",
	}, help)

	local lines = {
		"Q / E — Disparar ganchos (te jalan solos)",
		"Shift — GAS: acelera + recoge cable",
		"Espacio — Soltar ganchos (salir volando)",
		"Click — Cortar (la NUCA roja hace x8)",
		"WASD — Dirigirte en el aire",
		"B — Aldea   ·   R — Rueda",
		"H — Mostrar/ocultar esta ayuda",
	}
	for i, line in lines do
		new("TextLabel", {
			Position = UDim2.new(0, 12, 0, 26 + i * 24),
			Size = UDim2.new(1, -24, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = COLOR_TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = line,
		}, help)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.H then
			help.Visible = not help.Visible
		end
	end)
end

local function buildRebirthButton()
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0, 250, 0, 40),
		BackgroundColor3 = COLOR_PANEL,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = COLOR_TEXT,
		Text = "",
		BorderSizePixel = 0,
	}, gui) :: TextButton
	corner(btn, 10)

	local function refresh()
		local nivel = tonumber(player:GetAttribute("Nivel")) or 1
		local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0
		local required = Config.Rebirth.NivelMinimo + rebirths * Config.Rebirth.IncrementoPorRebirth
		local nextMult = 1 + (rebirths + 1) * Config.Rebirth.MultiplicadorPorRebirth
		local ready = nivel >= required
		btn.Text = ready
			and ("★ RENACER → x%.2f recompensas"):format(nextMult)
			or ("Renacer: requiere Nv.%d (vas Nv.%d)"):format(required, nivel)
		btn.BackgroundColor3 = ready and COLOR_GOLD or COLOR_PANEL
		btn.TextColor3 = ready and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(150, 150, 160)
	end
	bindAttr("Nivel", refresh)
	bindAttr("Rebirths", refresh)

	btn.Activated:Connect(function()
		Remotes.Rebirth:FireServer()
	end)
end

----------------------------------------------------------------
-- Panel de aldea
----------------------------------------------------------------

local function actionButton(text: string, color: Color3, parent: Instance, onClick: () -> ()): TextButton
	local btn = new("TextButton", {
		Size = UDim2.new(0, 120, 0, 26),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(20, 20, 20),
		Text = text,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}, parent) :: TextButton
	corner(btn, 6)
	btn.Activated:Connect(onClick)
	return btn
end

local function refreshVillagePanel()
	-- limpiar filas anteriores
	for _, child in villageContent:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local state = lastVillageState
	if not state then
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = COLOR_TEXT,
			Text = "Cargando aldea...",
		}, villageContent)
		return
	end

	-- ── fila del muro ──
	local wallRow = new("Frame", {
		Size = UDim2.new(1, 0, 0, 86),
		BackgroundColor3 = COLOR_PANEL,
		BorderSizePixel = 0,
	}, villageContent) :: Frame
	corner(wallRow, 8)

	new("TextLabel", {
		Position = UDim2.new(0, 10, 0, 6),
		Size = UDim2.new(1, -20, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = state.muroRoto and COLOR_RED or COLOR_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ("Muro  Nv.%d%s"):format(state.muroNivel, state.muroRoto and "  — ¡DESTRUIDO!" or ""),
	}, wallRow)

	local hpBg = new("Frame", {
		Position = UDim2.new(0, 10, 0, 30),
		Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = Color3.fromRGB(50, 50, 60),
		BorderSizePixel = 0,
	}, wallRow) :: Frame
	corner(hpBg, 5)
	local ratio = state.muroVidaMax > 0 and state.muroVida / state.muroVidaMax or 0
	local hpFill = new("Frame", {
		Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1),
		BackgroundColor3 = ratio > 0.4 and COLOR_GREEN or COLOR_RED,
		BorderSizePixel = 0,
	}, hpBg) :: Frame
	corner(hpFill, 5)

	new("TextLabel", {
		Position = UDim2.new(0, 10, 0, 42),
		Size = UDim2.new(1, -20, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = COLOR_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ("%d / %d"):format(state.muroVida, state.muroVidaMax),
	}, wallRow)

	local btnX = 10
	if state.muroCosto then
		local b = actionButton("Mejorar  ⛁" .. fmt(state.muroCosto), COLOR_GOLD, wallRow, function()
			Remotes.VillageAction:FireServer({ action = "upgradeWall" })
		end)
		b.Position = UDim2.new(0, btnX, 0, 56)
		btnX += 128
	end
	if state.repararCosto and state.repararCosto > 0 then
		local b = actionButton("Reparar  ⛁" .. fmt(state.repararCosto), COLOR_GREEN, wallRow, function()
			Remotes.VillageAction:FireServer({ action = "repair" })
		end)
		b.Position = UDim2.new(0, btnX, 0, 56)
	end

	-- ── filas de edificios ──
	for _, e in Config.Village.Edificios do
		local nivel = state.edificios[e.id] or 0
		local cost = state.costos.edificios[e.id]

		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundColor3 = COLOR_PANEL,
			BorderSizePixel = 0,
		}, villageContent) :: Frame
		corner(row, 8)

		local desc: string
		if e.produce == "Monedas" then
			desc = ("+%d ⛁/s"):format(e.baseRate * math.max(nivel, 1))
		elseif e.produce == "Esencia" then
			desc = ("+%d ◆/min"):format(e.baseRate * math.max(nivel, 1))
		else
			desc = ("-%d%% daño al muro"):format(math.min(math.max(nivel, 1) * Config.Village.CuartelReduccion * 100, 50))
		end

		new("TextLabel", {
			Position = UDim2.new(0, 10, 0, 6),
			Size = UDim2.new(1, -20, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = COLOR_TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = ("%s  Nv.%d"):format(e.nombre, nivel),
		}, row)

		new("TextLabel", {
			Position = UDim2.new(0, 10, 0, 24),
			Size = UDim2.new(0.5, 0, 0, 14),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(170, 170, 180),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = (nivel > 0 and "" or "produce: ") .. desc,
		}, row)

		if cost then
			local label = nivel == 0 and "Construir" or "Mejorar"
			local b = actionButton(("%s  ⛁%s"):format(label, fmt(cost)), COLOR_GOLD, row, function()
				Remotes.VillageAction:FireServer({ action = "buy", id = e.id })
			end)
			b.Position = UDim2.new(1, -130, 0, 30)
		else
			new("TextLabel", {
				Position = UDim2.new(1, -130, 0, 30),
				Size = UDim2.new(0, 120, 0, 26),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextColor3 = COLOR_GREEN,
				Text = "MÁXIMO",
			}, row)
		end
	end
end

local function buildVillagePanel()
	villagePanel = new("Frame", {
		Name = "VillagePanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 320, 0, 420),
		BackgroundColor3 = COLOR_BG,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Visible = false,
	}, gui) :: Frame
	corner(villagePanel, 12)

	new("TextLabel", {
		Position = UDim2.new(0, 14, 0, 8),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextColor3 = COLOR_TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "TU ALDEA",
	}, villagePanel)

	villageContent = new("Frame", {
		Position = UDim2.new(0, 10, 0, 40),
		Size = UDim2.new(1, -20, 1, -50),
		BackgroundTransparency = 1,
	}, villagePanel) :: Frame
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, villageContent)

	-- botón flotante para abrir (abajo derecha)
	local openBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.new(0, 130, 0, 40),
		BackgroundColor3 = COLOR_PANEL,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLOR_TEXT,
		Text = "Aldea  [B]",
		BorderSizePixel = 0,
	}, gui) :: TextButton
	corner(openBtn, 10)

	local function toggle()
		villagePanel.Visible = not villagePanel.Visible
		if villagePanel.Visible then
			Remotes.VillageAction:FireServer({ action = "get" })
			refreshVillagePanel()
		end
	end
	openBtn.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.B then
			toggle()
		end
	end)
end

----------------------------------------------------------------
-- Init
----------------------------------------------------------------

function UIController.Init()
	gui = new("ScreenGui", {
		Name = "TitanHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
	}, player:WaitForChild("PlayerGui")) :: ScreenGui

	buildHUD()
	buildVillagePanel()
	buildEventBar()
	buildRebirthButton()
	buildHelpPanel()

	Remotes.EventStarted.OnClientEvent:Connect(function(info)
		showBanner(("⚠ %s — ¡BOTÍN x%d!"):format(info.nombre, info.multiplicador), COLOR_RED, 5)
		local label = eventLabel
		if label then
			eventEndsAt = os.clock() + info.duracion
			label:SetAttribute("BaseText", ("⚠ %s  (x%d)"):format(info.nombre, info.multiplicador))
			label.Text = ("⚠ %s  (x%d)"):format(info.nombre, info.multiplicador)
			label.Visible = true
		end
	end)

	-- banner al renacer (solo en cambios, no al cargar)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0
		if rebirths > 0 then
			local mult = 1 + rebirths * Config.Rebirth.MultiplicadorPorRebirth
			showBanner(("★ ¡RENACIDO!  x%.2f recompensas permanentes ★"):format(mult), COLOR_GOLD, 5)
		end
	end)

	Remotes.WaveStarted.OnClientEvent:Connect(function(wave, count, isBoss)
		if isBoss then
			showBanner(("OLEADA %d — ¡JEFE A LA VISTA!"):format(wave), COLOR_RED, 4)
		else
			showBanner(("OLEADA %d — %d titanes"):format(wave, count), COLOR_TEXT, 2.5)
		end
	end)

	Remotes.TitanKilled.OnClientEvent:Connect(function(_typeId, recompensa)
		showToast("+" .. recompensa.monedas .. " ⛁", COLOR_GOLD)
		if recompensa.esencia > 0 then
			showToast("+" .. recompensa.esencia .. " ◆", COLOR_PURPLE)
		end
	end)

	Remotes.BossKilled.OnClientEvent:Connect(function(info)
		showBanner(("¡JEFE ELIMINADO!  Nivel %d"):format(info.nivel), COLOR_GOLD, 3.5)
	end)

	local muroEstabaRoto = false
	Remotes.VillageUpdate.OnClientEvent:Connect(function(state)
		lastVillageState = state
		if villagePanel.Visible then
			refreshVillagePanel()
		end
		-- solo avisar en la transición intacto -> roto
		if state.muroRoto and not muroEstabaRoto then
			showBanner("¡TU MURO FUE DESTRUIDO!", COLOR_RED, 3)
		end
		muroEstabaRoto = state.muroRoto
	end)

	print("[UIController] listo — B abre el panel de aldea")
end

return UIController
