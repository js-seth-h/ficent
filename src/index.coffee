# util = require 'util'
debug =  require('debug')('ficent')

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
 
_emptyFn = ()->

cutFlowsByArity = (fnFlows, arity)->
  debug 'cutFlowsByArity  ', arity     
  for fn, inx in fnFlows
    debug 'fn.length', fn.length
    if not _isArray(fn) and fn.length is arity
      return fnFlows[inx..] 
  return []

unifyErrors = (errors)->
  errs = errors.filter (err)-> err 
  error = undefined
  if errs.length > 0
    error = errs[0]
    error.errors = errors
  return error  
 
runFork = (fnFlows, args, outCallback)-> 
  join = ficent.join()
  fnFlows.forEach (flow)->
    flow args..., join.in()
  join.out outCallback 

runFlow = (fnFlows, err, args, outCallback)->
  debug 'runFlow start', err, args
  errorHandlerArity = args.length + 2 # include err, callback
  if err
    fnFlows = cutFlowsByArity(fnFlows, errorHandlerArity)    
  
  return outCallback err, args... if fnFlows.length is 0 
  
  [fn, fns...] = fnFlows  

  if _isArray fn 
    fnArr = fn.map (flow)->  
      return _fn.flow flow if _isArray flow 
      return flow

    fn = (args..., next)-> runFork fnArr, args, next 

  argsToCall = args
  argsToCall = [err].concat args if fn.length is errorHandlerArity

  fn argsToCall..., (err)->
    debug 'callback of runFlow, err = ', err
    runFlow fns, err, args, outCallback  
    
runChain = ( fnFlows, args, outCallback)->
  debug 'runChain', fnFlows, args
  [fn, fns...] = fnFlows  
  if _isArray fn
    fnArr = fn.map (flow)->  
      return _fn.chain flow if _isArray flow 
      return flow

    fn = (args..., next)-> runFork fnArr, args, next 
  fn args..., (err, output...)->
    return outCallback err if err   
    return outCallback null, output... if fns.length is 0 
    runChain fns, output, outCallback 
 


runReduce = (data, fn, memo, outCallback)->
  debug 'runReduce', arguments
  return outCallback null, memo if data.length is 0
  [head, others...] = data
  fn memo, head, (err, newMemo)->
    return outCallback err if err
    runReduce others, fn, newMemo, outCallback

runSeries = (data, fn, results, outCallback)->
  debug 'runSeries', arguments
  return outCallback null, results if data.length is 0
  [head, others...] = data
  fn head, (err, output)->
    return outCallback err if err
    results.push output
    runSeries others, fn, results, outCallback

_fn = {}
_fn.join = (strict = true)->
  errors = []
  results = []
  finished = [] 
  outFn = undefined
  resultsObj = {}
  callOut = ()->   
    allFnished = finished.every (v)-> v
    if allFnished and outFn
      err = unifyErrors errors
      results.obj = resultsObj
      outFn err, results

  fns = 
    in :(varName = null)->
      varName = varName
      inx = errors.length
      errors.push undefined
      results.push undefined
      finished.push false

      if varName
        resultsObj[varName] = resultsObj[varName]  ||  [] 
        varInx = results.length
        resultsObj[varName].push undefined
      return (err, values...)->
        throw new Error 'should call `callback` once' if finished[inx] and strict
        errors[inx] = err
        values = values[0] if values.length is 1
        results[inx] = values
        if varName
          resultsObj[varName][inx] = values
        finished[inx] = true
        callOut()
    out: (fn)->
      outFn = fn
      callOut()
  return fns


_fn.series = (fn)->
  return (data, outCallback)-> 
    runSeries data, fn, [], outCallback

_fn.map = (fn)->
  return (data, outCallback)->
