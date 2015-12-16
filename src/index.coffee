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
 
_isNumeric = (obj)->
    return !_isArray( obj ) && (obj - parseFloat( obj ) + 1) >= 0;
_isString = (obj)->
  typeof obj == 'string' || obj instanceof String  
_isArray = Array.isArray or (obj) ->
  Object.prototype.toString.call(obj) is "[object Array]"
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
_defaultCallbackFn.desc = '_defaultCallbackFn'
toss_fn_maker =
  return: null
  goto: null
  desc: (_toss)->
    unless _toss.desc
      _toss.desc = 'no-named-toss'

  _tossable: (_toss)->
    _toss._tossable = true

  _var_read: {}
  _var_write: {}
  const: (_toss)->
    _toss.const = (name, value)->
      _toss._var_read[name] = value
  var: (_toss)->
    _toss.var = (name, value)->
      # return _toss[name] unless value 
      # _toss[name] = value 
      unless value
        # read
        value = _toss._var_write[name] or _toss._var_read[name] 
        return value  
      else 
        # write
        _toss._var_write[name] = value
      
  setVar: (_toss)->
    _toss.setVar = (names...)->
      return _toss.err (err, args...)->
        for value, inx in args
          n = names[inx]
          if n
            _toss.var n, value
        _toss null
  vars: (_toss)->
    _toss.vars = ()->
      _tmp = {}
      for own k, v of _toss._var_read
        _tmp[k] = v
      for own k, v of _toss._var_write
        _tmp[k] = v
      vars = []
      for own k, v of _tmp
        vars.push k
      return vars
 
  _args: []
  args: (_toss)->
    _toss.args = ()->
      return _toss._args
  setArgs: (_toss)->
    _toss.setArgs = (args)->
      _toss._args = args
  err: (_toss)->
    _toss.err = (nextFn)->
      cb = (errMayBe, args...)->
        # debug 'err-to', 'take', arguments
        if _isError errMayBe # Stupid Proof
          return _toss errMayBe, args...
        try 
          toss_lib.tossData _toss, cb
          nextFn errMayBe, args...
        catch err
          _toss err
      toss_lib.makeTossableFn cb, "#{_toss.desc}.err"
      toss_lib.tossData cb, _toss
      return  cb

 
toss_lib =
  makeTossableFn: (_toss, desc)->
    return unless _toss 
    for own k, v of toss_fn_maker
      if _isFunction v
        v _toss
      else 
        _toss[k] = v

    if _toss.desc is 'no-named-toss'
      _toss.desc = desc
 

  tossData : (fn, srcFns...)-> 

    return if fn._tossable isnt true

    for srcFn in srcFns
      continue if srcFn._tossable isnt true
      debug 'toss-data', fn.desc , '<<', srcFn.desc
      # fn._args = srcFn._args
      fn.setArgs srcFn.args()
      for key, inx in srcFn.vars()
        fn.const key, srcFn.var key

      for own k, v of srcFn 
        continue if toss_fn_maker.hasOwnProperty k
        debug '     ', 'prop:', k
        fn[k] = v 

    return
 
_validating = (fns, prefix)->
  # _valid = (arr, prefix)->
  for item, inx in fns
    item.desc = "#{prefix}.#{inx}" unless item.desc
    # debug item.desc, item
    if _isArray item
      _validating item, item.desc
    else if _isFunction item
    else if _isString item
    else
      throw new Error 'item of ficent flow must be function or array'  
createMuxFn = (muxArgs...)->
  hint = undefined
  if muxArgs.length is 1
    [fns] = muxArgs
  else 
    [hint, fns] = muxArgs
 

  newFn = (args..., outCallback)-> 
    if typeof outCallback isnt 'function'
      args.push outCallback
      outCallback = _defaultCallbackFn
    # else 
      # toss_lib.makeTossableFn outCallback, "#{newFn.desc}.outcallback"


    debug 'mux    ', newFn.desc, '->', outCallback.desc 
    join = createJoin()
    forkingFns.forEach (flow, inx)->
      cbIn = join.in()
      debug 'calling  ', flow.desc, '->', cbIn.desc
      toss_lib.makeTossableFn cbIn, "#{flow.desc}.callback"
      # toss_lib.tossData cbIn, outCallback
      # flow.desc = "fork.#{inx}"
      flow args..., cbIn

    _insideCb = (err, args...)->
      # debug 'fork _insideCb', err, args
      if err
        err.hint = err.hint or hint
        err.ficentFn = err.ficentFn or newFn
      # toss_lib.tossData outCallback, _insideCb
      outCallback err, args...

    toss_lib.makeTossableFn _insideCb, "#{newFn.desc}.before-outcallback"
    join.out _insideCb

  # newFn.hint = hint
  for own k, v of hint
    Object.defineProperty newFn, k, {value: v, writable: true } 
    # debug 'set hint kv', k, v
    # newFn[k] = v 
  newFn.desc = newFn.desc or 'fork'
  _validating fns, newFn.desc

  forkingFns = fns.map (flow, inx)->  
    _fn = createSeqFn {desc: "#{newFn.desc}.flow-wrap.#{inx}" }, flow
    return _fn
  return newFn

