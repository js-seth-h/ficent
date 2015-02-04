# util = require 'util'
debug =  require('debug')('ficent')

# 라이브러리의 목적
# Error 핸들링에 초점 
# 직/병렬 동시 서술
# + 가변인수 = arity를 기준으로하여 처리가능.
# + 배열 병렬- > context로 Array만 들어올수있을까? 가능성은..? 있다. 누산기로 쓸수도 있고..
#   고로 배열 병렬은 다른 시작점을 걸고 연결할수 있게 해보자.
#   로직의 재활용을 위한것이니 로직은 고정이다. 그러면, 입력을 억지로 맞추는것보다 그대로 넘기는게 낫다. 
# + retry -> 이건 확실히 다른 시작점을 걸어야 한다.
#     유틸리티 형태도 될듯...
# + waterfall 과감히 삭제. 실효성이 많이 없다. 딱딱 떨어지는 경우도 거의 없고...
 
 
###
Error 처리가 핵심이다. 
그렇다면, Error Handler를 식별해야하는데, 1. Arity로 식별. 2. 고유 Property로 식별
Arity로 체크해도 무방 할듯하다. 어차피 입력 컨텍스트가 다르면, 무소용이니까..
다만, 가변 인수인 경우. -> 가변인수인 함수를 물리는 케이스가 있을까...?
그런데 이렇게 간다면...Async와 비슷해지지 않는가?
Arity가 다르면, 아규먼트도 다를테니, 별 문제가 없겠다.

다만, Ficent로 묶었는데, Ficent의 입력으로 애초부터 Err가 포함되어 오는 경우는?
달리, Null부터 오는 경우는...?
처음 호출될떄, 첫 인수가 Error인경우와 아닌경우 Base Arity를 조정하면 될까?
첫 인수가 NULL이거나 Err일때를 Callback 상황으로 가정하면 별 문제 없을듯...
일반적인 경우 첫 인수가 NULL인경우는 거의 없다..
###

_toString = Object.prototype.toString
_isArray = Array.isArray or (obj) ->
  _toString.call(obj) is "[object Array]"
_isError = (obj)-> 
  _toString.call(obj) is "[object Error]"
_isFunction = (obj)->
  return !!(obj && obj.constructor && obj.call && obj.apply);
_isObject = (obj)->
  return (!!obj && obj.constructor == Object);

_emptyFn = ()->

# cutFlowsByArity = (flowFns, arity)->
#   debug 'cutFlowsByArity  ', arity     
#   for fn, inx in flowFns
#     debug 'fn.length', fn.length
#     if not _isArray(fn) and fn.length is arity
#       return flowFns[inx..] 
#   return []

unifyErrors = (errors)->
  errs = errors.filter (err)-> err 
  error = undefined
  if errs.length > 0
    error = errs[0]
    error.errors = errors
  return error  
 
runFork = (forkingFns, args, outCallback)-> 
  join = ficent.join()
  forkingFns.forEach (flow)->
    cbIn = join.in()
    flow args..., cbIn

  join.out outCallback 

