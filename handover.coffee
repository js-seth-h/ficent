# util = require 'util'
debug =  require('debug')('handover')

# Error Jump 기능
# 직/병렬 동시 서술
# + 가변인수 = arity를 기준으로하여 처리가능.
# + 배열 병렬- > context로 Array만 들어올수있을까? 가능성은..? 있다. 누산기로 쓸수도 있고..
#   고로 배열 병렬은 다른 시작점을 걸고 연결할수 있게 해보자.
#   로직의 재활용을 위한것이니 로직은 고정이다. 그러면, 입력을 억지로 맞추는것보다 그대로 넘기는게 낫다. 
# + retry -> 이건 확실히 다른 시작점을 걸어야 한다.
#     유틸리티 형태도 될듯...
# + waterfall 형태에 대해서... ErrorJump나 직병렬 동시가 되려면 waterfall형태는 못한다.. 
#     대신, 함수연쇄(fnCompose) 넣어서 waterfall형태의 실행을 가능하게 하자.

_toString = Object.prototype.toString
_isArray = Array.isArray or (obj) ->
  _toString.call(obj) is "[object Array]"

findFnByArity = (fnFlows, arity)->
  debug 'findFnByArity  ', arity     
  inx = 0 
  for fn in fnFlows
    # console.log 'fn.length', fn.length
    if not _isArray(fn) and fn.length is arity
      return inx
    inx++
  return -1

fnForkJoin = (handsToFork)->
  debug 'fnForkJoin', handsToFork.length
  return (ctxArgs..., outCallback)->
    endstate = new Array()
    errors = new Array()
    handsToFork.forEach (task, index)->
      endstate[index] = false
      errors[index] = undefined
 
    checkAllEnd =()->
      return unless endstate.indexOf(false) is -1  
      debug 'fnForkJoin errors - ', errors
      errs = errors.filter (err)-> err 
      debug 'errs = ', errs
      # errors = undefined unless hasErr
      error = undefined
      if errs.length > 0
        error = errs[0]
        error.errors = errors

      debug 'fnForkJoin finished - ', error
      outCallback(error) 


    handsToFork.forEach (task, index)-> 
      debug 'Parallel run  ', index
      fnDone = (err)->
        debug 'Parallel done ', index
        errors[index] = err
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
      inx = findFnByArity(next_hands, arityOfErrorHandler) if err # find Error Jump   
      return callOutNext(err) if not next_hands[inx]? 
      debug 'inx of hand to run = ', inx     

      handToRun = next_hands[inx]
      handsOthers = next_hands[inx + 1 ..]

      if _isArray handToRun 
        handToRun = fnForkJoin handToRun


      fnNext = mkNext(handsOthers)
      argsToCall = ctxArgs.concat fnNext 
      debug 'hand args = ', argsToCall
      if handToRun.length is arityOfErrorHandler
        argsToCall = [err].concat argsToCall        
      return handToRun.apply undefined, argsToCall 
      
  mkNext(hands)(null) 

runSIDM = (fn, inputs, outCallback)-> 
  endstate = new Array()
  errors = new Array()
  inputs.forEach (input, index)->
    endstate[index] = false
    errors[index] = undefined

  checkAllEnd =()->
    return unless endstate.indexOf(false) is -1  


    debug 'errs = ', errs
    # errors = undefined unless hasErr

    debug 'SIDM errors - ', errors
    errs = errors.filter (err)-> err 
    error = undefined
    if errs.length > 0
      error = errs[0]
      error.errors = errors
    debug 'SIDM finished - ', error
    outCallback(error, inputs) 




  inputs.forEach (args, index)->
    debug 'SIDM run  ', index
    fnDone = (err )->
      debug 'SIDM done ', index, args
      errors[index] = err
      endstate[index] =  true
      checkAllEnd()

    # debug ' typeof args, ',  (typeof args), args
    unless _isArray args
      args = [args]

    argsToCall = args.concat fnDone 
    debug  'argsToCall', argsToCall
    fn argsToCall...

fnRetry = (fn, tryLimit)->
  return (args..., outCallback)->
    debug 'fnRetry'
    tryCnt = 0
    fnDone = (err)->
      debug 'fnDone of fnRetry'
      tryCnt++
      if err and tryCnt < tryLimit
        fn argsToCall...
      else
        outCallback err
    argsToCall = args.concat fnDone 
    fn argsToCall...


callFirstFn = (funcArr, args, outCallback)->
  [fn, fns...] = funcArr
  fn args...,(err, output...)-> 
    return outCallback err if err
    return outCallback err, output... if fns.length is 0
    callFirstFn fns, output, outCallback # [err, output...]  

_compose = (functions...)->  
  return (args..., outCallback)-> 
    callFirstFn functions, args, outCallback



_map = (data, fn, outCallback)->
  errors = []
  results = []
  endstate = []

  checkAllEnd =()->
    return unless endstate.indexOf(false) is -1  
    debug 'fnForkJoin errors - ', errors
    errs = errors.filter (err)-> err 
    debug 'errs = ', errs
    # errors = undefined unless hasErr
    error = undefined
    if errs.length > 0
      error = errs[0]
      error.errors = errors

    debug 'fnForkJoin finished - ', error
    outCallback(error, results) 

  callFn = (inx, args...)-> 
    fn args..., (err, output)-> 
      errors[inx] = err
      results[inx] = output
      endstate[inx] = true
      checkAllEnd()
  
  if _isArray data
    for item, inx in data
      errors[inx] = null
      results[inx] = null
      endstate[inx] = false
    for item, inx in data
      callFn inx, item
  else
    inx = 0
    for own key, value of data
      errors[inx] = null
      results[inx] = null
      endstate[inx] = false
      inx++
    for own key, value of data
      callFn inx, key, value
      inx++
      # fn item, (err, output)->



handover = (hands)-> 
  fn = (args...)->
    fnHandover(hands, args...) 
  fn.parallel = (args...)->
    runSIDM(fn, args...)
  fn.fnRetry = (tryLimit)->
    fnRetry(fn,tryLimit)
  return fn 

handover.hands = {}  
handover.fnForkJoin = fnForkJoin
handover.map = _map
handover.compose = _compose
module.exports = exports = handover