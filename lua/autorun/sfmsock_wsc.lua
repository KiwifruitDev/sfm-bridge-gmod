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

-- initialize from sfm_bridge

include("sfmbridge/sh_init.lua")

if CLIENT then
    include("sfmbridge/cl_init.lua")
end

if SERVER then
	AddCSLuaFile("sfmbridge/cl_init.lua")
	AddCSLuaFile("sfmbridge/sh_init.lua")
	AddCSLuaFile("includes/modules/volumetric.lua") -- fake volumetric lua file
    include("sfmbridge/init.lua")
end
