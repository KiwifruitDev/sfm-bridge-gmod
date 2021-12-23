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

-- initialize from sfmsock

include("sfmsock/sh_init.lua")

if CLIENT then
    include("sfmsock/cl_init.lua")
end

if SERVER then
	AddCSLuaFile("sfmsock/cl_init.lua")
	AddCSLuaFile("sfmsock/sh_init.lua")
    include("sfmsock/init.lua")
end
