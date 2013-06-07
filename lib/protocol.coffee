require("coffee-script")
exports.serializeCallInfo = (name,count)->
    return {name:name,count:count}
exports.serializeCallRequest = (name,args)->
    return {name:name,args:args}
    