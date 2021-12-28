/*
	SFM Bridge for Garry's Mod
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

CreateConVar("sfm_bridge_restrict", "1", {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Restricts SFM Bridge to super admins only.")
CreateConVar("sfm_bridge_ip", "ws://localhost:9090/", {FCVAR_PROTECTED, FCVAR_ARCHIVE}, "The IP address to connect to.")
local debug = CreateConVar("sfm_bridge_debug", "0", {FCVAR_REPLICATED, FCVAR_ARCHIVE}, "Enables debug messages.")

util.AddNetworkString("SFM_BRIDGE_GetBoneData")
util.AddNetworkString("SFM_BRIDGE_StopBoneData")
util.AddNetworkString("SFM_BRIDGE_SetupLight")
util.AddNetworkString("SFM_BRIDGE_PlayBoneData")
util.AddNetworkString("SFM_BRIDGE_StopBoneDataMovie")
util.AddNetworkString("SFM_BRIDGE_PauseBoneData")
util.AddNetworkString("SFM_BRIDGE_ResumeBoneData")
util.AddNetworkString("SFM_BRIDGE_GoToBoneData")
util.AddNetworkString("SFM_BRIDGE_ClearBoneData")
util.AddNetworkString("SFM_BRIDGE_MovieFrame")

local function printdebug(...)
	if debug:GetBool() then
		print(...)
	end
end

local MODEL_REPLACEMENTS = {
	-- [modelname] = replacementmodel
}

concommand.Add("sfm_bridge_connect", function(ply, cmd, args)
	if not IsValid(ply) then return end
	if GetConVar("sfm_bridge_restrict"):GetBool() and not ply:IsSuperAdmin() then return end
	ply:PrintMessage(HUD_PRINTCONSOLE, "Connecting to SFM Bridge...")
	SFM_BRIDGE_ConnectWSS(GetConVar("sfm_bridge_ip"):GetString(), ply, args[1] == "force")
end, nil, "Connect to an SFM Bridge websocket server.", FCVAR_REPLICATED)

concommand.Add("sfm_bridge_flip", function(ply, cmd, args)
	if not IsValid(ply) then return end
	ply:SetNWBool("sfm_bridge_flipped", not ply:GetNWBool("sfm_bridge_flipped"))
	if ply:GetNWBool("sfm_bridge_flipped") then
		ply:SetViewEntity(SFM_BRIDGE_CAMERA)
		ply:SetFOV(SFM_BRIDGE_FOV or 100)
		ply:SendLua("gui.EnableScreenClicker(true);gui.SetMousePos(ScrW() / 2, ScrH() / 2)")
	else
		ply:SetViewEntity(ply)
		ply:SetFOV(100)
		ply:SendLua("gui.EnableScreenClicker(false);gui.SetMousePos(ScrW() / 2, ScrH() / 2)")
	end
end, nil, "Flip between camera view and game view.", FCVAR_REPLICATED)

SFM_BRIDGE_FRAME = SFM_BRIDGE_FRAME or {}
SFM_BRIDGE_WSS = SFM_BRIDGE_WSS or nil

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

SFM_BRIDGE_DAGS = SFM_BRIDGE_DAGS or {}
SFM_BRIDGE_BONEDATA = SFM_BRIDGE_BONEDATA or {}
SFM_BRIDGE_BONEDATA_ENTS = SFM_BRIDGE_BONEDATA_ENTS or {}

SFM_BRIDGE_FRAME_RATE = SFM_BRIDGE_FRAME_RATE or 24
SFM_BRIDGE_CURRENT_FRAME = SFM_BRIDGE_CURRENT_FRAME or 0

local bonestoignore = {
	-- useful if specific bones cause issues, ignores itself and all children
	-- you should probably submit an issue on github if you ever need to use this
	-- https://github.com/TeamPopplio/sfm-bridge-gmod/issues
	-- managed to figure out what's wrong with it? share :)
	-- https://github.com/TeamPopplio/sfm-bridge-gmod/pulls
}

local function ShouldIngoreBone(bone)
	for _, ignore in pairs(bonestoignore) do
		if string.find(bone, ignore) then
			return true
		end
	end
	return false
end

function SFM_BRIDGE_ParseBones(children, dag, parentmatrix, bonetable, isroot, lastparent)
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
			matrixpos:SetAngles(ang)
			if bone.transform.perAxisScale then -- sfm bridge exclusive, does not exist by default
				matrixpos:Scale(Vector(bone.transform.perAxisScale.x, bone.transform.perAxisScale.y, bone.transform.perAxisScale.z))
			elseif bone.transform.scale then -- does not exist by default
				matrixpos:Scale(Vector(bone.transform.scale, bone.transform.scale, bone.transform.scale))
			end
			childtable.matrix = parentmatrix * matrixpos
			childtable.parent = lastparent
			if isroot then -- offset by position, can't set this bone directly
				dag:SetPos(childtable.matrix:GetTranslation())
				-- angles must be offset from dag:GetAngles
				dag:SetAngles(childtable.matrix:GetAngles())
			end
			table.insert(bonetable, childtable)
			if bone.children ~= nil then
				SFM_BRIDGE_ParseBones(bone.children, dag, childtable.matrix, bonetable, false, childtable.id)
			end
		end
	end
	return bonetable
end

local function AccumulateParents(dag, bonematrix, parentid)
	-- reapply all parent matrixes (used to remove the offsets)
	local newmatrix = bonematrix
	local newparentid = parentid
	if newparentid then
		while newparentid > 0 do
			parentmatrix = dag:GetBoneMatrix(newparentid)
			if parentmatrix then
				local parentlocalpos = dag:WorldToLocal(newmatrix:GetTranslation(), parentmatrix:GetAngles())
				local parentlocalang = newmatrix:GetAngles() - parentmatrix:GetAngles()
				newmatrix:SetTranslation(parentmatrix:GetTranslation() + parentlocalpos)
				newmatrix:SetAngles(parentlocalang)
				newparentid = newparentid - 1
			else
				break
			end
		end
	end
	return bonematrix
end

function SFM_BRIDGE_UpdateFrame(updateclients, commit, ismovie, frame)
	if not IsValid(SFM_BRIDGE_CAMERA) then
		SFM_BRIDGE_CAMERA = ents.Create("prop_dynamic")
	end
	if not SFM_BRIDGE_FRAME.filmClip then return end -- invalid packets?
	-- main camera
	local camera = SFM_BRIDGE_FRAME.filmClip.camera
	if camera then
		SFM_BRIDGE_CAMERA:SetModel("models/dav0r/camera.mdl")
		SFM_BRIDGE_CAMERA:DrawShadow(false)
		SFM_BRIDGE_FOV = camera.fieldOfView
		SFM_BRIDGE_CAMERA:SetPos(Vector(camera.transform.position.x, camera.transform.position.y, camera.transform.position.z))
		-- problem with rotation is that it uses quanternions, so let's convert them into qangles
		SFM_BRIDGE_CAMERA:SetAngles(QuaternionToAngles(camera.transform.orientation.w, camera.transform.orientation.x, camera.transform.orientation.y, camera.transform.orientation.z))
		for _, ply in pairs(player.GetAll()) do
			if ply:GetNWBool("sfm_bridge_flipped") then
				ply:SetViewEntity(SFM_BRIDGE_CAMERA)
				ply:SetFOV(camera.fieldOfView)
			else
				ply:SetViewEntity(ply)
			end
		end
	end
	local used_ent_indexes = {}
	if SFM_BRIDGE_FRAME.filmClip.animationSets then
		for k, v in pairs(SFM_BRIDGE_FRAME.filmClip.animationSets) do
			if v.gameModel then
				local created = false
				if not IsValid(SFM_BRIDGE_DAGS[k]) or SFM_BRIDGE_DAGS[k]:GetClass() ~= "dag_model" and not v.overrideEntity then
					created = true
					SFM_BRIDGE_DAGS[k] = ents.Create(v.overrideEntity and v.overrideEntity or "dag_model")
					SFM_BRIDGE_DAGS[k]:SetBloodColor(DONT_BLEED)
				elseif SFM_BRIDGE_DAGS[k]:GetClass() ~= v.overrideEntity and v.overrideEntity then
					SFM_BRIDGE_DAGS[k]:Remove()
					created = true
					SFM_BRIDGE_DAGS[k] = ents.Create(v.overrideEntity)
					SFM_BRIDGE_DAGS[k]:SetBloodColor(DONT_BLEED)
				end
				if not IsValid(SFM_BRIDGE_DAGS[k]) then
					printdebug("[SFM_BRIDGE] Could not create entity type " .. v.overrideEntity)
					SFM_BRIDGE_DAGS[k] = nil
					continue
				end
				local dag = SFM_BRIDGE_DAGS[k]
				dag:DrawShadow(true)
				table.insert(used_ent_indexes, dag:EntIndex())
				if v.gameModel.visible == false then -- TODO: somehow add the scene object visibility
					dag:SetPos(Vector(0,0,0))
					dag:SetNoDraw(true)
					printdebug("[SFM_BRIDGE] Entity " .. k .. " is invisible")
					continue
				end
				dag:SetNoDraw(false)
				-- this dag is a model
				local model = Model(v.overrideModel and v.overrideModel or v.gameModel.modelName)
				if MODEL_REPLACEMENTS[model] then
					if util.IsValidModel(MODEL_REPLACEMENTS[model]) then
						model = MODEL_REPLACEMENTS[model]
					end
				end
				if not util.IsValidModel(model) then
					model = "models/error.mdl"
				end
				if not v.noModel then
					if model ~= dag:GetModel() then
						dag:SetModel(model)
					end
				end
				dag:SetPos(Vector(v.gameModel.transform.position.x, v.gameModel.transform.position.y, v.gameModel.transform.position.z))
				dag:SetAngles(QuaternionToAngles(v.gameModel.transform.orientation.w, v.gameModel.transform.orientation.x, v.gameModel.transform.orientation.y, v.gameModel.transform.orientation.z))
				-- TODO: figure out how bodygroups (v.gameModel.body) are calculated and apply them here
				dag:SetSkin(v.gameModel.skin)
				-- physics if applicable
				if v.physics == true and created then
					dag:PhysicsInit(SOLID_VPHYSICS)
					dag:SetMoveType(MOVETYPE_VPHYSICS)
					dag:SetSolid(SOLID_VPHYSICS)
				elseif not v.physics and created then
					dag:PhysicsInit(SOLID_NONE)
					dag:SetMoveType(MOVETYPE_NONE)
					dag:SetSolid(SOLID_NONE)
				elseif not v.physics then
					dag:PhysicsDestroy()
				end
				if created then
					dag:Spawn()
				end
				if v.vehicle then
					local vehicle = list.Get("Vehicles")[v.vehicle or "Jeep"]
					if not vehicle then
						printdebug("[SFM_BRIDGE] Could not find vehicle " .. v.vehicle)
					else
						for k, v in pairs(vehicle.KeyValues) do
							dag:SetKeyValue(k, v)
						end
					end
				end
				-- transmit
				if v.gameModel.children ~= nil and not v.noBones then -- sfm bridge exclusive
					local parentmatrix = Matrix()
					-- these values are used as the parent matrix for parsebones
					parentmatrix:SetTranslation(dag:GetPos())
					parentmatrix:SetAngles(dag:GetAngles())
					if v.gameModel.transform.perAxisScale then -- sfm bridge exclusive, does not exist by default
						parentmatrix:SetScale(Vector(v.gameModel.transform.perAxisScale.x, v.gameModel.transform.perAxisScale.y, v.gameModel.transform.perAxisScale.z))
					elseif v.gameModel.transform.scale then -- does not exist by default
						parentmatrix:SetScale(Vector(v.gameModel.transform.scale, v.gameModel.transform.scale, v.gameModel.transform.scale))
					else
						parentmatrix:SetScale(Vector(1,1,1))
					end
					local bones = SFM_BRIDGE_ParseBones(v.gameModel.children, dag, parentmatrix, {}, true, -1)
					-- the translation and angles aren't needed anymore, so let's remove them
					parentmatrix:SetTranslation(Vector(0,0,0))
					parentmatrix:SetAngles(Angle(0,0,0))
					if updateclients then
						net.Start("SFM_BRIDGE_GetBoneData")
							net.WriteBool(commit)
							net.WriteInt(frame, 32)
							net.WriteMatrix(parentmatrix)
							net.WriteEntity(dag)
							if bones then
								net.WriteTable(bones)
							else
								net.WriteInt(0, 8) -- ???
								printdebug("No bones found for " .. ent:GetModel())
							end
						net.Broadcast()
					elseif ismovie then
						-- client mismatches entity callbacks sometimes, let's correct that
						net.Start("SFM_BRIDGE_MovieFrame")
							net.WriteEntity(dag)
							net.WriteInt(frame, 32)
						net.Broadcast()
					end
				elseif v.noBones == true and not dag.noBones then
					dag.noBones = true
					if created then
						dag:Spawn()
					end
					if v.physics == true then
						local phys = dag:GetPhysicsObject()
						if IsValid(phys) then
							phys:Wake()
						end
					end
					net.Start("SFM_BRIDGE_StopBoneData")
						net.WriteEntity(dag)
					net.Broadcast()
				end
				-- flexes :)
				if v.gameModel.globalFlexControllers then
					printdebug("Building flexes for " .. v.gameModel.modelName)
					for k2, v2 in pairs(v.gameModel.globalFlexControllers) do
						local flex = dag:GetFlexIDByName(v2.name)
						if flex then
							dag:SetFlexWeight(flex, v2.flexWeight)
						else
							printdebug("Flex " .. v2.name .. " not found in " .. v.gameModel.modelName)
						end
					end
				end
			elseif v.light then
				local created = false
				if not IsValid(SFM_BRIDGE_DAGS[k]) or SFM_BRIDGE_DAGS[k]:GetClass() ~= "dag_light" and not v.overrideEntity then
					created = true
					SFM_BRIDGE_DAGS[k] = ents.Create(v.overrideEntity and v.overrideEntity or "dag_light")
				elseif SFM_BRIDGE_DAGS[k]:GetClass() ~= v.overrideEntity and v.overrideEntity then
					SFM_BRIDGE_DAGS[k]:Remove()
					created = true
					SFM_BRIDGE_DAGS[k] = ents.Create(v.overrideEntity)
				end
				if not IsValid(SFM_BRIDGE_DAGS[k]) then
					printdebug("[SFM_BRIDGE] Could not create entity type " .. v.overrideEntity)
					SFM_BRIDGE_DAGS[k] = nil
					continue
				end
				local dag = SFM_BRIDGE_DAGS[k]
				dag:DrawShadow(false)
				table.insert(used_ent_indexes, dag:EntIndex())
				dag:SetPos(Vector(v.light.transform.position.x, v.light.transform.position.y, v.light.transform.position.z))
				dag:SetAngles(QuaternionToAngles(v.light.transform.orientation.w, v.light.transform.orientation.x, v.light.transform.orientation.y, v.light.transform.orientation.z))
				-- set network vars
				dag:SetLightDagTexture(v.light.texture)
				dag:SetLightDagFarZ(v.light.maxDistance)
				dag:SetLightDagNearZ(v.light.minDistance)
				dag:SetLightDagVerticalFOV(v.light.verticalFOV)
				dag:SetLightDagHorizontalFOV(v.light.horizontalFOV)
				dag:SetLightDagShadowDepthBias(v.light.shadowDepthBias)
				dag:SetLightDagShadowSlopeScaleDepthBias(v.light.shadowSlopeScaleDepthBias)
				dag:SetLightDagShadowFilterSize(v.light.shadowFilterSize)
				dag:SetLightDagConstantAttenuation(v.light.constantAttenuation)
				dag:SetLightDagLinearAttenuation(v.light.linearAttenuation)
				dag:SetLightDagQuadraticAttenuation(v.light.quadraticAttenuation)
				if v.light.textureFrame then
					dag:SetLightDagTextureFrame(v.textureFrame) -- exclusive to SFM Bridge
				end
				dag:SetLightDagColorR(v.light.color.r)
				dag:SetLightDagColorG(v.light.color.g)
				dag:SetLightDagColorB(v.light.color.b)
				dag:SetLightDagColorA(v.light.color.a)
				dag:SetLightDagBrightness(v.light.intensity)
				dag:SetLightDagOrthoLeft(v.orthoLeft or 0) -- exclusive to SFM Bridge
				dag:SetLightDagOrthoRight(v.orthoRight or 0) -- exclusive to SFM Bridge
				dag:SetLightDagOrthoTop(v.orthoTop or 0) -- exclusive to SFM Bridge
				dag:SetLightDagOrthoBottom(v.light.orthoBottom or 0) -- exclusive to SFM Bridge
				dag:SetLightDagCastShadows(v.light.castsShadows)
				dag:SetLightDagVolumetric(v.light.volumetric)
				dag:SetLightDagOrtho(v.ortho or false) -- exclusive to SFM Bridge
				if v.light.visible == false then -- TODO: somehow add the scene object visibility
					dag:SetLightDagVisible(false)
				else
					dag:SetLightDagVisible(true)
				end
				if created then
					dag:Spawn()
				end
				printdebug("Created light " .. v.light.name)
				-- delay?
				-- TODO: just send all of the variables through the network instead of relying on networked vars
				timer.Simple(0.1, function()
					if IsValid(dag) then
						net.Start("SFM_BRIDGE_SetupLight")
							net.WriteEntity(dag)
						net.Broadcast()
					end
				end)
			elseif v["particle system"] then
				printdebug("[SFM_BRIDGE] WARNING: Particles are not yet implemented.")
			elseif v.camera then
				continue -- useless
			else
				printdebug("[SFM_BRIDGE] WARNING: Can't determine the dag type of " .. v.name .. "! If this is in error, please create an issue on GitHub.")
			end
		end
	end
	for k, v in pairs(SFM_BRIDGE_DAGS) do
		if not v:IsValid() or not table.HasValue(used_ent_indexes, v:EntIndex()) then
			SFM_BRIDGE_DAGS[k]:Remove()
			SFM_BRIDGE_DAGS[k] = nil
		end
	end
	printdebug("Frame complete")
end

local tcp_combo = tcp_combo or ""
local received_first = received_first or false

function SFM_BRIDGE_TryJson()
	local tryjson = util.JSONToTable(tcp_combo) or false
	if tryjson ~= false then
		tcp_combo = ""
		received_first = false
		-- we have a complete JSON packet
		if tryjson.type == "framecommit" then
			SFM_BRIDGE_FRAME = tryjson
			if tryjson.currentFrame then
				printdebug("Successfully parsed frame commit for frame " .. tryjson.currentFrame)
				SFM_BRIDGE_CURRENT_FRAME = tryjson.currentFrame
				CommitFrameData(tryjson.currentFrame, tryjson)
			else
				printdebug("Successfully parsed frame commit, however no frame was specified.")
			end
			if tryjson.frameRate then
				SFM_BRIDGE_FRAME_RATE = tryjson.frameRate
			end
			SFM_BRIDGE_UpdateFrame(true, SFM_BRIDGE_CURRENT_FRAME ~= nil and true or false, false, tryjson.currentFrame or SFM_BRIDGE_CURRENT_FRAME or 0)
		elseif tryjson.type == "framedata" then
			printdebug("Successfully parsed frame data")
			SFM_BRIDGE_FRAME = tryjson
			SFM_BRIDGE_UpdateFrame(true, false, false, SFM_BRIDGE_CURRENT_FRAME or 0)
		else
			printdebug("Recieved unknown data type, is this client up to date?")
		end
	else
		printdebug("SFM Bridge FAILED TO PARSE JSON")
	end
end

function SFM_BRIDGE_ConnectWSS(url, ply, force)
	if not url or url == "" then
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "SFM Bridge URL is empty, tell the server owner to set it via 'sfm_bridge_ip' and try again.")
		end
		printdebug("Attempted to connect to SFM Bridge with an empty URL, set the URL via 'sfm_bridge_ip' and try again.")
	elseif SFM_BRIDGE_WSS and not force and IsValid(ply) then
		ply:PrintMessage(HUD_PRINTCONSOLE, "SFM Bridge is already connected, try again with 'sfm_bridge_connect force' if there was a problem.")
	else
		SFM_BRIDGE_WSS = GWSockets.createWebSocket(url, false)
		function SFM_BRIDGE_WSS:onMessage(msg)
			-- we need to recieve multiple TCP packets
			if string.StartWith(msg, "!START!") and string.EndsWith(msg, "!END!") then
				printdebug("Recieved complete data")
				tcp_combo = string.Replace(string.Replace(msg, "!START!", ""), "!END!", "")
				SFM_BRIDGE_TryJson()
			elseif string.StartWith(msg, "!START!") then
				printdebug("Recieved first data")
				tcp_combo = string.Replace(msg, "!START!", "")
				received_first = true
			elseif string.EndsWith(msg, "!END!") then
				printdebug("Recieved end of data")
				tcp_combo = tcp_combo .. string.Replace(msg, "!END!", "")
				received_first = false
				SFM_BRIDGE_TryJson()
			elseif received_first then -- in between
				printdebug("Recieved in-between data, concatenating")
				tcp_combo = tcp_combo .. msg
			else
				printdebug("Recieved data, but we didn't expect it")
			end
		end
		function SFM_BRIDGE_WSS:onError(errMessage)
			printdebug("SFM Bridge ERROR: " .. errMessage)
		end
		function SFM_BRIDGE_WSS:onConnected()
			printdebug("SFM Bridge CONNECTED")
		end
		function SFM_BRIDGE_WSS:onDisconnected()
			tcp_combo = ""
			received_first = false
			printdebug("SFM Bridge DISCONNECTED")
		end
		SFM_BRIDGE_WSS:open()
		if IsValid(ply) then
			ply:PrintMessage(HUD_PRINTCONSOLE, "Connected to SFM Bridge.")
		end
	end
end

-- flip views
hook.Add("ShowSpare1", "Flipper", function(ply)
	ply:ConCommand("sfm_bridge_flip")
end)

-- Movies
SFM_BRIDGE_MOVIE_DATA = SFM_BRIDGE_MOVIE_DATA or {}
SFM_BRIDGE_MOVIE_FIRST_FRAME = SFM_BRIDGE_MOVIE_FIRST_FRAME
SFM_BRIDGE_MOVIE_LAST_FRAME = SFM_BRIDGE_MOVIE_LAST_FRAME

function CommitFrameData(time, frame) -- Commit frames, this is not called when frames are transmitted.
	StopFrameData()
	-- set SFM_BRIDGE_MOVIE_FIRST_FRAME and SFM_BRIDGE_MOVIE_LAST_FRAME (even if they're zero)
	if not SFM_BRIDGE_MOVIE_FIRST_FRAME or SFM_BRIDGE_MOVIE_FIRST_FRAME > time then
		SFM_BRIDGE_MOVIE_FIRST_FRAME = time
	end
	if not SFM_BRIDGE_MOVIE_LAST_FRAME or SFM_BRIDGE_MOVIE_LAST_FRAME < time then
		SFM_BRIDGE_MOVIE_LAST_FRAME = time
	end
    SFM_BRIDGE_MOVIE_DATA[time] = frame -- Doesn't matter if it already exists, it'll overwrite it.
end

function ClearFrameData()
	StopFrameData()
	SFM_BRIDGE_MOVIE_DATA = {}
	SFM_BRIDGE_MOVIE_FIRST_FRAME = nil
	SFM_BRIDGE_MOVIE_LAST_FRAME = nil
	for k, v in pairs(SFM_BRIDGE_DAGS) do
		if IsValid(v) then
			v:Remove()
		end
	end
	if IsValid(SFM_BRIDGE_CAMERA) then
		SFM_BRIDGE_CAMERA:Remove()
	end
	/*
	net.Start("SFM_BRIDGE_ClearBoneData")
	net.Broadcast()
	*/