#     _map arr, fn, next
# _map = (data, fn, outCallback)->  
    join = ficent.join()
    if _isArray data 
      data.forEach (args)->
        args = [args] unless _isArray args
        fn args..., join.in()

      # fns = data.map (args)->  
      #   args = [args] unless _isArray args
      #   return (next)->   
      #     fn args..., next 
      # joinAsyncFns fns, outCallback
    else
      for own key, value of data
        fn key, value, join.in(key)

      _outCallback = outCallback
      outCallback= (err, results, next)->
        debug 'remapper out = ', results
        next err if err
        # out = {}
        # for own key, value of data
          # out[key.toString()] = results[key.toString()][0]
        _outCallback null, results.obj

    join.out outCallback

      # fns = []
      # result = {}
      # for own key, value of data
      #   do (key, value)->
      #     fns.push (next)->
      #       fn key, value, (err, output...)->
      #         output = output[0] if output.length is 1
      #         result[key] = output
      #         next err, output...
      # joinAsyncFns fns, (err, results)-> 
      #   outCallback err, result
   
      
_fn.reduce = (memo, fn)->
  return (data, outCallback)->
    runReduce data, fn, memo, outCallback


_fn.retry = (tryLimit, fn)->
  return (args..., outCallback)->
    debug 'fnRetry'
    tryCnt = 0
    fnDone = (err, output...)->
      debug 'fnDone of fnRetry'
      tryCnt++
      if err and tryCnt < tryLimit
        fn argsToCall...
      else
        outCallback err, output...
    argsToCall = args.concat fnDone 
    fn argsToCall...
_fn.do = (args..., fn)->
  debug 'do  with ', 'args=', args, 'fn=', fn
  fn args...
_fn.delay = (msec, fn)->
  return (args...)->
    setTimeout ()->
      fn args...
    , msec
# _fn.delay.run = (args..., msec, fn)->
#   _fn.delay(msec, fn) args...

_fn.wrap = (preFns,postFns)->
  preFns = [preFns] unless _isArray preFns
  postFns = [postFns] unless _isArray postFns
  return (inFns)->
    inFns = [inFns] unless _isArray inFns
    return _fn.flow [preFns..., inFns..., postFns...]

_fn.fork = (flowFns)->
  return (args..., outCallback)->      
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = ()-> 
    runFork flowFns, args, outCallback

    
_fn.chain = (chainFns)->
  return (args..., outCallback)-> 
    if outCallback and typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = undefined
    unless outCallback
      outCallback = _emptyFn
    runChain chainFns, args, outCallback

_fn.flow = (flowFns)->
  return (args..., outCallback)->  

    first = args[0]
    err = null
    # debug 'first', first
    if first is null or first is undefined or _isError first
      err = args.shift()
      debug 'set err = ', err
  
    if outCallback and typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = undefined
    unless outCallback
      outCallback = _emptyFn

    # debug '_fn.flow arity = ', args.length
    debug '_fn.flow ', 'err =',err, 'args=', args, 'outCallback=', outCallback , '<--', arguments
    runFlow flowFns, err, args, outCallback


_fn.flow.run = (args..., fnFlows)-> 
  # _fn.flow(fnFlows) args..., _emptyFn
  _fn.do args..., _emptyFn, _fn.flow fnFlows
_fn.chain.run = (args..., fnFlows)-> 
  # _fn.chain(fnFlows) args..., _emptyFn
  _fn.do args..., _emptyFn, _fn.chain fnFlows

ficent = _fn.flow
# ficent.fn = {}
# ficent.mkFn = {}



# 함수 2개를 붙이는 방법으로 Conext(Flow)와  값전달(Chain)이 있다.
 
# ficent.mk = 
  # retry: _retry
  # map : _map
ficent.flow = _fn.flow
# ficent.fnForkJoin = fnForkJoin
ficent.chain = _fn.chain
# ficent.compose = _compose


# 다중화(병렬 실행)에는, 입력을 다중화하거나, 함수를 다중화 할수 있다.
ficent.map = _fn.map
ficent.fork = _fn.fork

ficent.each = _fn.map

# 다중화된 결과를 합치는 건 리듀스 뿐...
ficent.reduce = _fn.reduce

# 다중 입력에 대한 직렬 수행.
ficent.series = _fn.series
# 다수 함수에 대한 직렬 수행은 flow나  chain에서 가능하다.
#

# 함수를 수정할수 있다. 
# 반복
ficent.retry = _fn.retry
# 앞뒤로 감싸기.
ficent.wrap = _fn.wrap


# ficent.callback = callback
ficent.join = _fn.join


ficent.delay = _fn.delay

ficent.do = _fn.do

module.exports = exports = ficent