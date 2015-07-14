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
  return obj instanceof Error
  # _toString.call(obj) is "[object Error]" # Error을 상속받으면 부정확.
_isFunction = (obj)->
  return !!(obj && obj.constructor && obj.call && obj.apply);
_isObject = (obj)->
  return (!!obj && obj.constructor == Object);

_defaultCallbackFn = (err)->
  if err
    throw err  
 
toss =
  assign : (fn, srcFn...)->
    return unless fn
    for t in srcFn
      for own prop, val of t
        continue if prop is 'err'
        fn[prop] = val
        debug 'assign', prop, '=', val
    return

  mixErr: (callback)->
    return unless callback
    callback.err = (nextFn)->
      return (errMayBe, args...)->
        # debug 'err-to', 'take', arguments
        if _isError errMayBe # Stupid Proof
          return callback errMayBe, args...
        try 
          nextFn errMayBe, args...
        catch err
          callback err
  
createMuxFn = (fns)->  
  forkingFns = fns.map (flow)->  
    return createSeqFn flow if _isArray flow
    return flow

  newFn = (args..., outCallback)-> 
    # runFork fnArr, args, next 
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = _defaultCallbackFn

    join = createJoin()
    forkingFns.forEach (flow)->
      cbIn = join.in()
      toss.assign cbIn, outCallback
      flow args..., cbIn
    join.out outCallback 

  return newFn

createSeqFn = (flowFns)->
  _validating = (fns)->
    _valid = (arr)->
      for item in arr
        if _isArray item
          _valid item
        else
          throw new Error 'item of ficent flow must be function or array' unless _isFunction item
    _valid fns 

  fnInx = 0
  contextArgs = null
  outCallback = _defaultCallbackFn
  _toss = (err, tossArgs...)->
    _toss.params = tossArgs
    if flowFns.length is fnInx
      toss.assign outCallback, _toss
       
      return outCallback err, tossArgs... #  contextArgs...

    fn = flowFns[fnInx]
    debug 'createSeqFn', 'toss', fnInx
    fnInx++ 

    if _isArray fn 
      fn = createMuxFn fn 

    unless _isFunction fn
      outCallback new Error 'ficent only accept Function or Array'
      return
    isErrorHandlable = (fn.length is contextArgs.length + 2) # include err, callback
    if err and not isErrorHandlable
      return _toss err

    try
      if isErrorHandlable
        fn err, contextArgs..., _toss
      else
        fn contextArgs..., _toss
    catch newErr
      _toss newErr

  _validating flowFns
  toss.mixErr _toss 

  startFn = (args..., done)->   
    debug 'createSeqFn', 'startFn'
    first = args[0]
    startErr = null
    # debug 'first', first
    if first is null or first is undefined or _isError first
      startErr = args.shift()
      debug 'createSeqFn', 'set startErr = ', startErr
  
    if done 
      if typeof done isnt 'function'
        args.push done
      else
        outCallback = done 
    contextArgs = args
    _toss startErr, args... 

  return startFn
 
 
createJoin = (strict = true)->
  errors = []
  results = []
  finished = [] 
  inFns = []
  outFn = undefined

  _unifyErrors = (errors)->
    errs = errors.filter (err)-> err 
    error = undefined
    if errs.length > 0
      error = errs[0]
      error.errors = errors
    return error  

  callOut = ()->   
    allFnished = finished.every (v)-> v
    if allFnished and outFn
      err = _unifyErrors errors
      # results.obj = resultsObj
      toss.assign outFn, inFns...
      outFn err, results

  fns = 
    in :(varName = null)->
      varName = varName
      inx = errors.length
      errors.push undefined
      results.push undefined
      finished.push false
 
      _cb = (err, values...)->
        throw new Error 'should call `callback` once' if finished[inx] and strict
        errors[inx] = err
        values = values[0] if values.length is 1
        results[inx] = values
        if varName
          results[varName] = values
        finished[inx] = true

        callOut()
      inFns.push _cb
      return _cb
    out: (fn)->
      outFn = fn
      callOut()
  return fns
  
_fn = {}
_fn.join = createJoin 
_fn.fork = createMuxFn
_fn.flow = createSeqFn 

#############################################
# 유틸리티 고계도 함수

_fn.wrap = (preFns,postFns)->
  preFns = [preFns] unless _isArray preFns
  postFns = [postFns] unless _isArray postFns
  return (inFns)->
    inFns = [inFns] unless _isArray inFns
    return _fn.flow [preFns..., inFns..., postFns...]

_fn.err = (fn)->
  return (args..., callback)->
    toss.mixErr callback
    try
      fn args..., callback
    catch e
      callback e

# _fn.catch 
###
구현할까 생각해봤는데 의미가 없다.  
_fn.catch를 사용하면, 에러가 나던 말던 신경 안쓰는 루틴이기도 한데다가 
callback이 없으니 구조적으로 깊이 파고들 이유가 없다는 것이다. 
그냥 try catch 해도 된다. 
###

ficent = (args..., flowFns)->
  _fn.flow flowFns
 
ficent.fn = _fn.flow 
ficent.flow = _fn.flow 
ficent.err = _fn.err


# 같은 입력 요소에 대한 병렬 실행
ficent.fork = _fn.fork


#############################################
# 유틸리티 고계도 함수 
# 앞뒤로 감싸기.
ficent.wrap = _fn.wrap 

#############################################
# fork-join 패턴 구현체
ficent.join = _fn.join


module.exports = exports = ficent