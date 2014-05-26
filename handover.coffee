util = require 'util'
debug =  require('debug')('handover')

# Error Jump 기능
# 직/병렬 동시 서술
# + 가변인수 = arity를 기준으로하여 처리가능.
# + 배열 병렬- > context로 Array만 들어올수있을까? 가능성은..? 있다. 누산기로 쓸수도 있고..
#   고로 배열 병렬은 다른 시작점을 걸고 연결할수 있게 해보자.
#   로직의 재활용을 위한것이니 로직은 고정이다. 그러면, 입력을 억지로 맞추는것보다 그대로 넘기는게 낫다. 
# + retry -> 이건 확실히 다른 시작점을 걸어야 한다.


findHandByArity = (hands, arity)->
  debug 'findHandByArity  ', arity     
  inx = 0 
  for task in hands
    # console.log 'task.length', task.length
    if not util.isArray(task) and task.length is arity
      return inx
    inx++
  return -1

mkForkJoin = (handsToFork)->
  debug 'mkForkJoin', handsToFork.length
  return (ctxArgs..., outCallback)->
    endstate = new Array()
    result = new Array()
    handsToFork.forEach (task, index)->
      endstate[index] = false
      result[index] = undefined

    checkAllEnd =()->
      if endstate.indexOf(false) is -1            
        err = null
        for val in result
          if val
            err = val
            break 
        outCallback(err) 

    handsToFork.forEach (task, index)-> 
      debug 'Parallel run  ', index
      fnDone = (err)->
        debug 'Parallel done ', index
        result[index] = err
        endstate[index] =  true
        checkAllEnd()

      argsToCall = ctxArgs.concat fnDone 
      task.apply undefined, argsToCall


fnHandover = (hands, ctxArgs..., outCallback)->
  debug 'fnHandover', arguments
  if typeof outCallback isnt 'function'
    ctxArgs.push outCallback
    outCallback = null 

  arity = ctxArgs.length + 1 # include callback
  arityOfErrorHandler = arity + 1
  debug 'ctxArgs', ctxArgs 
  debug 'outCallback', typeof outCallback 
  debug 'arity of hand = ', arity


  callOutNext = (err)->
    debug 'callOutNext - err = ', err
    if outCallback
      argsToCall = [err].concat ctxArgs
      debug 'callOutNext - arg = ', argsToCall    
      outCallback.apply undefined, argsToCall

  mkNext = (next_hands)->
    return (err)-> 
      debug 'next of handover', err
      return callOutNext err if next_hands is undefined
      inx = 0
      inx = findHandByArity(next_hands, arityOfErrorHandler) if err # find Error Jump   
      return callOutNext(err) if not next_hands[inx]? 
      debug 'inx of hand to run = ', inx     

      handToRun = next_hands[inx]
      handsOthers = next_hands[inx + 1 ..]

      if util.isArray handToRun 
        handToRun = mkForkJoin handToRun


      fnNext = mkNext(handsOthers)
      argsToCall = ctxArgs.concat fnNext 
      debug 'hand args = ', argsToCall
      if handToRun.length is arityOfErrorHandler
        argsToCall = [err].concat argsToCall        
      return handToRun.apply undefined, argsToCall 
      
  mkNext(hands)(null) 

fnSIDM = (fn, inputs, outCallback)-> 
  endstate = new Array()
  result = new Array()
  inputs.forEach (input, index)->
    endstate[index] = false
    result[index] = undefined

  checkAllEnd =()->
    if endstate.indexOf(false) is -1            
      err = null
      for val in result
        if val
          err = val
          break 
      debug 'SIDM finished - ', err
      outCallback(err, inputs) 

  inputs.forEach (args, index)->
    debug 'SIDM run  ', index
    fnDone = (err )->
      debug 'SIDM done ', index, args
      result[index] = err
      endstate[index] =  true
      checkAllEnd()

    # debug ' typeof args, ',  (typeof args), args
    unless util.isArray args
      args = [args]

    argsToCall = args.concat fnDone 
    debug  'argsToCall', argsToCall
    fn.apply undefined, argsToCall

fnRetry = (fn, tryLimit)->
  return (args..., outCallback)->
    debug 'fnRetry'
    tryCnt = 0
    fnDone = (err)->
      debug 'fnDone of fnRetry'
      tryCnt++
      if err and tryCnt < tryLimit
        fn.apply undefined, argsToCall
      else
        outCallback err
    argsToCall = args.concat fnDone 
    fn.apply undefined, argsToCall


handover = (hands)-> 
  fn = (args...)->
    fnHandover(hands, args...)
  fn.parallel = (args...)->
    fnSIDM(fn, args...)
  fn.retry = (tryLimit)->
    fnRetry(fn,tryLimit)
  return fn 

module.exports = exports = handover