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

AddCSLuaFile()

if CLIENT then
	pcall(require, "volumetric") -- This module does not exist yet, future-proofing.
end

local function printdebug(...)
	if GetConVar("sfm_bridge_debug", "0"):GetBool() then
		print(...)
	end
end

ENT.Base = "dag"
ENT.Type = "anim"

ENT.Spawnable = false
ENT.AdminOnly = true

ENT.PrintName = "Light Dag"
ENT.Author = "KiwiFruitDev"
ENT.Category = "SFM Bridge"
ENT.Purpose = "Used to represent Source Filmmaker lighting within Garry's Mod."
ENT.Instructions = "Intended for internal use only."
ENT.Contact = "https://github.com/TeamPopplio/sfm-bridge-gmod"

ENT.DisableDuplicator = true
ENT.DoNotDuplicate = true

ENT.IsLightDag = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "LightDagTexture")
	self:NetworkVar("Int", 0, "LightDagFarZ")
	self:NetworkVar("Int", 1, "LightDagNearZ")
	self:NetworkVar("Int", 2, "LightDagVerticalFOV")
	self:NetworkVar("Int", 3, "LightDagHorizontalFOV")
	self:NetworkVar("Int", 4, "LightDagShadowDepthBias")
	self:NetworkVar("Int", 5, "LightDagShadowSlopeScaleDepthBias")
	self:NetworkVar("Int", 6, "LightDagShadowFilterSize")
	self:NetworkVar("Int", 7, "LightDagConstantAttenuation")
	self:NetworkVar("Int", 8, "LightDagLinearAttenuation")
	self:NetworkVar("Int", 9, "LightDagQuadraticAttenuation")
	self:NetworkVar("Int", 9, "LightDagQuadraticAttenuation")
	self:NetworkVar("Int", 10, "LightDagTextureFrame")
	self:NetworkVar("Int", 11, "LightDagColorR")
	self:NetworkVar("Int", 12, "LightDagColorG")
	self:NetworkVar("Int", 13, "LightDagColorB")
	self:NetworkVar("Int", 14, "LightDagColorA")
	self:NetworkVar("Int", 15, "LightDagBrightness")
	self:NetworkVar("Int", 16, "LightDagOrthoLeft")
	self:NetworkVar("Int", 17, "LightDagOrthoTop")
	self:NetworkVar("Int", 18, "LightDagOrthoRight")
	self:NetworkVar("Int", 19, "LightDagOrthoBottom")
	self:NetworkVar("Bool", 0, "LightDagCastShadows")
	self:NetworkVar("Bool", 1, "LightDagVolumetric") -- Useless without the binary module.
	self:NetworkVar("Bool", 2, "LightDagVisible")
	self:NetworkVar("Bool", 3, "LightDagOrtho")
	if SERVER then
		-- defaults from Source Filmmaker
		self:SetLightDagTexture("effects/flashlight001")
		self:SetLightDagFarZ(600)
		self:SetLightDagNearZ(10)
		self:SetLightDagVerticalFOV(45)
		self:SetLightDagHorizontalFOV(45)
		self:SetLightDagShadowDepthBias(0.00008)
		self:SetLightDagShadowSlopeScaleDepthBias(2)
		self:SetLightDagShadowFilterSize(3)
		self:SetLightDagConstantAttenuation(0)
		self:SetLightDagLinearAttenuation(0)
		self:SetLightDagQuadraticAttenuation(1500)
		self:SetLightDagTextureFrame(0) -- exclusive to SFM Bridge
		self:SetLightDagColorR(255)
		self:SetLightDagColorG(255)
		self:SetLightDagColorB(255)
		self:SetLightDagColorA(255)
		self:SetLightDagBrightness(500)
		self:SetLightDagOrthoLeft(100) -- exclusive to SFM Bridge
		self:SetLightDagOrthoTop(100) -- exclusive to SFM Bridge
		self:SetLightDagOrthoRight(100) -- exclusive to SFM Bridge
		self:SetLightDagOrthoBottom(100) -- exclusive to SFM Bridge
		self:SetLightDagCastShadows(true)
		self:SetLightDagVolumetric(false)
		self:SetLightDagVisible(true)
		self:SetLightDagOrtho(false) -- exclusive to SFM Bridge
	end
end

function ENT:InitializeLight()
	if not IsValid(self.lamp) and self:GetLightDagVisible() then
		self.lamp = ProjectedTexture()
	elseif IsValid(self.lamp) and not self:GetLightDagVisible() then
		self.lamp:Remove()
		self.lamp = nil
		return
	elseif not IsValid(self.lamp) and not self:GetLightDagVisible() then
		return -- not valid and not visible
	end
	self.lamp:SetTexture(self:GetLightDagTexture())
	self.lamp:SetFarZ(self:GetLightDagFarZ())
	self.lamp:SetNearZ(self:GetLightDagNearZ())
	self.lamp:SetVerticalFOV(self:GetLightDagVerticalFOV())
	self.lamp:SetHorizontalFOV(self:GetLightDagHorizontalFOV())
	self.lamp:SetShadowDepthBias(self:GetLightDagShadowDepthBias())
	self.lamp:SetShadowSlopeScaleDepthBias(self:GetLightDagShadowSlopeScaleDepthBias())
	self.lamp:SetShadowFilter(self:GetLightDagShadowFilterSize())
	self.lamp:SetConstantAttenuation(self:GetLightDagConstantAttenuation())
	self.lamp:SetLinearAttenuation(self:GetLightDagLinearAttenuation())
	self.lamp:SetQuadraticAttenuation(self:GetLightDagQuadraticAttenuation())
	self.lamp:SetTextureFrame(self:GetLightDagTextureFrame())
	self.lamp:SetColor(Color(self:GetLightDagColorR(), self:GetLightDagColorG(), self:GetLightDagColorB(), self:GetLightDagColorA()))
	self.lamp:SetBrightness(self:GetLightDagBrightness())
	self.lamp:SetEnableShadows(self:GetLightDagCastShadows())
	if self.lamp.SetVolumetric then
		self.lamp:SetVolumetric(self:GetLightDagVolumetric())
	elseif self:GetLightDagVolumetric() == true then -- binary module missing
		printdebug("[SFM Bridge] WARNING: Volumetric lighting is not supported on this server.")
	end
	self.lamp:SetOrthographic(self:GetLightDagOrtho(), self:GetLightDagOrthoLeft(), self:GetLightDagOrthoTop(), self:GetLightDagOrthoRight(), self:GetLightDagOrthoBottom())
	self.lamp:SetPos(self:GetPos())
	self.lamp:SetAngles(self:GetAngles())
	self.lamp:Update()
end
