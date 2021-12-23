# SFM SOCK Websocket Client for Garry's Mod
A websocket client for Garry's Mod intended to retrieve scene and frame data from [SFM SOCK](https://github.com/TeamPopplio/sfmsock).

This software can be used to replicate scenes from Source Filmmaker with 1:1 accuracy.

## Installation
The [GWSockets](https://github.com/FredyH/GWSockets) binary module must be installed first, see its documentation for more details.

Once GWSockets is installed, clone this repository to your Garry's Mod's ``addons`` directory.

You should now be able to access console commands with the ``sfmsock_`` prefix when loaded.

## Usage
Requires the use of an SFM SOCK-compatible proxy server and an instance of [SFM SOCK](https://github.com/TeamPopplio/sfmsock).

The [SFM SOCK Websocket Server Proxy](https://github.com/TeamPopplio/sfmsock-wss-proxy) is provided for ease of use.

To run the proxy server, you must have [node.js](https://nodejs.org/) v16 or higher installed.

## Connecting to a server
When a server is running, you can connect to it by running the ``sfmsock_connect`` command.

The default server IP is ``wss://localhost:9191/``, it can be changed via the ``sfmsock_ip`` convar.

This addon can be restricted to super admins only using the ``sfmsock_restrict`` convar.

Once the client has successfully connected, when data is transmitted it should update your game automatically.

## License
This software is licensed under the MIT License.
