--!strict
-- AnimationController.luau — reproduce animaciones según el estado del personaje.
-- Los IDs viven en Config.Animations; mientras estén en "rbxassetid://0" no hace
-- nada (fase 4 = subir animaciones reales a Roblox y pegar los IDs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local AnimationController = {}

local tracks: { [string]: AnimationTrack } = {}
local animator: Animator? = nil

local function hasRealId(id: string): boolean
	return id ~= "" and id ~= "rbxassetid://0"
end

local function loadTracks(char: Model)
	tracks = {}
	local humanoid = char:WaitForChild("Humanoid") :: Humanoid
	animator = humanoid:WaitForChild("Animator") :: Animator

	for name, id in Config.Animations :: { [string]: string } do
		if hasRealId(id) then
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local track = (animator :: Animator):LoadAnimation(anim)
			tracks[name] = track
		end
	end
end

function AnimationController.Play(name: string, fade: number?)
	local track = tracks[name]
	if track and not track.IsPlaying then
		track:Play(fade or 0.15)
	end
end

function AnimationController.Stop(name: string, fade: number?)
	local track = tracks[name]
	if track and track.IsPlaying then
		track:Stop(fade or 0.15)
	end
end

function AnimationController.Init()
	local function onCharacter(char: Model)
		loadTracks(char)

		-- reacciona al atributo que setea GrappleController
		char:GetAttributeChangedSignal("Grappling"):Connect(function()
			if char:GetAttribute("Grappling") then
				AnimationController.Play("GrappleSwing")
			else
				AnimationController.Stop("GrappleSwing")
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return AnimationController
