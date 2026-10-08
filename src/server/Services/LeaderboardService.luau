--!strict
-- LeaderboardService.luau — Leaderboard GLOBAL (entre servidores) con
-- OrderedDataStore + tablero físico en la plaza central.
-- Puntaje = Rebirths * 1000 + Nivel (así el rebirth siempre pesa más).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)

local STORE_NAME = "GlobalRanking_v1"
local UPDATE_INTERVAL = 60
local TOP_N = 10

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local nameCache: { [number]: string } = {}
local rowLabels: { TextLabel } = {}

----------------------------------------------------------------
-- Tablero físico
----------------------------------------------------------------

local function buildBoard()
	local board = Instance.new("Part")
	board.Name = "Leaderboard"
	board.Size = Vector3.new(26, 16, 2)
	board.Position = Vector3.new(0, 8, 48)
	board.Anchored = true
	board.Color = Color3.fromRGB(35, 35, 42)
	board.Material = Enum.Material.SmoothPlastic

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(650, 400)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 52)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 34
	title.TextColor3 = Color3.fromRGB(235, 195, 90)
	title.Text = "★ MEJORES CAZADORES ★"
	title.Parent = gui

	for i = 1, TOP_N do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -40, 0, 32)
		row.Position = UDim2.new(0, 20, 0, 52 + (i - 1) * 33)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextSize = 22
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and Color3.fromRGB(235, 195, 90) or Color3.fromRGB(220, 220, 220)
		row.Text = i .. ".  —"
		row.Parent = gui
		table.insert(rowLabels, row)
	end

	gui.Parent = board
	board.Parent = Workspace
end

----------------------------------------------------------------
-- Actualización
----------------------------------------------------------------

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local result = ok and name or ("Usuario " .. userId)
	nameCache[userId] = result
	return result
end

local function updateLoop()
	while true do
		local s = store
		if s then
			-- subir el puntaje de los jugadores conectados
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile then
					local score = profile.Rebirths * 1000 + profile.Nivel
					pcall(function()
						s:SetAsync(tostring(player.UserId), score)
					end)
				end
			end

			-- leer el top global
			local ok, pages = pcall(function()
				return s:GetSortedAsync(false, TOP_N)
			end)
			if ok and pages then
				local top = (pages :: DataStorePages):GetCurrentPage()
				for i = 1, TOP_N do
					local entry = top[i]
					local label = rowLabels[i]
					if entry and label then
						local userId = tonumber(entry.key) or 0
						local score = entry.value :: number
						local rebirths = math.floor(score / 1000)
						local nivel = score % 1000
						label.Text = ("%d.  %s   —   R%d · Nv.%d"):format(i, getName(userId), rebirths, nivel)
					elseif label then
						label.Text = i .. ".  —"
					end
				end
			end
		end
		task.wait(UPDATE_INTERVAL)
	end
end

----------------------------------------------------------------

function LeaderboardService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_NAME)
	end)
	store = ok and result or nil
	if not store then
		warn("[LeaderboardService] Sin acceso a DataStores (¿juego no publicado?) — tablero en modo local")
	end

	buildBoard()
	task.spawn(updateLoop)
	print("[LeaderboardService] listo — actualiza cada " .. UPDATE_INTERVAL .. "s")
end

return LeaderboardService
