require("coffee-script")
exports.verboseLevel = 3
exports.log = ()->
    if exports.verboseLevel <= 2
        return
    console.log.apply console,arguments
    
exports.error = ()->
    if exports.verboseLevel <= 0
        return
    console.error.apply console,arguments
exports.warn = ()->
    if not exports.verboseLevel <= 1
        return
    console.warn.apply console,arguments
