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

AddCSLuaFile()

ENT.Base = "base_entity"
ENT.Type = "anim"

ENT.Spawnable = false
ENT.AdminOnly = true

ENT.PrintName = "Dag"
ENT.Author = "KiwiFruitDev"
ENT.Category = "SFM SOCK"
ENT.Purpose = "Used to represent Source Filmmaker dags within Garry's Mod."
ENT.Instructions = "Intended for internal use only."
ENT.Contact = "https://github.com/TeamPopplio/sfmsock-wsc-gmod"

ENT.DisableDuplicator = true
ENT.DoNotDuplicate = true

function ENT:Draw()
    local mdl = self:GetModel()
    if mdl ~= "" then
        if not string.find(mdl, "*") then
	        self:DrawModel()
        end
    end
end 
