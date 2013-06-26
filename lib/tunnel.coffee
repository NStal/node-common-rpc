require("coffee-script")
ws = require "ws"
events = require "events"
WebSocket = ws
WebSocketServer = ws.Server
Log = require "./log.coffee"
class Tunnel extends events.EventEmitter
    constructor:()->
        @isClosed = false
        @id = Tunnel.idIndex++
        super()
Tunnel.create = (type,info)->
    if type is "ws"
        return new WebSocketTunnel(info)
    return null
Tunnel.idIndex = 0
# @isReady
# @isClosed
# @isConnecting
# @isClosed -> @isClosed && isConnecting -> @isReady  
class WebSocketTunnel extends Tunnel
    constructor:(info)->
        @isClosed = true
        @isConnecting = false
        @isReady = false
        if info.ws 
            @canReconnect = false
            if info.ws not instanceof WebSocket
                throw new Error "Receive ws option but not instanceof WebSocket"
            @ws = info.ws
            
        else
            if not info.host
                Log.warn "no host specified, default to localhost"
            if not info.port
                Log.warn "no port specified, default to 20000"
            @host = info.host or "localhost"
            @port = info.port or 20000
            @ws = new WebSocket(["ws://",@host,":",@port].join(""))
            @canReconnect = true
        @isConnecting = true
        # using websocket to init
        
        @initWebSocket()
    initWebSocket:()->
        if @ws.readyState is 0
            @isConnecting = true
            @ws.on "open",()=>
                @isReady = true
                @isClosed = false
                @isConnecting = false
                @emit "ready"
        else if @ws.readyState is 1
            @isReady = true
            @isClosed = false
            @isConnecting = false
        else
            Log.error "Init WebSocket Is Brokwn, readyState",@ws.readyState
            @emit "error",new Error "Fail to init websocket"
            @closeIfNotClosed()
        
        @ws.on "message",(data)=>
            @emit "data",new Buffer(data,"base64").toString()
        @ws.on "error",(err)=>
            @emit "error",err
        @ws.on "close",()=>
            @closeIfNotClosed()
    closeIfNotClosed:()->
        if @isClosed
            return
        @isClosed = true
        @isReady = false
        @ws.close()
        @emit "close"
    toString:()->
        if @ws and @ws.readyState is 1
            return "Websocket("+JSON.stringify(@ws._socket.remoteAddress)+")"
        else if not @ws
            return "Websocket(null)"
        else
            return "Websocket(not connected)"
    write:(data)->
        if not @ws
            Log.error "Not WebSocke Asigned In Tunnel"
            @emit "error",new Error "Websocket Not Ready To Write"
            return false
        if @ws.readyState isnt 1
            Log.error "Websocket Try Write Ad State #{@ws.readyState}"
            @emit "error",new Error "Websocket Not Ready To Write"
            return false
        
        @ws.send new Buffer(data).toString("base64")
        return true
    close:()->
        @ws.close()
    reconnect:()->
        if @ws and @ws.readyState is 1
            Log.warn "reconnect open websocket"
            @ws.close()
        if @isConnecting
            Log.warn "already connecting"
        if @canReconnect
            @ws = null
            @ws = new WebSocket(["ws://",@host,":",@port].join(""))
            @initWebSocket()
        
        
        return @canReconnect



exports.Tunnel = Tunnel
exports.WebSocketTunnel = WebSocketTunnel

