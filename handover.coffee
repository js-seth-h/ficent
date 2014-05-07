util = require 'util'
# debug =  require('debug')('handover')

runHandover = (req, res, hands, outNext)-> 
  res.data = res.data || {}
  cnt = 0 

  indexOfErrorHandler = (hands)->
    inx = 0
    for task in hands
      # console.log 'task.length', task.length
      if not util.isArray(task) and task.length is 4
        return inx
      inx++
    return -1

  mkParallel = (hands)->
    return (res, req, next)->
      
      endstate = new Array()
      result = new Array()

      hands.forEach (task, index)->
        endstate[index] = false
        task req, res, (err)->
          result[index] = err
          endstate[index] =  true
          if endstate.indexOf(false) is -1            
            err = null
            for val in result
              if val
                err = val
                break

            next(err) 

  mkNext = (next_hands)->
    return (err)-> 

      return outNext err if next_hands is undefined
      inx = 0
      inx = indexOfErrorHandler(next_hands) if err
      
      return outNext(err) if not next_hands[inx]? 

      nextFn = next_hands[inx]
      leftFn = next_hands[inx + 1 ..]

      if util.isArray nextFn 
        nextFn = mkParallel nextFn


      if nextFn.length is 4
        return nextFn err, req, res, mkNext(leftFn)
      return nextFn req, res, mkNext(leftFn) 

  mkNext(hands)(null) 

handover =
  hands : {}   
  make: (hands)->
    return (req,res, next)-> 
      runHandover req, res, hands, next

module.exports = exports = handover
