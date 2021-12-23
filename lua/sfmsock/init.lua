/*
	SFM SOCK Websocket Client for Garry's Mod
	This software is licensed under the MIT License.
	Copyright (c) 2021 KiwifruitDev

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

require("gwsockets") -- https://github.com/FredyH/GWSockets

CreateConVar("sfmsock_restrict", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Restricts SFM SOCK to super admins only.")
CreateConVar("sfmsock_ip", "ws://localhost:9090/", {FCVAR_PROTECTED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "The IP address to connect to.")

util.AddNetworkString("SFMSOCK_GetBoneData")
util.AddNetworkString("SFMSOCK_ResetBones")

local MODEL_REPLACEMENTS = {
	-- [modelname] = replacementmodel
}

concommand.Add("sfmsock_connect", function(ply, cmd, args)
	if not IsValid(ply) then return end
	if GetConVar("sfmsock_restrict"):GetBool() and not ply:IsSuperAdmin() then return end
	ply:PrintMessage(HUD_PRINTCONSOLE, "Connecting to SFM SOCK...")
	SFMSOCK_ConnectWSS(GetConVar("sfmsock_ip"):GetString(), ply, args[1] == "force")
end, nil, "Connect to an SFM SOCK websocket server.", FCVAR_REPLICATED)

concommand.Add("sfmsock_flip", function(ply, cmd, args)
	if not IsValid(ply) then return end
	ply:SetNWBool("sfmsock_flipped", not ply:GetNWBool("sfmsock_flipped"))
	if ply:GetNWBool("sfmsock_flipped") then
		ply:SetViewEntity(SFMSOCK_CAMERA)
		ply:SetFOV(SFMSOCK_FOV or 100)
	else
		ply:SetViewEntity(ply)
		ply:SetFOV(100)
	end
end, nil, "Flip between camera view and game view.", FCVAR_REPLICATED)

SFMSOCK_FRAME = SFMSOCK_FRAME or {}
SFMSOCK_WSS = SFMSOCK_WSS or nil

function QuaternionToAngles(r, i, j, k)
	local pitch, yaw, roll

	local sinr_cosp = 2 * (r*i + j*k)
	local cosr_cosp = 1 - 2 * (i*i + j*j)
	roll = math.atan2(sinr_cosp, cosr_cosp)

	local sinp = 2 * (r*j - k*i)

	if math.abs(sinp) >= 1 then
		if sinp >= 0 then
			pitch = 90
		else
			pitch = -90
		end
	else
		pitch = math.deg(math.asin(sinp))
	end

	local siny_cosp = 2 * (r*k + i*j)
	local cosy_cosp = 1 - 2 * (j*j + k*k)
	yaw = math.atan2(siny_cosp, cosy_cosp)

	return Angle(pitch, math.deg(yaw), math.deg(roll))
end

SFMSOCK_DAGS = SFMSOCK_DAGS or {}
SFMSOCK_BONEDATA = SFMSOCK_BONEDATA or {}
SFMSOCK_BONEDATA_ENTS = SFMSOCK_BONEDATA_ENTS or {}

local bonestoignore = {
	-- fingers are currently not supported
	//"thumb",
	//"middle",
	//"ring",
	//"pinky",
	//"index",
}

local function ShouldIngoreBone(bone)
	for _, ignore in pairs(bonestoignore) do
		if string.find(bone, ignore) then
			return true
		end
	end
	return false
end

function SFMSOCK_ParseBones(children, dag, parentmatrix, bonetable, isroot)
	for _, bone in pairs(children) do
		-- viewtarget check
		if bone.name == "viewTarget" then
			dag:SetEyeTarget(LocalToWorld(Vector(bone.transform.position.x, bone.transform.position.y, bone.transform.position.z), Angle(0,0,0), dag:GetPos(), dag:GetAngles()))
			continue
		end
		local childtable = {}
		-- this is odd, the last character is always a right parenthesis and the first character of the actual name is a left parenthesis but there is a fake name before the parenthesis
		-- we only want the actual name, so let's avoid the fake name
		-- remove everything before the first left parenthesis including the left parenthesis
		local found = string.find(bone.name, "%(")
		if not found then continue end -- this should not happen
		childtable.name = bone.name:sub(found + 1)
		-- remove everything after the last right parenthesis including the right parenthesis
		childtable.name = childtable.name:sub(1, string.find(childtable.name, "%)") - 1)
		if not ShouldIngoreBone(childtable.name) then
			matrixpos = Matrix()
			matrixpos:SetTranslation(Vector(bone.transform.position.x, bone.transform.position.y, bone.transform.position.z))
			local ang = QuaternionToAngles(bone.transform.orientation.w, bone.transform.orientation.x, bone.transform.orientation.y, bone.transform.orientation.z)
			matrixpos:Rotate(ang)
			childtable.matrix = parentmatrix * matrixpos
			if isroot then -- offset by position, can't set this bone directly
				dag:SetPos(childtable.matrix:GetTranslation())
				-- angles must be offset from dag:GetAngles
				dag:SetAngles(childtable.matrix:GetAngles() - dag:GetAngles() - ang)
			end
			table.insert(bonetable, childtable)
			if bone.children ~= nil then
				SFMSOCK_ParseBones(bone.children, dag, childtable.matrix, bonetable, false)
			end
		end
	end
	return bonetable
end

function SFMSOCK_UpdateFrame()
	if not IsValid(SFMSOCK_CAMERA) then
		SFMSOCK_CAMERA = ents.Create("prop_dynamic")
	end
	-- main camera
	local camera = SFMSOCK_FRAME.filmClip.camera
	if camera then
		SFMSOCK_CAMERA:SetModel("models/dav0r/camera.mdl")
		SFMSOCK_FOV = camera.fieldOfView
		SFMSOCK_CAMERA:SetPos(Vector(camera.transform.position.x, camera.transform.position.y, camera.transform.position.z))
		-- problem with rotation is that it uses quanternions, so let's convert them into qangles
		SFMSOCK_CAMERA:SetAngles(QuaternionToAngles(camera.transform.orientation.w, camera.transform.orientation.x, camera.transform.orientation.y, camera.transform.orientation.z))
		for _, ply in pairs(player.GetAll()) do
			if ply:GetNWBool("sfmsock_flipped") then
				ply:SetViewEntity(SFMSOCK_CAMERA)
				ply:SetFOV(camera.fieldOfView)
			else
				ply:SetViewEntity(ply)
			end
		end
	end
	local used_ent_indexes = {}
	if SFMSOCK_FRAME.filmClip.animationSets then
		for k, v in pairs(SFMSOCK_FRAME.filmClip.animationSets) do
			if v.gameModel then
				if not IsValid(SFMSOCK_DAGS[k]) then
					SFMSOCK_DAGS[k] = ents.Create("generic_actor")
				end
				local dag = SFMSOCK_DAGS[k]
				table.insert(used_ent_indexes, dag:EntIndex())
				if not v.gameModel.visible then
					dag:SetPos(Vector(0,0,0))
					dag:SetNoDraw(true)
					continue
				end
				dag:SetNoDraw(false)
				-- this dag is a model
				local model = Model(v.gameModel.modelName)
				if MODEL_REPLACEMENTS[model] then
					if util.IsValidModel(MODEL_REPLACEMENTS[model]) then
						model = MODEL_REPLACEMENTS[model]
					end
				end
				if not util.IsValidModel(model) then
					model = "models/error.mdl"
				end
				dag:SetModel(model)
				dag:SetPos(Vector(v.gameModel.transform.position.x, v.gameModel.transform.position.y, v.gameModel.transform.position.z))
				dag:SetAngles(QuaternionToAngles(v.gameModel.transform.orientation.w, v.gameModel.transform.orientation.x, v.gameModel.transform.orientation.y, v.gameModel.transform.orientation.z))
				-- TODO: figure out how bodygroups (v.gameModel.body) are calculated and apply them here
				dag:SetSkin(v.gameModel.skin)
				-- transmit
				if v.gameModel.children ~= nil then
					net.Start("SFMSOCK_GetBoneData")
						local bones = SFMSOCK_ParseBones(v.gameModel.children, dag, dag:GetWorldTransformMatrix(), {}, true)
						net.WriteEntity(dag)
						if bones then
							net.WriteTable(bones)
						else
							net.WriteUInt(0, 8) -- ???
							print("No bones found for " .. ent:GetModel())
						end
					net.Broadcast()
				end
				-- flexes :)
				if v.gameModel.globalFlexControllers then
					print("Building flexes for " .. v.gameModel.modelName)
					for k2, v2 in pairs(v.gameModel.globalFlexControllers) do
						local flex = dag:GetFlexIDByName(v2.name)
						if flex then
							dag:SetFlexWeight(flex, v2.flexWeight)
						else
							print("Flex " .. v2.name .. " not found in " .. v.gameModel.modelName)
						end
					end
				end
			end
		end
	end
	for k, v in pairs(SFMSOCK_DAGS) do
		if not v:IsValid() or not table.HasValue(used_ent_indexes, v:EntIndex()) then
			SFMSOCK_DAGS[k]:Remove()
			SFMSOCK_DAGS[k] = nil
		end
	end
	print("Frame complete")
end

local tcp_combo = ""
local received_first = false

function SFMSOCK_TryJson()
	print("Recieved data, trying to parse as json")
	local tryjson = util.JSONToTable(tcp_combo) or false
	if tryjson ~= false then
		-- we have a complete JSON packet
		if tryjson.type == "framedata" then
			print("Got frame data")
			SFMSOCK_FRAME = tryjson
			SFMSOCK_UpdateFrame()
			tcp_combo = ""
			received_first = false
		else
			print("Got unknown data type")
			tcp_combo = ""
			received_first = false
		end
	end
end

function SFMSOCK_ConnectWSS(url, ply, force)
	if not url or url == "" then
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "SFM SOCK URL is empty, tell the server owner to set it via 'sfmsock_ip' and try again.")
		end
		print("Attempted to connect to SFM SOCK with an empty URL, set the URL via 'sfmsock_ip' and try again.")
	elseif SFMSOCK_WSS and not force and IsValid(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "SFM SOCK is already connected, try again with 'sfmsock_connect force' if there was a problem.")
	else
		SFMSOCK_WSS = GWSockets.createWebSocket(url, false)
		function SFMSOCK_WSS:onMessage(msg)
			-- we need to recieve multiple TCP packets
			if received_first then
				print("Recieved more data, concatenating")
				tcp_combo = tcp_combo .. msg
				SFMSOCK_TryJson()
			elseif string.StartWith(msg, "{") then
				tcp_combo = msg
				received_first = true
				SFMSOCK_TryJson()
			end
		end
		function SFMSOCK_WSS:onError(errMessage)
			print("SFM SOCK ERROR: " .. errMessage)
		end
		function SFMSOCK_WSS:onConnected()
			print("SFM SOCK CONNECTED")
		end
		function SFMSOCK_WSS:onDisconnected()
			print("SFM SOCK DISCONNECTED")
		end
		SFMSOCK_WSS:open()
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "Connected to SFM SOCK.")
		end
	end
end

-- flip views
hook.Add("ShowSpare1", "Flipper", function(ply)
	ply:ConCommand("sfmsock_flip")
end)
