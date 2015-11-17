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
    console.error err
    console.error err.stack
    throw err  
 
toss =
  assign : (fn, srcFn...)->
    return unless fn
    for t in srcFn
      # debug ' < ', toss.toss_props t
      for own prop, val of t
        continue if prop is 'err'
        continue if prop is 'toss_props'
        fn[prop] = val
        # debug 'assign', prop, '=', val
    return

  mix_toss: (_toss)->
    return unless _toss
    _toss.toss_props = ()->
      toss.toss_props _toss

    _toss.setVar = (names...)->
      return _toss.err (err, args...)->

        for value, inx in args
          n = names[inx]
          if n
            _toss[n] = value
        _toss null


    _toss.err = (nextFn)->
      return (errMayBe, args...)->
        # debug 'err-to', 'take', arguments
        if _isError errMayBe # Stupid Proof
          return _toss errMayBe, args...
        try 
          nextFn errMayBe, args...
        catch err
          _toss err
  toss_props: (fn)-> 
    l = {}
    for own prop, val of fn
      continue if prop is 'err'
      continue if prop is 'toss_props'
      l[prop] = val
    return l
    # return require('util').inspect(l)
    # return JSON.stringify l, null, 2 
  # print: (fn)->
  #   debug 'toss.print', toss.toss_props fn

createMuxFn = (muxArgs...)->
  hint = undefined
  if muxArgs.length is 1
    [fns] = muxArgs
  else 
    [hint, fns] = muxArgs

  forkingFns = fns.map (flow, inx)->  
    # _hint = 
      # at:  'ficent nested fork ' + inx
    return createSeqFn flow
    # return flow

  newFn = (args..., outCallback)-> 
    # runFork fnArr, args, next 
    debug 'createMuxFn, newFn ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
    # debug 'toss.print', toss.toss_props outCallback
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = _defaultCallbackFn

    join = createJoin()
    forkingFns.forEach (flow)->
      cbIn = join.in()
      toss.assign cbIn, outCallback
      flow args..., cbIn

    _insideCb = (err, args...)->
      # debug 'fork _insideCb', err, args
      if err
        err.hint = err.hint or hint
        err.ficentFn = err.ficentFn or newFn
      toss.assign outCallback, _insideCb
      outCallback err, args...

    join.out _insideCb

  # newFn.hint = hint
  for own k, v of hint
    debug 'set hint kv', k, v
    newFn[k] = v 
  return newFn

createSeqFn = (args...)->
  hint = undefined
  if args.length is 1
    [flowFns] = args
  else 
    [hint, flowFns] = args


  if not _isArray flowFns
    flowFns = [flowFns]

  _validating = (fns)->
    _valid = (arr)->
      for item in arr
        if _isArray item
          _valid item
        else
          throw new Error 'item of ficent flow must be function or array' unless _isFunction item
    _valid fns 

  _startArg = (args..., done)-> 
    # debug 'createSeqFn', '_startArg'
    first = args[0]
    startErr = null 
    if first is null or first is undefined or _isError first
      startErr = args.shift()
      # debug 'createSeqFn', 'set startErr = ', startErr

    outCallback = _defaultCallbackFn
    if done 
      if typeof done isnt 'function'
        args.push done
      else
        outCallback = done  
    return [ startErr, args, outCallback]

  _validating flowFns
  startFn = (args...)->   
    fnInx = 0
    contextArgs = null
    outCallback = null
    brokenErr = null

    [startErr, args, outCallback] = _startArg args... 
    debug 'createSeqFn, startFn *********************************************'
    # debug 'toss.print', toss.toss_props  outCallback

    contextArgs = args

    _createTmpCB = (finx)->
      called = false
      cb_callcheck = (err, args...)->
        debug 'cb_callcheck',finx,  err, args
        if called is true
          unless err
            brokenErr = new Error 'toss is called twice.' 
            fnInx = finx
            _toss brokenErr
          else
            _toss err 
          return 
          # return 
        called = true

        # debug  '_toss', '<', 'tmpCB ', finx
        toss.assign _toss, cb_callcheck 
        _toss err, args... 

      # debug 'tmpCB ', finx, '<', '_toss'
      toss.assign cb_callcheck, _toss 
      toss.mix_toss cb_callcheck
      return cb_callcheck

    _toss = (err, tossArgs...)->
      if brokenErr
        return if err isnt brokenErr

      _toss.params = tossArgs
      if err
        err.hint = err.hint or hint
        err.ficentFn = err.ficentFn or startFn 
      if flowFns.length is fnInx
        # debug ' - assign to outCallback'
        # debug 'outCallback',  '<', '_toss'
        toss.assign outCallback, _toss
         
        return outCallback err, tossArgs... #  contextArgs...

      fn = flowFns[fnInx]
      # debug 'createSeqFn', 'toss', fnInx
      fnInx++ 

      if _isArray fn 
        fn = createMuxFn hint, fn 

      unless _isFunction fn
        outCallback new Error 'ficent only accept Function or Array'
        return
      isErrorHandlable = (fn.length is contextArgs.length + 2) # include err, callback
      if err and not isErrorHandlable
        return _toss err

      try
        cb = _createTmpCB (fnInx - 1)
        if isErrorHandlable
          fn err, contextArgs..., cb
        else
          fn contextArgs..., cb
      catch newErr
        err = err or newErr 
        _toss err
    toss.mix_toss _toss  
    debug '_toss',  '<', 'outCallback'
    toss.assign _toss, outCallback
    _toss startErr, args... 
  # startFn.hint = hint

  debug 'hint ===', hint
  for own k, v of hint
    debug 'set Hint kv', k, v
    # startFn[k] = v 
    Object.defineProperty startFn, k, {value: v } 
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
      toss.mix_toss _cb
      inFns.push _cb
      return _cb
    out: (fn)->
      outFn = fn
      callOut()
  return fns
   
ficent = (args...)->
  ficent.flow args...

#############################################
# 유틸리티 고계도 함수 
# 앞뒤로 감싸기.
ficent.wrap = (preFns,postFns)->
  preFns = [preFns] unless _isArray preFns
  postFns = [postFns] unless _isArray postFns
  return (inFns)->
    inFns = [inFns] unless _isArray inFns
    return ficent.flow [preFns..., inFns..., postFns...]
 

#############################################
# fork-join 패턴 구현체
ficent.join = createJoin
ficent.flow = createSeqFn # 함수 직렬 수행
ficent.fork = createMuxFn # 함수 병렬 수행

ficent.ser =
ficent.series = (flows)->
  taskFn = ficent flows
  return (input_array, callback)->
    results_array = []
    fns = input_array.map (args)->
      unless _isArray args
        args = [args]
      # debug 'mk Closure Fn with ', args
      return (_toss)->
        # debug 'inside par', args
        taskFn args..., _toss.err (err, results_values...)->
          if results_values.length is 1
            results_values = results_values[0]
          results_array.push results_values
          _toss err

    f = ficent.flow fns
    f (err)->
      callback err, results_array
 
ficent.par = 
ficent.parallel = (flows)->
  taskFn = ficent flows
  return (input_array, callback)->
    fns = input_array.map (args)->
      unless _isArray args
        args = [args]
      # debug 'mk Closure Fn with ', args
      return (next)->
        # debug 'inside par', args
        taskFn args..., next
    f = ficent.fork fns 
    f callback

# ficent.do = (inputs..., flows, callback)->
#   f = ficent.flow flows
#   f inputs..., callback



module.exports = exports = ficent