end

local sfm_bridge_movie_loop = CreateConVar("sfm_bridge_movie_loop", "0", {FCVAR_REPLICATED}, "Whether or not to loop the movie.")

function PlayFrameData(startframe, endframe, framerate, reverse) -- Play frames, done through console.
	-- set SFM_BRIDGE_FRAME for every frame until the end
	printdebug("Starting playback")
	-- framerate-based timer
	timer.Remove("SFM_BRIDGE_PlayFrameData") -- just in case
	local frame = startframe
	if not frame then return end
	timer.Create("SFM_BRIDGE_PlayFrameData", 1 / (framerate or SFM_BRIDGE_FRAME_RATE), 0, function()
		frame = reverse and (frame - 1) or (frame + 1)
		SFM_BRIDGE_CURRENT_FRAME = frame
		if reverse and frame == SFM_BRIDGE_MOVIE_FIRST_FRAME or not reverse and frame == SFM_BRIDGE_MOVIE_LAST_FRAME then
			if not sfm_bridge_movie_loop:GetBool() then
				timer.Remove("SFM_BRIDGE_PlayFrameData")
				printdebug("Ending playback")
				return
			else
				frame = reverse and SFM_BRIDGE_MOVIE_LAST_FRAME or SFM_BRIDGE_MOVIE_FIRST_FRAME
			end
		end
		if SFM_BRIDGE_MOVIE_DATA[frame] then
			SetGlobalInt("SFM_BRIDGE_CURRENT_FRAME", frame)
			printdebug("Playing frame " .. frame)
			SFM_BRIDGE_FRAME = SFM_BRIDGE_MOVIE_DATA[frame]
			SFM_BRIDGE_UpdateFrame(false, false, true, frame)
			hook.Run("SFM_BRIDGE_MovieFrame", frame) -- lua scripters can interface with this
		end
	end)
	/*
	net.Start("SFM_BRIDGE_PlayBoneData")
		net.WriteInt(frame, 32)
		net.WriteInt(endframe or SFM_BRIDGE_MOVIE_LAST_FRAME or SFM_BRIDGE_CURRENT_FRAME, 32)
		net.WriteInt(framerate or SFM_BRIDGE_FRAME_RATE, 32)
		net.WriteInt(SFM_BRIDGE_MOVIE_FIRST_FRAME or 0, 32)
		net.WriteInt(SFM_BRIDGE_MOVIE_LAST_FRAME or 0, 32)
		net.WriteBool(reverse)
	net.Broadcast()
	*/
