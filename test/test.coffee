rpc = require "../lib/rpc.coffee"
rpc.Log.verboseLevel = 0
WebSocketGateway = rpc.WebSocketGateway
RPCServer = rpc.RPCServer
RPCInterface = rpc.RPCInterface
Static = {}
describe "Basic Test",()->
    it "create server",(done)->
        Static.server = new RPCServer(new WebSocketGateway(31023))
        Static.server.serve {
            add:(a,b,callback)->
                callback null,a+b
            doTimeout5s:(callback)->
                setTimeout (()->
                    callback(null,true)
                    ),1000 * 5
            giveError:(callback)->
                callback "Error"
            }
        Static.server.once "ready",()->
            done()
    it "create auto config interface",(done)->
        Static.autoInf = RPCInterface.create {type:"ws",host:"localhost",port:31023,autoConfig:true},(err,inf)->
            if err
                done err
            Static.autoInf = inf
            done()
    it "test normal add rpc",(done)->
        Static.autoInf.add 5,6,(err,result)->
            console.log "add 5 6 result",err,result
            if err
                throw err
                return
            done()
    it "test error",(done)-> 
        Static.autoInf.giveError (err,result)->
            console.log "giveError result",err,result
            if err
                done()
                return
            done(new Error "Didnt give an error")
    it "test timeout 2s",(done)->
        Static.autoInf.timeout = 1 * 1000
        Static.autoInf.doTimeout5s (err,result)->
            if not err or err.message isnt "Timeout"
                throw new Error "Not Timeout"
                return
            done()
    it "create non auto index interface",(done)->
        inf = RPCInterface.create {type:"ws",host:"localhost",port:31023,autoConfig:true},(err,inf)->
        inf.initRemoteConfig {publicCalls:[{name:"add",count:2}]}
        inf.add 100,200,(err,data)->
            if err or not data
                throw new Error
            done()
    it "reconnect after server close should flush buffers until it open",(done)->
        Static.server.gateway.close()
        inf = RPCInterface.create {type:"ws",host:"localhost",port:31023}
        
        inf.timeout = 1 * 1000
        inf.initRemoteConfig {publicCalls:[{name:"add",count:2}]}
        inf.add 100,200,(err,data)->
            if err or not data
                throw new Error
            done()
        Static.server.setGateway(new WebSocketGateway(31023))
    it "reconnect after server close should throw timeout",(done)->
        Static.server.gateway.close()
        inf = RPCInterface.create {type:"ws",host:"localhost",port:31023}
        
        inf.timeout = 1 * 1000
        inf.initRemoteConfig {publicCalls:[{name:"add",count:2}]}
        inf.add 100,200,(err,data)->
            if err and err.message is "Timeout"
                done()
                return
            throw new Error

process.on "exit",()->
    console.log "exit"
    process.exit(0)
process.on "SIGINT",()->
    console.log "int"
    process.exit(0)
process.on "SIGTERM",()->
    console.log "term!"
    process.exit(0)



