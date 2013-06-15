rpc = require "../lib/rpc.coffee"
rpc.Log.verboseLevel = 3
WebSocketGateway = rpc.WebSocketGateway
RPCServer = rpc.RPCServer
RPCInterface = rpc.RPCInterface
Static = {}
inf = RPCInterface.create {type:"ws",host:"localhost",port:31023}

inf.timeout = 1 * 3000
inf.initRemoteConfig {publicCalls:[{name:"add",count:2}]}
inf.add 100,200,(err,data)->
    console.error err,data
    if err or not data
        throw new Error
    done()
setTimeout (()->
    Static.server = new RPCServer(new WebSocketGateway(31023))
    ),500