end

local movie_paused = movie_paused or false
local movie_reversed = movie_reversed or false

-- Playhead functions
function PauseFrameData()
	timer.Pause("SFM_BRIDGE_PlayFrameData")
	//net.Start("SFM_BRIDGE_PauseBoneData")
	//net.Broadcast()
	movie_paused = true
end

function ResumeFrameData()
	timer.UnPause("SFM_BRIDGE_PlayFrameData")
	//net.Start("SFM_BRIDGE_ResumeBoneData")
	//net.Broadcast()
	movie_paused = false
end

function StopFrameData()
	movie_paused = false
	SFM_BRIDGE_CURRENT_FRAME = 0
	timer.Remove("SFM_BRIDGE_PlayFrameData")
	//net.Start("SFM_BRIDGE_StopBoneDataMovie")
	//net.Broadcast()
end

function GoToFrameData(frame) -- might as well add to make it similar to demos
	timer.Remove("SFM_BRIDGE_PlayFrameData")
	SFM_BRIDGE_FRAME = SFM_BRIDGE_MOVIE_DATA[frame] or SFM_BRIDGE_FRAME
	hook.Run("SFM_BRIDGE_MovieFrame", time)
	//net.Start("SFM_BRIDGE_GoToBoneData")
		//net.WriteInt(frame, 32)
	//net.Broadcast()
	local endframe = (movie_reversed and SFM_BRIDGE_MOVIE_FIRST_FRAME or SFM_BRIDGE_MOVIE_LAST_FRAME)
	local framerate = SFM_BRIDGE_FRAME_RATE
	PlayFrameData(frame, endframe, framerate, movie_reversed)
