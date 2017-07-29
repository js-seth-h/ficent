debug =  require('debug')('ficent')

###
라이브러리의 목적
Error 핸들링에 초점 
직/병렬 동시 서술
+ 가변인수 = arity를 기준으로하여 처리가능.
+ 배열 병렬- > context로 Array만 들어올수있을까? 가능성은..? 있다. 누산기로 쓸수도 있고..
  고로 배열 병렬은 다른 시작점을 걸고 연결할수 있게 해보자.
  로직의 재활용을 위한것이니 로직은 고정이다. 그러면, 입력을 억지로 맞추는것보다 그대로 넘기는게 낫다. 
+ retry -> 이건 확실히 다른 시작점을 걸어야 한다.
    유틸리티 형태도 될듯...
+ waterfall 과감히 삭제. 실효성이 많이 없다. 딱딱 떨어지는 경우도 거의 없고...
 
###
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
###
병렬화 다중화 정리 
 
1 서로 다른 함수에 , 서로 다른 데이터.
2 서로 다른 함수에 , 같은 데이터
3 같은 함수에, 서로 다른 데이터.
4 같은 함수에 같은 데이터.???? -> 몇번을 실행하던 결과가 같겠지.. 뭐하러..?
따라서 1~3 케이스만 고려

1. join(Fork–join model)으로 해결, 함수를 시작시키는 것을 체계화하기 힘들다. 
2. fork/flow로 해결 -> 병렬 실행 / 순차 실행의 차이일뿐
3. serial / parallel로 해결 -> 병렬 실행 / 순차 실행의 차이일뿐.

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


nextTick = (fn)->
  setTimeout fn, 0
if (typeof process isnt 'undefined') and (process.release.name is 'node') 
  nextTick = process.nextTick

_defaultCallbackFn = (err)->
  if err
    console.error err
    console.error err.stack
    throw err  

_alignArgs = (args...)-> 
  # first = args[0]
  # startErr = null 
  debug '_alignArgs input:', args
  maybeError = args[0]
  maybeCallback = args[args.length - 1]

  if maybeError is null or maybeError is undefined or _isError maybeError 
    args.shift()
  else 
    maybeError = null

  if _isFunction maybeCallback
    args.pop()
  else 
    maybeCallback = _defaultCallbackFn  
  debug '_alignArgs', maybeError, args, maybeCallback
  return [ maybeError, args, maybeCallback]

createJoin = ()->

  getUnifyErrors = ()->
    err_objects = context.errors.filter (err)-> err 
    error = undefined
    if err_objects.length > 0
      error = err_objects[0]
      # error.errors = err_objects
    return error  

  checkEnd = ()->   
    all_done = context.finished.every (v)-> v
    return unless all_done

    if context.outCallback
      err = getUnifyErrors()
      debug 'join done', context.results...

      context.outCallback err, context.results...

  inbound = ()->
    _tosser = (err, values...)->
      if context.is_canceled is true
        return  
      if _tosser.called is true
        err = err or new Error 'should call `callback` once' 
        context.is_canceled = true
        # context.outCallback err  
        # return 
      _tosser.called = true 
      context.errors[_tosser.inx] = err
      # values = values[0] if values.length is 1
      context.results[_tosser.inx] = values
      context.finished[_tosser.inx] = true 
      checkEnd() 

    _tosser.inx = context.errors.length
    context.errors.push undefined
    context.results.push undefined
    context.finished.push false 

    return _tosser
  outbound = (fn)->
    context.outCallback = fn
    checkEnd() 

  context = 
    is_canceled: false   
    # vars: {}
    in: inbound
    out: outbound 
    outCallback: null
    errors : []
    results : []
    finished : []  
    # cancel: do_cancel

  return context


createMuxFn = (fns)-> 
  entryFn = (args...)->     
    [startErr, startArgs, outCallback] = _alignArgs args... 
    context = createJoin() 

    forkingFns = fns.map (fn, inx)-> createSeqFn fn
    context.muxContext = []
    forkingFns.forEach (fn, inx)->
      ctx = fn startErr, startArgs..., context.in()
      context.muxContext.push ctx
    context.out outCallback

    context.cancel = ()->
      context.is_canceled = true
      for ctx in context.muxContext
        ctx.cancel()

    return context
  return entryFn

