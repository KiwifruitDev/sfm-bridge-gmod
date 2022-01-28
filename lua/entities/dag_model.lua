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

ENT.Base = "dag"
ENT.Type = "anim"

ENT.Spawnable = false
ENT.AdminOnly = true

ENT.PrintName = "Model Dag"
ENT.Author = "KiwiFruitDev"
ENT.Category = "SFM Bridge"
ENT.Purpose = "Used to represent Source Filmmaker models within Garry's Mod."
ENT.Instructions = "Intended for internal use only."
ENT.Contact = "https://github.com/TeamPopplio/sfm-bridge-gmod"

ENT.DisableDuplicator = true
ENT.DoNotDuplicate = true

ENT.IsModelDag = true

function ENT:Draw()
    self:DrawModel()
    self:CreateShadow()
end 
