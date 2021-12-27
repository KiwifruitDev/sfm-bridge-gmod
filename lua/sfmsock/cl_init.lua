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

SFMSOCK_CLIENT_BONES = SFMSOCK_CLIENT_BONES or {}
SFMSOCK_CLIENT_CALLBACKS = SFMSOCK_CLIENT_CALLBACKS or {}
SFMSOCK_CLIENT_MOVIE_DATA = SFMSOCK_CLIENT_MOVIE_DATA or {}

local sfmsock_cl_disablebones = CreateConVar("sfmsock_cl_disablebones", "0", FCVAR_NONE, "Disables bone manipulation on the client.")
local sfmsock_cl_framecommand = CreateConVar("sfmsock_cl_framecommand", "", FCVAR_NONE, "Runs this command on every frame sent by SFM SOCK.")

local function printdebug(...)
	if GetConVar("sfmsock_debug", "0"):GetBool() then
		print(...)
	end
end

local function flush(ent)
	local count = 0
	if IsValid(ent) then
		local callbacks = ent:GetCallbacks("BuildBonePositions")
		if callbacks then
			for k, v in pairs(callbacks) do
				ent:RemoveCallback("BuildBonePositions", k)
				count = count + 1
			end
		end
	end
	if sfmsock_cl_disablebones:GetBool() then return count end -- ignore bone data if disabled
	SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()] = ent:AddCallback("BuildBonePositions", function( self, numbones )
		if SFMSOCK_CLIENT_BONES[self:EntIndex()] then
			for _, data in pairs(SFMSOCK_CLIENT_BONES[self:EntIndex()]) do
				local boneindex = self:LookupBone(data.name)
				if boneindex ~= nil then
					if self:GetBoneContents(boneindex) ~= 0 then
						self:SetBoneMatrix(boneindex, data.matrix)
					end
				end
			end
		end
	end)
	return count
end

cvars.AddChangeCallback("sfmsock_cl_disablebones", function(cvar, old, new)
	for k, v in pairs(SFMSOCK_CLIENT_BONES) do
		local ent = Entity(k)
		if IsValid(ent) then
			flush(ent)
		end
	end
	if new == "1" then
		SFMSOCK_CLIENT_BONES = {}
	end
end)

concommand.Add("sfmsock_cl_flush", function()
	SFMSOCK_CLIENT_BONES = {}
	for k, v in pairs(SFMSOCK_CLIENT_CALLBACKS) do
		local ent = ents.GetByIndex(k)
		if IsValid(ent) then
			local count = flush(ent)
			printdebug("Removed " .. count .. " callback" .. (count ~= 1 and "s" or "") .. " from entity index " .. k)
		else
			printdebug("Could not remove callbacks from invalid entity index " .. k)
		end
	end
	SFMSOCK_CLIENT_CALLBACKS = {}
end)

net.Receive("SFMSOCK_SetupLight", function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end
	if not ent.IsLightDag then return end
	printdebug("[SFMSOCK] Setting up light for entity index " .. ent:EntIndex())
	ent:InitializeLight()
end)

net.Receive("SFMSOCK_StopBoneData", function()
	-- todo: GetCallbacks
	local ent = net.ReadEntity()
	SFMSOCK_CLIENT_BONES[ent:EntIndex()] = nil
	if SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()] then
		ent:RemoveCallback("BuildBonePositions", SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()])
		SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()] = nil
	end
end)

net.Receive("SFMSOCK_GetBoneData", function()
	local commit = net.ReadBool()
	local frame = net.ReadInt(32)
	local newmatrix = net.ReadMatrix()
	local ent = net.ReadEntity()
	local bones = net.ReadTable()
	if IsValid(ent) then
		SFMSOCK_CLIENT_BONES[ent:EntIndex()] = bones
		if commit then
			SFMSOCK_CLIENT_MOVIE_DATA[frame] = SFMSOCK_CLIENT_MOVIE_DATA[frame] or {}
			SFMSOCK_CLIENT_MOVIE_DATA[frame][ent:EntIndex()] = bones
		end
		printdebug("Processing bone data for " .. ent:GetModel() .. " on frame " .. frame .. ".")
		flush(ent) -- this was a problem, so I added this
		if newmatrix then
			ent:EnableMatrix("RenderMultiply", newmatrix)
		end
		ent:SetRenderBoundsWS(Vector(), Vector(), Vector(16384, 16384, 16384)) -- the entire world
		ent:SetLOD(0)
	end
end)

net.Receive("SFMSOCK_MovieFrame", function()
	local ent = net.ReadEntity()
	local frame = net.ReadInt(32)
	-- just in case
	if IsValid(ent) then
		flush(ent)
		if SFMSOCK_CLIENT_MOVIE_DATA[frame] then
			printdebug("Playing frame " .. frame .. " for " .. ent:GetModel())
			SFMSOCK_CLIENT_BONES = SFMSOCK_CLIENT_MOVIE_DATA[frame]
			local command = sfmsock_cl_framecommand:GetString()
			local args = string.Explode(" ", command)
			command = args[1]
			table.remove(args, 1)
			RunConsoleCommand(command, unpack(args))
		end
	end
end)