callContext = (flowFns, startArgs, cb)->
  make_tosser = ()->
    _tosser = (err, args...)->
      if context.is_canceled is true
        return 
      if _tosser.called is true
        err = err or new Error 'should call `callback` once' 
        call_next_fn err 
        context.is_canceled = true
        return 
      _tosser.called = true
      debug '_tosser takes', err, args...
      call_next_fn err, args... 
  
    _tosser.err = (extend_fn)->
      return (maybeError, args...)->       
        # if _isError maybeError 
        ###
          멍청이 방지가 더 문제가 되었다.
          JS의 TYPE이 강력하지가 않아서, 분명히 error인데 피해간다. 쯥.
        ###
        if maybeError 
          return _tosser maybeError, args...
        try  
          extend_fn maybeError, args...
        catch err
          _tosser err

    _tosser.cancel = (err = new Error 'Canceled')->
      context.fnInx = flowFns.length
      _tosser err
      context.is_canceled = true 

    _tosser.return = (args...)->
      context.fnInx = flowFns.length
      _tosser args... 

    _tosser.goto = (label, args...)->
      if label is 'first'
        inx = 0 
      else if label is 'last'
        inx = flowFns.length - 1 
      else
        inx = flowFns.indexOf label
        if inx < 0 
          return throw new Error 'Failed to goto ' + label 
      context.fnInx = inx 
      _tosser null, args...


    _tosser.getArgs =
    _tosser.args = ()->
      return _tosser.argv
      
    _tosser.setArgs = (args)->
      _tosser.argv = args 
 
    _tosser.items = ()->
      context.vars
 
    _tosser.toItems = (names...)->
      return _tosser.err (err, args...)->
        for value, inx in args
          # n = names[inx]
          if names[inx]
            _tosser.setItem names[inx], value
        _tosser err, args...

    _tosser.setItem = (key, value)->
      context.vars[key] = value

    _tosser.getItem = (key)->
      return context.vars[key] 

    return _tosser
  do_cancel = ()->
    context.is_canceled = true
  call_next_fn = (err, tossArgs...)->
    if flowFns.length is context.fnInx 
      return context.outCallback err, tossArgs... #  startArgs...

    cur_fn = flowFns[context.fnInx]
    context.fnInx++ 
 
    if _isArray cur_fn
      cur_fn = createMuxFn cur_fn 

    if _isString cur_fn
      return call_next_fn err, tossArgs...

    unless _isFunction cur_fn
      context.outCallback new Error 'ficent only accept Function or Array or Label'
      return        

    cur_fn_is_error_handler = (cur_fn.length is context.startArgs.length + 2) 

    if err and not cur_fn_is_error_handler
      return call_next_fn err

    try
      _toss = make_tosser()
      _toss.setArgs tossArgs # NEW TOSS  

      if cur_fn_is_error_handler
        debug 'try call', cur_fn, [err, context.startArgs..., _toss]
        debug 'try call, scope =', context.scope
        cur_fn.apply context, [err, context.startArgs..., _toss]
      else
        debug 'try call', cur_fn, [ context.startArgs..., _toss]
        debug 'try call, scope =', context.scope
        cur_fn.apply context, [context.startArgs..., _toss] 
    catch newErr
      # err = newErr err or newErr 
      call_next_fn newErr

  context = 
    is_canceled: false
    fnInx: 0 
    flowFns: flowFns 
    startArgs: startArgs
    outCallback: cb
    vars: {}
    # scope: this
    next: call_next_fn
    cancel: do_cancel

  return context


createSeqFn = (flowFns)->  

  if not _isArray flowFns
    flowFns = [flowFns] 
    # _valid fns, prefix

  entryFn = (args...)->    
    [startErr, startArgs, callback] = _alignArgs args... 

    debug 'entryFn', startErr, startArgs, callback
    context = callContext flowFns, startArgs, callback
    context.next startErr
    return context
  return entryFn
   


   
   
ficent = (args...)->
  ficent.flow args...
 
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
      debug 'mk Closure Fn with ', args
      return (_toss)->
        nextTick ()->
          debug 'inside par', args
          debug 'call series - each task', '_toss._tossable?', _toss._tossable
          taskFn args..., _toss.err (err, results_values...)->
            if results_values.length is 1
              results_values = results_values[0]
            results_array.push results_values
            _toss err

    f = ficent.flow fns

    seriesCallback = (err)->
      # toss_lib.tossData outCallback, seriesCallback
      outCallback err, results_array

    # toss_lib.makeTossableFn seriesCallback, 'series-internal-callback'
    # toss_lib.tossData seriesCallback, outCallback
    f seriesCallback
 
ficent.par = 
ficent.parallel = (args...)-> 
  taskFn = ficent args...
  return (input_array, outCallback)->
    fns = input_array.map (args)->
      unless _isArray args
        args = [args]
      debug 'mk Closure Fn with ', args
      return (next)-> 
        nextTick ()->
          taskFn args..., next
    f = ficent.fork fns 
    f outCallback
 

#############################################
# 유틸리티 고계도 함수 
# 앞뒤로 감싸기.
ficent.wrap = (preFns,postFns)->
  preFns = [preFns] unless _isArray preFns
  postFns = [postFns] unless _isArray postFns
  return (inFns)->
    inFns = [inFns] unless _isArray inFns
    return ficent.flow [preFns..., inFns..., postFns...]


module.exports = exports = ficent


