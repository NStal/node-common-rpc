rpc = require "../lib/rpc.coffee"
rpc.Log.verboseLevel = 3
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
            doTimeout2s:(callback)->
                setTimeout (()->
                    callback(null,true)
                    ),1000 * 2
            giveError:(callback)->
                callback "Error"
            giveComplexJsonObject:(callback)->
                callback null,{a:5,b:"char",c:[],d:null,e:[1],f:["1"],g:{number:1,object:{number:1},array:[{number:1}]}}
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
            if err
                throw err
                return
            done()
    it "test comlex json response",(done)->
        Static.autoInf.giveComplexJsonObject (err,result)->
            console.assert result.a is 5
            console.assert result.b is "char"
            console.assert result.c instanceof Array
            console.assert result.c.length is 0
            console.assert result.d is null
            console.assert result.e instanceof Array
            console.assert result.e.length is 1
            console.assert result.e[0] is 1
            console.assert result.f instanceof Array
            console.assert result.f.length is 1
            console.assert result.f[0] is "1"
            #g:{number:1,object:{number:1},array:[{number:1}]}
            console.assert result.g
            console.assert result.g.number is 1
            console.assert result.g.object
            
            console.assert result.g.object.number is 1
            console.assert result.g.array
            console.assert result.g.array instanceof Array
            console.assert result.g.array.length is 1
            console.assert result.g.array[0].number is 1
            
            done()
    it "test error",(done)-> 
        Static.autoInf.giveError (err,result)->
            if err
                done()
                return
            done(new Error "Didnt give an error")
    it "test timeout 1s",(done)->
        Static.autoInf.timeout = 1 * 1000
        OK = false
        Static.autoInf.doTimeout2s (err,result)->
            if not err or err.message isnt "Timeout"
                throw new Error "Not Timeout"
                return
            OK = true
        setTimeout (()->
            if OK
                done()
            else
                throw new Error "Server timeout2s call not return"
            ),3000
    it "close auto config interface",(done)->
        Static.autoInf.once "close",()->
            done()
        Static.autoInf.close()
    it "create non auto index interface",(done)->
        Static.inf = RPCInterface.create {type:"ws",host:"localhost",port:31023,autoConfig:true},(err,inf)->
        inf = Static.inf
        inf.initRemoteConfig {publicCalls:[{name:"add",count:2}]}
        inf.add 100,200,(err,data)->
            if err or not data
                throw new Error
            done()
    it "close none auto index interface",(done)->
        Static.inf.once "close",()->
            Static.inf = null
            done()
        Static.inf.close()
    it "test gateway close",(done)->
        Static.server.gateway.once "close",()->
            done()
        Static.server.close() 
    it "interface should save buffers and flush them until it open",(done)->
        inf = RPCInterface.create {type:"ws",host:"localhost",port:31023}
        
        inf.timeout = 1 * 5000
        inf.initRemoteConfig {publicCalls:[{name:"add",count:2}]}
        inf.add 100,200,(err,data)->
            console.log err,data
            if err or not data
                throw new Error
            done()
        setTimeout (()->
            Static.server.setGateway(new WebSocketGateway(31023)) 
            ),100
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


