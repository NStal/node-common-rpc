require("coffee-script")
events = require "events"
RPCInterface = (require "./interface.coffee").RPCInterface;
Tunnel = (require "./tunnel.coffee").Tunnel;
Gateway = (require "./gateway.coffee").Gateway;
WebSocketGateway = (require "./gateway.coffee").WebSocketGateway;
Log = require "./log.coffee"
class RPCServer extends events.EventEmitter
    constructor:(gateway)->
        @publicCalls = []
        @clients = []
        if gateway
            @setGateway(gateway)
    setGateway:(gateway)->
        if @gateway
            @gateway.close()
        @gateway = gateway
        @gateway.on "ready",()=>
            @isReady = true
            @emit "ready"
        @gateway.on "connection",(tunnel)=>
            try
                @addClient(tunnel)
            catch e
                Log.error "fail to add client:",e
                Log.error "tunnel:",tunnel
        @gateway.on "error",(err)=>
            @emit "error",err
    serve:(obj)->
        for item of obj
            if typeof obj[item] is "function"
                if @[item]
                    throw new Error "RPCServer has property "+item
                @[item] = obj[item]
                @declare(item)
    declare:(name)->
        if typeof @[name] isnt "function"
            throw new Error ["declare",name,"isnt function"].join(" ")
        @publicCalls.push name
    createConfig:()->
        config = {publicCalls:[],type:"config"}
        for name in @publicCalls
            console.assert typeof @[name] is "function"
            config.publicCalls.push {name:name,count:@[name].length-1}

        return config
    close:()->
        @gateway.close()
        @clients = []
    handleRequest:(req,client)->
        if req.name not in @publicCalls
            client.write @createResponseString({error:"Invalid Callback",ticket:req.ticket})
            return
        if typeof @[req.name] isnt "function"
            client.write @createResponseString({error:"Server Error",ticket:req.ticket})
            return
        req.args = req.args or []
        if @[req.name].length isnt req.args.length + 1
            client.write @createResponseString({error:"Invalid Parameter",ticket:req.ticket})
            return
        req.args.push (err,data)=>
            client.write @createResponseString({error:err,data:data,ticket:req.ticket})
        @[req.name].apply this,req.args
    createResponseString:(data)->
        rsp = {error:data.error,ticket:data.ticket,data:data.data}
        return JSON.stringify(rsp)
    addClient:(client)->
        @clients.push client
        config = @createConfig()
        client.write JSON.stringify config
        client.isRemoved = false
        client.on "data",(data)=>
            json = null
            if client.isRemoved
                return
            try
                json = JSON.parse(data)
                @handleRequest(json,client)
            catch e
                Log.error "Recieve Invalid Data From Client",client.toString(),data.toString(),e
                return
        
        client.on "error",(err)=>
            if client.isRemoved
                return
            @emit "error",err
        client.on "close",()=>
            @removeClient(client)
    removeClient:(client)->
        if client.isRemoved
            return true
        for item,index in @clients
            if item is client
                @clients.splice(index,1)
                client.isRemoved
                item.close()
                return true
        return false
            
exports.RPCServer = RPCServer
exports.RPCInterface = RPCInterface
exports.Tunnel = Tunnel
exports.Gateway = Gateway
exports.WebSocketGateway = WebSocketGateway
exports.Log = Log