end

concommand.Add("sfm_bridge_movie_play", function(ply, cmd, args)
	StopFrameData()
	movie_paused = false
	SFM_BRIDGE_CURRENT_FRAME = 0
	local startframe = args[1] and tonumber(args[1]) or (movie_reversed and SFM_BRIDGE_MOVIE_LAST_FRAME or SFM_BRIDGE_MOVIE_FIRST_FRAME)
	local endframe = args[2] and tonumber(args[2]) or (movie_reversed and SFM_BRIDGE_MOVIE_FIRST_FRAME or SFM_BRIDGE_MOVIE_LAST_FRAME)
	local framerate = args[3] and tonumber(args[3]) or SFM_BRIDGE_FRAME_RATE
	printdebug(startframe, endframe, framerate)
	PlayFrameData(startframe, endframe, framerate, movie_reversed)
end)

concommand.Add("sfm_bridge_movie_reverse", function(ply, cmd, args)
	movie_paused = false
	movie_reversed = not movie_reversed
	local framerate = args[1] and tonumber(args[1]) or SFM_BRIDGE_FRAME_RATE
	PlayFrameData(SFM_BRIDGE_CURRENT_FRAME, movie_reversed and SFM_BRIDGE_MOVIE_LAST_FRAME or SFM_BRIDGE_MOVIE_FIRST_FRAME, framerate, movie_reversed)
end)

