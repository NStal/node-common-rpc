require("coffee-script")
Log = require "./log.coffee"
Tunnel = (require "./tunnel.coffee").Tunnel
protocol = require "./protocol.coffee"
events = require "events"
class RPCSession
    constructor:(name,args,callback)->
        @ticket = parseInt(Math.random()*1000000000)
        @name = name
        @args = args
        @callback = (_args...)=>
            if @done
                return
            @close()
            if callback
                callback.apply(this,_args)
    close:()->
        @done = true
    serialize:()->
        JSON.stringify({name:@name,args:@args,ticket:@ticket})

class RPCInterface extends events.EventEmitter
    constructor:(tunnel)->
        if not tunnel
            return
        @_callSessions = [];
        @_callSessionBuffers = []
        @timeout = 1000 * 10;
        @setTunnel(tunnel)
    setTunnel:(tunnel)->
        if @tunnel
            # force close the old tunnel
            @tunnel.close(true)
        @tunnel = tunnel
        @tunnel.on "error",(err)=>
            # panic...,OK may be just small mistake
            Log.error "tunnel error",err
        @tunnel.on "close",(force)=>
            # not closing buffers, let it timeout
            # in case tunnel end before data call
            # if not force close try reconnect
            if not force
                @_tryReconnect()
        @tunnel.on "ready",()=>
            @_isReconnect = false
            @_flushSessionBuffers()
        if @tunnel.isReady
            @_isReconnect = false
            @_flushSessionBuffers()
        @tunnel.on "data",(data)=>
            json = null
            try
                json = JSON.parse(data.toString())
            catch e
                # something wrong when transfering
                # data or even worse
                # sorry, but we can do nothing about it
                @emit "error",new Error "Invalid JsonParse"+e
                return
            @_handleResponse(json)
            
    close:()->
        @isClose = true
        if @tunnel
            @tunnel.close(true)
        @tunnel = null
    initRemoteConfig:(config)->
        # @remoteKey = config.key
        if @noRemoteConfig
            Log.log "config:no remote config,ignore recieved remote config"
            return
        for call in config.publicCalls
            @buildRemoteCall(call,true)
        @emit "config"
    describe:(name)->
        if typeof @[name] is "function" and @[name].info
            return @[name].info
        return null
    _handleResponse:(rsp)->
        if rsp.type is "config"
            rsp.fromServer = true
            @initRemoteConfig(rsp)
            return
        for session,index in @_callSessions
            if session.ticket is rsp.ticket
                @_callSessions.splice(index,1)
                if rsp.error and rsp.error.name and rsp.error.message
                    name = rsp.error.name 
                    rsp.error = new Error rsp.error.message
                    rsp.name = name
                session.callback(rsp.error,rsp.data)
                return
        Log.warn "Unexpect response ticket",rsp
        Log.warn "Maybe someone else is using this tunnel"
    
    _removeSessionFromBuffer:(session)->
        for _session,index in @_callSessionBuffers
            if session is _session
                @_callSessionBuffers.splice(index,1)
                return true
        return false
    _removeSession:(session)->
        for _session,index in @_callSessions
            if session is _session
                @_callSessions.splice(index,1)
                return true
        return false
    _tryReconnect:()->
        # try to ask tunnel to reconnect
        # if failed clear buffers

        # not connecting and tunnel is set
        if @_isReconnect or not @tunnel
            return
        # when ask reconnect the
        # tunnel should return false if it's "IMPOSIBLE"
        # to reconnect
        
        result = @tunnel.reconnect()
        if not result
            # tunnel is imposibale to reconnect
            @clearSessionBuffers(new Error("Connection Fail"))
            @emit "close"
            return
        else
            @_isReconnect = true
        # if can't reconnect
        # use an new tunnel
    _flushSessionBuffers:()->
        for session in @_callSessionBuffers
            @_invokeRemoteCall(session)
        @_callSessionBuffers.length = 0
    clearSessions:(err)->
        for session in @_callSessions
            session.callback(err)
        for session in @_callSessionBuffers
            session.callback(err)
        @_callSessionBuffers = []
        @_callSessions = []
    buildRemoteCall:(info,fromServer)->
        # info
        # name:rpcName
        # count:param count
        console.assert typeof info.count is "number","invalid rpc info count"
        console.assert info.name,"invalid rpc name"
        if @[info.name]
            if not fromServer
                Log.warn "duplicate remote call"
            else
                Log.log "reconfig from server"
        rpc = (args...)->
            callback = null
            # check call count
            if args.length is info.count+1
                callback = args.pop()
            else if args.length is info.count
                callback = null
            else
                Log.error "Expect parameters of",info.count
                throw new Error "Unmatched parameter"
            if callback isnt null and typeof callback isnt "function"
                Log.error "Invalid Callback",callback
                throw new Error "Invalid Callback"
            for arg in args 
                if typeof arg is "function"
                    Log.error args,arg,"can't be serializable"
                    throw new Error "Unserializable Arguments"
            # other type just resigned to JSON.stringify
            # good luck!
            session = new RPCSession(info.name,args,callback)
            @_invokeRemoteCall(session)
        rpc.info = info
        @[info.name] = rpc
    
    _invokeRemoteCall:(session)->
        
        setTimeout (()=>
            session.callback new Error "Timeout"
            # may be in session buffer
            @_removeSessionFromBuffer(session)
            # may be sent
            @_removeSession(session)
            ),@timeout
        if not @tunnel or not @tunnel.isReady
            @_callSessionBuffers.push session
            return
        @_callSessions.push session
        @tunnel.write session.serialize()
RPCInterface.configTimeout = 1000 * 5
RPCInterface.create = (info,callback)->
    # info
    # host,port for socket-like connection
    # autoConfig,return on recieve server config
    type = info.type or "ws"
    tunnel = Tunnel.create(type,info)
    inf = new RPCInterface(tunnel)
    if info.noRemoteConfig
        inf.noRemoteConfig = true
    if info.autoConfig
        done =false
        inf.on "close",()->
            if not done
                done = true 
                callback new Error "Connection Closed"
        inf.on "config",()->
            if not done
                done = true
                callback null,inf
        inf.on "error",(err)->
            if not done
                done = true
                callback new Error err
        setTimeout (()->
            if not done
                done = true
                callback new Error "Timeout"
            ),RPCInterface.configTimeout
    return inf
exports.RPCInterface = RPCInterface