require("coffee-script")
Tunnel = require "./tunnel"
ws = require "ws"
events = require "events"
WebSocket = ws
WebSocketServer = ws.Server

class Gateway extends events.EventEmitter
    constructor:()->
        super()
        @tunnels = []
        Gateway.instances.push this
    close:()->
        if @isClose
            return
        @isClose = true
        if @server
            @server.close()
        for item in @tunnels
            item.close(true)
        @tunnels = []

class WebSocketGateway extends Gateway
    constructor:(port,host)->
        super()
        @server = new WebSocketServer {port:port,host:host},()=>
            @isReady = true
            @emit "ready"
        @server.on "connection",(ws)=>
            tunnel = new Tunnel.WebSocketTunnel({ws:ws})
            @emit "connection",tunnel
            @tunnels.push tunnel
        @server.on "error",(err)=>
            @emit "error",err
            @close()
Gateway.instances = []
Gateway.clear = ()->
    for gateway in Gateway.instances
        console.log "clear server"
        gateway.close()
exports.Gateway = Gateway
exports.WebSocketGateway = WebSocketGateway