concommand.Add("sfm_bridge_movie_pause", function(ply, cmd, args)
	if not timer.Exists("SFM_BRIDGE_PlayFrameData") then
		ply:PrintMessage(HUD_PRINTCONSOLE, "SFM Bridge is not playing a movie.")
		return
	end
	PauseFrameData()
end)

concommand.Add("sfm_bridge_movie_resume", function(ply, cmd, args)
	if not timer.Exists("SFM_BRIDGE_PlayFrameData") then
		ply:PrintMessage(HUD_PRINTCONSOLE, "SFM Bridge is not playing a movie.")
		return
	end
	ResumeFrameData()
end)

concommand.Add("sfm_bridge_movie_togglepause", function(ply, cmd, args)
	if not timer.Exists("SFM_BRIDGE_PlayFrameData") then
		ply:PrintMessage(HUD_PRINTCONSOLE, "SFM Bridge is not playing a movie.")
		return
	end
	if movie_paused then
		ResumeFrameData()
	else
		PauseFrameData()
	end
end)

concommand.Add("sfm_bridge_movie_stop", function(ply, cmd, args)
	if not timer.Exists("SFM_BRIDGE_PlayFrameData") then
		ply:PrintMessage(HUD_PRINTCONSOLE, "SFM Bridge is not playing a movie.")
		return
	end
	StopFrameData()
end)

concommand.Add("sfm_bridge_movie_goto", function(ply, cmd, args)
	if not args[1] then
		ply:PrintMessage(HUD_PRINTCONSOLE, "Usage: sfm_bridge_movie_goto <frame>")
		return
	end
	GoToFrameData(tonumber(args[1]))
end)

concommand.Add("sfm_bridge_goto_camera", function(ply, cmd, args)
	if IsValid(SFM_BRIDGE_CAMERA) then
		ply:SetPos(SFM_BRIDGE_CAMERA:GetPos())
	end
end)

concommand.Add("sfm_bridge_movie_clear", function(ply, cmd, args)
	ClearFrameData()
end)