createSeqFn = (args...)->
  hint = undefined
  if args.length is 1
    [flowFns] = args
  else 
    [hint, flowFns] = args


  if not _isArray flowFns
    flowFns = [flowFns] 
    # _valid fns, prefix

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
        # toss_lib.makeTossableFn done, "#{startFn.desc}.outcallback" 
        outCallback = done  
    return [ startErr, args, outCallback]

  startFn = (args...)->   
    fnInx = 0
    contextArgs = null
    outCallback = null
    brokenErr = null

    [startErr, args, outCallback] = _startArg args... 


    contextArgs = args

    _createTmpCB = (fn_desc)->
      called = false


      cb_callcheck = (err, args...)->
        if called is true
          err = err or new Error 'toss is called twice.' 
          _call_next_fn err 
          return 
        called = true

        # debug  '_call_next_fn', '<', 'tmpCB ', finx
        debug 'seq-done ', cb_callcheck.desc, 'with', args...
        toss_lib.tossData _call_next_fn, cb_callcheck 
        _call_next_fn err, args... 

      # debug 'tmpCB ', finx, '<', '_call_next_fn'
      toss_lib.makeTossableFn cb_callcheck, "#{fn_desc}.toss" # "ficent.flow.callback.of-#{finx}"

      cb_callcheck.done =
      cb_callcheck.return = (args...)->
        fnInx = flowFns.length
        cb_callcheck args...

      cb_callcheck.goto = (label, args...)->
        if label is 'first'
          inx = 0 
        if label is 'last'
          inx = flowFns.length - 1 
        else
          inx = flowFns.indexOf label
          if inx < 0 
            return throw new Error 'Failed to goto ' + label

        fnInx = inx 
        cb_callcheck null, args...

      return cb_callcheck

    _call_next_fn = (err, tossArgs...)->
      if brokenErr
        return if err isnt brokenErr

      _call_next_fn.setArgs tossArgs
      if err
        err.msg = err.toString()
        err.hint = err.hint or hint
        err.ficentFn = err.ficentFn or startFn 
      if flowFns.length is fnInx
        # debug ' - assign to outCallback'
        # debug 'outCallback',  '<', '_call_next_fn'
        # toss_lib.tossData outCallback, _call_next_fn
        return outCallback err, tossArgs... #  contextArgs...

      fn = flowFns[fnInx]
      fnInx++ 

      # debug 'fnInx', fnInx, fn

      if _isString fn # Label
        return _call_next_fn err, tossArgs...

      if _isArray fn 
        fn = createMuxFn {desc: "#{fn.desc}.fork-wrap"}, fn 
        # fn.desc = "flow.#{fnInx}.fork-wrap"

      unless _isFunction fn
        outCallback new Error 'ficent only accept Function or Array or Label'
        return
      isErrorHandlable = (fn.length is contextArgs.length + 2) # include err, callback
      if err and not isErrorHandlable
        return _call_next_fn err

      try
        cb = _createTmpCB fn.desc
        debug 'calling  ', fn.desc, '->', cb.desc
        toss_lib.tossData cb, _call_next_fn 

        if isErrorHandlable
          fn err, contextArgs..., cb
        else
          fn contextArgs..., cb
      catch newErr
        err = err or newErr 
        _call_next_fn err

    toss_lib.makeTossableFn _call_next_fn, "#{startFn.desc}.internal-next"
    # debug '_call_next_fn',  '<', 'outCallback'

    debug 'seq    ', startFn.desc, '->', outCallback.desc 
    # toss_lib.tossData _call_next_fn, outCallback
    _call_next_fn startErr, args... 
  # startFn.hint = hint

  # debug 'hint ===', hint
  # debug 'startFn.desc', startFn.desc 
  for own k, v of hint
    Object.defineProperty startFn, k, {value: v, writable: true } 


  startFn.desc = startFn.desc or 'ficent'
  _validating flowFns, startFn.desc
 
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
      # toss_lib.tossData outFn, inFns...
      outFn err, results

  fns = 
    in :(varName = null)->
      varName = varName
      inx = errors.length
      errors.push undefined
      results.push undefined
      finished.push false
 
      _cb_forked = (err, values...)->
        throw new Error 'should call `callback` once' if finished[inx] and strict
        errors[inx] = err
        values = values[0] if values.length is 1
        results[inx] = values
        if varName
          results[varName] = values
        finished[inx] = true

        callOut()
      # toss_lib.makeTossableFn _cb_forked, "join.callback.#{inx}.(#{varName})"
      inFns.push _cb_forked
      return _cb_forked
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
ficent.series = (args...)->
  taskFn = ficent args...
  return (input_array, outCallback)->
    results_array = []
    fns = input_array.map (args)->
      unless _isArray args
        args = [args]
      # debug 'mk Closure Fn with ', args
      return (_toss)->
        # debug 'inside par', args
        # debug 'call series - each task', '_toss._tossable?', _toss._tossable
        taskFn args..., _toss.err (err, results_values...)->
          if results_values.length is 1
            results_values = results_values[0]
          results_array.push results_values
          _toss err

    f = ficent.flow {desc: "series-of.#{taskFn.desc}"}, fns

    seriesCallback = (err)->
      # toss_lib.tossData outCallback, seriesCallback
      outCallback err, results_array

    toss_lib.makeTossableFn seriesCallback, 'series-internal-callback'
    # toss_lib.tossData seriesCallback, outCallback
    f seriesCallback
 
ficent.par = 
ficent.parallel = (args...)-> 
  taskFn = ficent args...
  return (input_array, outCallback)->
    fns = input_array.map (args)->
      unless _isArray args
        args = [args]
      # debug 'mk Closure Fn with ', args
      return (next)-> 
        taskFn args..., next
    f = ficent.fork fns 
    f outCallback
 


module.exports = exports = ficent