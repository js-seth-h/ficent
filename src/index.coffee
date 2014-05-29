# util = require 'util'
debug =  require('debug')('flyway')

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
_isError = (obj)-> 
  _toString.call(obj) is "[object Error]"
 

cutFlowsByArity = (fnFlows, arity)->
  # debug 'cutFlowsByArity  ', arity     
  for fn, inx in fnFlows
    # debug 'fn.length', fn.length
    if not _isArray(fn) and fn.length is arity
      return fnFlows[inx..] 
  return []

joinAsyncFns = (fns, outCallback)->
  l = fns.length 
  errors = [0...l].map ()-> undefined
  results = errors.map ()-> undefined
  finished = errors.map ()-> false

  # debug 'errors', errors
  # debug 'results', results
  # debug 'finished', finished

  checkJoin = ()->
    return unless finished.every (v)-> v
    errs = errors.filter (err)-> err 
    # debug 'errs = ', errs
    # errors = undefined unless hasErr
    error = undefined
    if errs.length > 0
      error = errs[0]
      error.errors = errors
    # debug 'checkJoin - ', error
    outCallback(error, results) 
  
  for fn, inx in fns  
    do (inx)->
      # debug 'call fork', inx 
      fn (err, output...)->
        output = output[0] if output.length is 1
        finished[inx] = true
        results[inx] = output
        errors[inx] = err 
        checkJoin()
 

runForkFlow = (fnFlows, args, outCallback)->
  fns = fnFlows.map (flow)->  
    return (next)-> 
      flow = [flow] unless _isArray flow
      runFlow flow, null, args, next 
  joinAsyncFns fns, outCallback


runFlow = (fnFlows, err, args, outCallback)->
  errorHandlerArity = args.length + 2 # include err, callback
  if err
    fnFlows = cutFlowsByArity(fnFlows, errorHandlerArity)    
 
  return outCallback err, args... if fnFlows.length is 0 
  
  [fn, fns...] = fnFlows  
  if _isArray fn
    fnArr = fn
    fn = (args..., next)-> runForkFlow fnArr, args, next 

  argsToCall = args
  argsToCall = [err].concat args if fn.length is errorHandlerArity

  fn argsToCall..., (err)->
    runFlow fns, err, args, outCallback 
  

runForkChain = (fnFlows, args, outCallback)->
  fns = fnFlows.map (flow)->  
    return (next)-> 
      flow = [flow] unless _isArray flow
      runChain flow, args, next 
  joinAsyncFns fns, outCallback

runChain = ( fnFlows, args, outCallback)->
  debug 'runChain', fnFlows, args
  [fn, fns...] = fnFlows  
  if _isArray fn
    fnArr = fn
    fn = (args..., next)-> runForkChain fnArr, args, next 
  fn args..., (err, output...)->
    return outCallback err if err   
    return outCallback null, output... if fns.length is 0 
    runChain fns, output, outCallback 
 


runReduce = (data, fn, memo, outCallback)->
  # debug 'runReduce', arguments
  return outCallback null, memo if data.length is 0
  [head, others...] = data
  fn memo, head, (err, newMemo)->
    return outCallback err if err
    runReduce others, fn, newMemo, outCallback

runSeries = (data, fn, results, outCallback)->
  # debug 'runSeries', arguments
  return outCallback null, results if data.length is 0
  [head, others...] = data
  fn head, (err, output)->
    return outCallback err if err
    results.push output
    runSeries others, fn, results, outCallback

_series = (fn)->
  return (data, outCallback)-> 
    runSeries data, fn, [], outCallback

_map = (fn)->
  return (data, outCallback)->
#     _map arr, fn, next
# _map = (data, fn, outCallback)->  
    if _isArray data 
      fns = data.map (args)->  
        args = [args] unless _isArray args
        return (next)->   
          fn args..., next 
      joinAsyncFns fns, outCallback
    else
      fns = []
      result = {}
      for own key, value of data
        do (key, value)->
          fns.push (next)->
            fn key, value, (err, output...)->
              output = output[0] if output.length is 1
              result[key] = output
              next err, output...
      joinAsyncFns fns, (err, results)-> 
        outCallback err, result
   
      
_reduce = (memo, fn)->
  return (data, outCallback)->
    runReduce data, fn, memo, outCallback


_retry = (tryLimit, fn)->
  return (args..., outCallback)->
    # debug 'fnRetry'
    tryCnt = 0
    fnDone = (err, output...)->
      # debug 'fnDone of fnRetry'
      tryCnt++
      if err and tryCnt < tryLimit
        fn argsToCall...
      else
        outCallback err, output...
    argsToCall = args.concat fnDone 
    fn argsToCall...
 

_chain = (chainFns)->
  return (args..., outCallback)-> 
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = ()->
    runChain chainFns, args, outCallback

_flow = (flowFns)->
  return (args..., outCallback)->  
    first = args[0]
    err = null
    # debug 'first', first
    if first is null or first is undefined or _isError first
      err = args.shift()
      # debug 'set err = ', err
  
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = ()->

    # debug '_flow arity = ', args.length
    # debug '_flow err= ', err
    runFlow flowFns, err, args, outCallback



_flow.run = (args..., fnFlows)->
  _flow(fnFlows) args...
 
_chain.run = (args..., fnFlows)->
  _chain(fnFlows) args...
 
flyway = _flow
flyway.fn = {}
flyway.makeFn = {}

# flyway.mk = 
  # retry: _retry
  # map : _map
flyway.flow = _flow
# flyway.fnForkJoin = fnForkJoin
flyway.chain = _chain
# flyway.compose = _compose
flyway.map = _map
flyway.each = _map

flyway.reduce = _reduce

flyway.retry = _retry
flyway.series = _series



module.exports = exports = flyway