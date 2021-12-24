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

concommand.Add("sfmsock_cl_flush", function()
	SFMSOCK_CLIENT_BONES = {}
	for k, v in pairs(SFMSOCK_CLIENT_CALLBACKS) do
		local ent = ents.GetByIndex(k)
		if IsValid(ent) then
			ent:RemoveCallback("BuildBonePositions", v)
		end
		SFMSOCK_CLIENT_CALLBACKS[k] = nil
	end
end)

net.Receive("SFMSOCK_StopBoneData", function()
	local ent = net.ReadEntity()
	SFMSOCK_CLIENT_BONES[ent:EntIndex()] = nil
	if SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()] then
		ent:RemoveCallback("BuildBonePositions", SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()])
		SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()] = nil
	end
end)

net.Receive("SFMSOCK_GetBoneData", function()
	local newmatrix = net.ReadMatrix()
	local ent = net.ReadEntity()
	local ismade = SFMSOCK_CLIENT_BONES[ent:EntIndex()] ~= nil and true or false
	local bones = net.ReadTable()
	SFMSOCK_CLIENT_BONES[ent:EntIndex()] = bones
	if IsValid(ent) then
		print("Processing bone data for " .. ent:GetModel())
	elseif not IsValid(ent) then
		return
	end
	if newmatrix then
		ent:EnableMatrix("RenderMultiply", newmatrix)
	end
	if not ismade then
		ent:SetRenderBoundsWS(Vector(), Vector(), Vector(16384, 16384, 16384)) -- the entire world
		ent:SetLOD(0)
		SFMSOCK_CLIENT_CALLBACKS[ent:EntIndex()] = ent:AddCallback("BuildBonePositions", function( ent, numbones )
			if SFMSOCK_CLIENT_BONES[ent:EntIndex()] then
				for _, data in pairs(SFMSOCK_CLIENT_BONES[ent:EntIndex()]) do
					local boneindex = ent:LookupBone(data.name)
					if boneindex ~= nil then
						if ent:GetBoneContents(boneindex) ~= 0 then
							ent:SetBoneMatrix(boneindex, data.matrix)
						end
					end
				end
			end
		end)
	end
end)
