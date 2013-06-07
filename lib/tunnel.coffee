require("coffee-script")
ws = require "ws"
events = require "events"
WebSocket = ws
WebSocketServer = ws.Server
Log = require "./log.coffee"
class Tunnel extends events.EventEmitter
    constructor:()->
        @isClosed = false
        super()
Tunnel.create = (type,info)->
    if type is "ws"
        return new WebSocketTunnel(info)
    return null
class WebSocketTunnel extends Tunnel
    constructor:(info)->
        if info.ws
            @canReconnect = false
            @ws = info.ws
        else
            @host = info.host or "localhost"
            @port = info.port or 20000
            @ws = new WebSocket(["ws://",@host,":",@port].join(""))
            @canReconnect = true
        # using websocket to init
        
        @initWebsocket()
    initWebsocket:()->
        if @ws.readyState is 0
            @ws.on "open",()=>
                @isReady = true
                @isClosed = false
                @emit "ready"
        else if @ws.readyState is 1
            @isReady = true
            @isClosed = false
        else
            Log.error "Init WebSocket Is Brokwn, readyState",@ws.readyState
            @emit "close",false

        @ws.on "message",(data)=>
            @emit "data",data
        @ws.on "error",(err)=>
            @emit "error",err
        @ws.on "close",()=>
            @isReady = false
            if @isClosed
                return
            @isReady = false
            @isClosed = true
            @close()
    toString:()->
        if @ws and @ws.readyState is 1
            return "Websocket("+JSON.stringify(@ws._socket.remoteAddress)+")"
        else if not @ws
            return "Websocket(null)"
        else
            return "Websocket(not connected)"
    write:(data)->
        if @ws.readyState isnt 1
            @emit "error",new Error "Websocket Not Ready To Write"
            return false
        @ws.send data.toString()
        return true
    close:(force)->
        # force close will not emit close event
        force = force and true or false
        if @isClosed then return
        if force
            @neverOpenAgain = true
        @ws.close()
        @emit "close",force
    reconnect:()->
        if @ws.readyState is 1
            Log.warn "reconnect open ws"
            @ws.close()
        if @neverOpenAgain
            return false
        if @canReconnect
            @ws = null
            @ws = new WebSocket(["ws://",@host,":",@port].join(""))
        return @canReconnect



exports.Tunnel = Tunnel
exports.WebSocketTunnel = WebSocketTunnel