runFlow = (flowFns, startErr, args, outCallback)->
  fnInx = 0
  _toss = (err, tossArgs...)->
    _toss.params = tossArgs

    if flowFns.length is fnInx
      return outCallback err, args...

    fn = flowFns[fnInx]
    fnInx++
 
    if _isArray fn 
      fnArr = fn.map (flow)->  
        return _fn.flow flow if _isArray flow 
        return flow

      fn = (args..., next)-> runFork fnArr, args, next 


    isErrorHandlable = (fn.length is args.length + 2) # include err, callback
    if err and not isErrorHandlable
      return _toss err

    if isErrorHandlable
      fn err, args..., _toss
    else
      fn args..., _toss
      
  _toss.err = (fn)->
    return (errMayBe, args...)->
      # debug 'err-to', 'take', arguments
      if _isError errMayBe # Stupid Proof
        _toss errMayBe, args...
      try 
        fn errMayBe, args...
      catch err
        _toss err


  _toss startErr, args...
 




  # debug 'runFlow start', err, args
  # return outCallback err, args... if flowFns.length is 0   

  # errorHandlerArity = args.length + 2 # include err, callback
  # [fn, fns...] = flowFns  
  

  # _goNext = (err)->
  #     debug 'runFlow _goNext : err = ', err
  #     runFlow fns, err, args, outCallback  

  # if err
  #   return _goNext err if _isArray fn
  #   return _goNext err if fn.length isnt errorHandlerArity  

  #   # flowFns = cutFlowsByArity(flowFns, errorHandlerArity)    

  # if _isArray fn 
  #   fnArr = fn.map (flow)->  
  #     return _fn.flow flow if _isArray flow 
  #     return flow

  #   fn = (args..., next)-> runFork fnArr, args, next 

  # argsToCall = args
  # argsToCall = [err].concat args if fn.length is errorHandlerArity
  # try
  #   fn argsToCall..., _goNext
  # catch error
  #   _goNext error
     


_validating = (fns)->
  _valid = (arr)->
    for item in arr
      if _isArray item
        _valid item
      else
        throw new Error 'item of ficent flow must be function or array' unless _isFunction item

  _valid fns
 

_fn = {}
_fn.join = (strict = true)->
  errors = []
  results = []
  finished = [] 
  inFns = []
  outFn = undefined
  resultsObj = {}
  callOut = ()->   
    allFnished = finished.every (v)-> v
    if allFnished and outFn
      err = unifyErrors errors
      results.obj = resultsObj

      # debug '===================================================='
      for fn in inFns
        for own prop, value of fn
          debug 'outFn << ', prop, ':', value
          outFn[prop] = value

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
      _cb = (err, values...)->
        throw new Error 'should call `callback` once' if finished[inx] and strict
        errors[inx] = err
        values = values[0] if values.length is 1
        results[inx] = values
        if varName
          resultsObj[varName][inx] = values
        finished[inx] = true

        # for own prop, value of _cb
        #   outFn[prop] = value

        callOut()
      inFns.push _cb
      return _cb
    out: (fn)->
      outFn = fn
      callOut()
  return fns
  

_fn.fork = (forkingFns)->
  return (args..., outCallback)->      
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = ()-> 
    runFork forkingFns, args, outCallback
_fn.fork.do = (args..., forkingFns, outCallback)->
  f = _fn.fork forkingFns
  f args..., outCallback 


_fn.flow = (flowFns)->
  _validating flowFns
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

_fn.flow.do = (args..., flowFns)->
  fn = _fn.flow flowFns
  fn args...

#############################################
# 유틸리티 고계도 함수

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
    try 
      argsToCall = args.concat fnDone     
      fn argsToCall...
    catch error
      fnDone error

_fn.delay = (msec, fn)->
  return (args...)->
    setTimeout ()->
      fn args...
    , msec  

_fn.wrap = (preFns,postFns)->
  preFns = [preFns] unless _isArray preFns
  postFns = [postFns] unless _isArray postFns
  return (inFns)->
    inFns = [inFns] unless _isArray inFns
    return _fn.flow [preFns..., inFns..., postFns...]


ficent = (args..., flowFns)->
  _fn.flow flowFns


ficent.fn = _fn.flow
ficent.do = _fn.flow.do
ficent.flow = _fn.flow

# 같은 입력 요소에 대한 병렬 실행
ficent.fork = _fn.fork


#############################################
# 유틸리티 고계도 함수

# 반복
ficent.retry = _fn.retry
# 앞뒤로 감싸기.
ficent.wrap = _fn.wrap
# 지연 추가
ficent.delay = _fn.delay


#############################################
# fork-join 패턴 구현체
ficent.join = _fn.join


module.exports = exports = ficent