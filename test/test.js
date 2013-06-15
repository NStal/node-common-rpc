// Generated by CoffeeScript 1.6.3
(function() {
  var RPCInterface, RPCServer, Static, WebSocketGateway, rpc;

  rpc = require("../lib/rpc.coffee");

  rpc.Log.verboseLevel = 3;

  WebSocketGateway = rpc.WebSocketGateway;

  RPCServer = rpc.RPCServer;

  RPCInterface = rpc.RPCInterface;

  Static = {};

  describe("Basic Test", function() {
    it("create server", function(done) {
      Static.server = new RPCServer(new WebSocketGateway(31023));
      Static.server.serve({
        add: function(a, b, callback) {
          return callback(null, a + b);
        },
        doTimeout5s: function(callback) {
          return setTimeout((function() {
            return callback(null, true);
          }), 1000 * 5);
        },
        doTimeout2s: function(callback) {
          return setTimeout((function() {
            return callback(null, true);
          }), 1000 * 2);
        },
        giveError: function(callback) {
          return callback("Error");
        }
      });
      return Static.server.once("ready", function() {
        return done();
      });
    });
    it("create auto config interface", function(done) {
      return Static.autoInf = RPCInterface.create({
        type: "ws",
        host: "localhost",
        port: 31023,
        autoConfig: true
      }, function(err, inf) {
        if (err) {
          done(err);
        }
        Static.autoInf = inf;
        return done();
      });
    });
    it("test normal add rpc", function(done) {
      return Static.autoInf.add(5, 6, function(err, result) {
        console.log("add 5 6 result", err, result);
        if (err) {
          throw err;
          return;
        }
        return done();
      });
    });
    it("test error", function(done) {
      return Static.autoInf.giveError(function(err, result) {
        console.log("giveError result", err, result);
        if (err) {
          done();
          return;
        }
        return done(new Error("Didnt give an error"));
      });
    });
    it("test timeout 1s", function(done) {
      var OK;
      Static.autoInf.timeout = 1 * 1000;
      OK = false;
      Static.autoInf.doTimeout2s(function(err, result) {
        if (!err || err.message !== "Timeout") {
          throw new Error("Not Timeout");
          return;
        }
        return OK = true;
      });
      return setTimeout((function() {
        if (OK) {
          return done();
        } else {
          throw new Error("Server timeout2s call not return");
        }
      }), 3000);
    });
    it("close auto config interface", function(done) {
      Static.autoInf.once("close", function() {
        return done();
      });
      return Static.autoInf.close();
    });
    it("create non auto index interface", function(done) {
      var inf;
      inf = RPCInterface.create({
        type: "ws",
        host: "localhost",
        port: 31023,
        autoConfig: true
      }, function(err, inf) {});
      inf.initRemoteConfig({
        publicCalls: [
          {
            name: "add",
            count: 2
          }
        ]
      });
      return inf.add(100, 200, function(err, data) {
        if (err || !data) {
          throw new Error;
        }
        return done();
      });
    });
    it("test gateway close", function(done) {
      Static.server.gateway.once("close", function() {
        return done();
      });
      return Static.server.close();
    });
    it("reconnect after server close should flush buffers until it open", function(done) {
      var inf;
      inf = RPCInterface.create({
        type: "ws",
        host: "localhost",
        port: 31023
      });
      inf.timeout = 1 * 5000;
      inf.initRemoteConfig({
        publicCalls: [
          {
            name: "add",
            count: 2
          }
        ]
      });
      inf.add(100, 200, function(err, data) {
        if (err || !data) {
          throw new Error;
        }
        return done();
      });
      return setTimeout((function() {
        return Static.server.setGateway(new WebSocketGateway(31023));
      }), 100);
    });
    return it("reconnect after server close should throw timeout", function(done) {
      var inf;
      Static.server.gateway.close();
      inf = RPCInterface.create({
        type: "ws",
        host: "localhost",
        port: 31023
      });
      inf.timeout = 1 * 1000;
      inf.initRemoteConfig({
        publicCalls: [
          {
            name: "add",
            count: 2
          }
        ]
      });
      return inf.add(100, 200, function(err, data) {
        if (err && err.message === "Timeout") {
          done();
          return;
        }
        throw new Error;
      });
    });
  });

  process.on("exit", function() {
    console.log("exit");
    return process.exit(0);
  });

  process.on("SIGINT", function() {
    console.log("int");
    return process.exit(0);
  });

  process.on("SIGTERM", function() {
    console.log("term!");
    return process.exit(0);
  });

}).call(this);
