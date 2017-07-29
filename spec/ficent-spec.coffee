process.env.DEBUG = "test, -ficent"
ficent = require '../src'
assert = require 'assert'
util = require 'util'

fs = require 'fs'
debug = require('debug')('test')

func1 = (ctx, next)->
  ctx.a = true
  next()
func2 = (ctx, next)->
  ctx.b = true
  next()

describe 'flow', ()->
  it 'run flow with context arguments ', (done)->
    ctx =
      name : 'context base'

    fx = ficent [
      func1,
      func2,
      (err, ctx, next)->
        debug  'arguments', arguments
        expect err
          .toEqual null
        # assert not util.isError err, 'no error'
        expect ctx.a
          .toBeTruthy()
        expect ctx.b
          .toBeTruthy()
        done()
    ]
    fx ctx


  it 'run flow with single function ', (done)->
    debug 'run flow with single function '
    ctx =
      name : 'context base'

    fx = ficent (err, ctx, next)->
      debug  'arguments', arguments
      throw new Error 'Fake'
    fx ctx, (err)->

      debug '======================================'
      debug 'run flow with single function:  expect not toEqual null =', err
      expect err
        .not.toEqual null
      done()


  it 'run flow with do ', (done)->
    do ficent [
      (next)->
        debug  'arguments', arguments
        next()
        done()
    ]

  it 'run function created by flow', (done)->

    ctx =
      name : 'context base'


    _fn = ficent.flow [
      func1,
      func2
    ]
    _fn ctx, (err)->
      debug  'arguments', arguments
      expect err
        .toEqual null
      # assert not util.isError err, 'no error'
      expect ctx.a
        .toBeTruthy()
      expect ctx.b
        .toBeTruthy()
      done()

  it 'with no arguments ', (done)->

    result = 1

    f1 = (next)->
      debug 'f1'
      result = 9
      next()
    f2 = (next)->
      debug 'f2'
      result = 11
      next()
    f = ficent.flow [ f1, f2]
    # f (req,res,next)
    debug 'run no arg'
    f (err)->
      assert not util.isError err, 'no error'
      # assert ctx.a , "must exist"
      # assert ctx.b , "must exist"
      expect(result).toEqual 11

      done()
  it 'run with multiple context arguments ', (done)->

    ctx = {}
    ctx1 = {}
    ctx2 = {}

    f = ficent.flow [
      (ctx, c1,c2, next)->
        ctx.a = true
        next()
      (ctx, c1,c2,next)->
        ctx.b = true
        next()
    ]
    # f (req,res,next)
    f ctx, ctx1, ctx2, (err)->
      debug  'arguments', arguments
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()

  it 'run with nesting flow ', (done)->

    ctx = {}

    g = ficent.flow [func1, func2]

    f = ficent.flow [ g ]

    # f (req,res,next)
    f ctx, (err)->
      debug  'arguments', arguments
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()


  it 'support error jump ', (done)->

    ctx = {}
    func_mk_Err = (ctx, next)->
      debug 'mk Err'
      next new Error 'FAKE'
    func_Err = (err, ctx, next)->
      debug 'got Err',err
      assert err, 'must get Error'
      next()

    f = ficent.flow [ func1, func_mk_Err, func2, func_Err]

    # f (req,res,next)
    f ctx, (err)->
      debug 'end ', arguments
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b is undefined , "must not exist"

      done()
  it 'support error but no handler', (done)->

    ctx = {}
    func_mk_Err = (ctx, next)->
      debug 'mk Err'
      next new Error 'FAKE'

    f = ficent.flow [ func1, func_mk_Err, func2]

    # f (req,res,next)
    f ctx, (err)->
      debug 'end ', arguments
      assert util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b is undefined , "must not exist"

      done()
  it 'occur err no cature in first', (done)->
    ctx = {}
    func_mk_Err = (ctx, next)->
      debug 'mk Err'
      throw new Error 'FAKE'
    func_Err = (err, ctx, next)->
      debug 'got Err',err
      ctx.errHandler = 1
      assert err, 'must get Error'
      next()

    f = ficent.flow [ func_mk_Err, func_Err]

    # f (req,res,next)
    f ctx, (err)->
      debug 'end ', arguments
      assert util.isError err, 'occerror error'
      assert ctx.errHandler is 1, 'got handler'
      done()
  it 'occur err no cature in not first', (done)->
    ctx = {}
    func_mk_Err = (ctx, next)->
      debug 'mk Err'
      next null
    func_Err = (err, ctx, next)->
      debug 'got Err',err
      assert err, 'must get Error'
      throw new Error 'FAKE'
      next()

    f = ficent.flow [ func_mk_Err, func_Err]

    # f (req,res,next)
    f ctx, (err)->
      debug 'end ', arguments
      assert util.isError err, 'occerror error'
      done()


describe 'goto, return', ()->
  it 'goto - skip', (done)->

    f = ficent.flow [
      (_toss)->
        _toss.setItem 'a', true
        _toss null
      (_toss)->
        _toss.setItem 'b', true
        _toss.setItem 'ctx', {cnt: 0 }
        _toss null
      (_toss)->
        return _toss.goto 'here'
      (_toss)->
        _toss.setItem('ctx').cnt++
        _toss.setItem 'c', true
        _toss null
      (_toss)->
        _toss.setItem 'd', true
        _toss null
      (_toss)->
        _toss.setItem 'e', true
        _toss null
      'here'
      (_toss)->
        _toss.setItem 'g', true
        _toss null, _toss.getItem 'ctx'
    ]
    # f (req,res,next)
    f (err, obj)->
      debug 'err ', err
      expect err
        .toEqual null
      expect obj.cnt
        .toEqual 0
      done()


  it 'goto - repeat', (done)->

    f = ficent.flow [
      (_toss)->
        _toss.setItem 'a', true
        _toss null
      (_toss)->
        _toss.setItem 'b', true
        _toss.setItem 'ctx', {cnt: 0 }
        _toss null
      'here'
      (_toss)->
        _toss.getItem('ctx').cnt++
        _toss.setItem 'c', true
        _toss null
      (_toss)->
        _toss.setItem 'd', true
        _toss null
      (_toss)->
        _toss.setItem 'e', true
        _toss null
      (_toss)->

        f = _toss.getItem 'f'
        _toss.setItem 'f', true
        unless f
          return _toss.goto 'here'
        _toss null
      (_toss)->
        _toss.setItem 'g', true
        _toss null, _toss.getItem 'ctx'
    ]
    # f (req,res,next)
    f (err, obj)->
      debug 'err ', err
      expect err
        .toEqual null
      expect obj.cnt
        .toEqual 2
      done()


  it 'return', (done)->
    f = ficent.flow [
      (_toss)->
        _toss.setItem 'a', 99
        _toss.return null, _toss
      (_toss)->
        _toss.setItem 'a', 88
        _toss null, _toss
    ]
    # f (req,res,next)
    f (err, obj)->
      debug 'err ', err
      expect err
        .toEqual null
      expect obj.getItem('a')
        .toEqual 99
      done()

describe 'fork', ()->
  it 'basic', (done)->

    f = ficent.fork  [
      (ctx, _toss)->
        ctx.cnt++ # 1
        _toss null
      (ctx, _toss)->
        ctx.x = 2
        ctx.cnt++ # 2
        _toss null
      (ctx, _toss)->
        ctx.cnt++ # 3
        _toss null
      (ctx, _toss)->
        ctx.cnt++ # 4
        _toss null
      (ctx, _toss)->
        ctx.cnt++ # 5
        _toss null
    ]
    ctx =  cnt : 0
    f ctx, (err)->
      assert ctx.cnt is 5 , 'fork count 5 , but ' + ctx.cnt
      done()

  it 'with Err', (done)->
    forkingFns = []
    ctx = cnt : 0

    f = ficent.fork [
      (ctx, _toss)->
        ctx.cnt++
        _toss new Error 'JUST'
      (ctx, _toss)->
        ctx.cnt++
        _toss new Error 'JUST'
      (ctx, _toss)->
        ctx.cnt++
        _toss new Error 'JUST'
    ]

    f ctx, (err)->
      assert util.isError err, 'error'
      assert ctx.cnt is 3 , 'fork count 3'
      done()

  it 'fork, no callback', (done)->
    forkingFns = []

    f = ficent.fork [
      (ctx, _toss)->
        ctx.cnt++
        _toss null
      (ctx, _toss)->
        ctx.cnt++
        _toss null
      (ctx, _toss)->
        ctx.cnt++
        _toss null
    ]
    ctx =  cnt : 0
    f ctx
    assert ctx.cnt is 3, 'fork count 3 '
    done()

  it 'param', (done)->

    f = ficent [
      [
        (ctx, _toss)->
          _toss null, 1, 2
        (ctx, _toss)->
          _toss null, 'a', 'b'
      ]
      (ctx, _toss)->
        debug 'param', _toss
        debug 'param', _toss.args()
        _toss null, _toss.args()...
    ]
    f (err, result... )->
      # assert ctx.cnt is 5 , 'fork count 5 '
      debug 'params result', err, result...
      # assert not util.isError err, 'no error'
      expect result
        .toEqual [ [1,2], ['a', 'b']]
      done()

describe 'flow  - forkjoin', ()->
  it 'base fork join ', (done)->
    ctx = {}
    f = ficent.flow [ [func1, func2, (ctx,next)->
      ctx.zzz = 9
      debug 'fj', ctx
      next()
     ] ]

    f ctx, (err)->
      debug 'errs, ctx', err, ctx
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"
      done()

  it 'with Err ', (done)->

    ctx = {}

    f = ficent.flow [ [func1, func2, (ctx, next)->
        next new Error 'fire Err'
      ] ]

    # f (req,res,next)
    f ctx, (err)->
      debug 'errs, ctx', err, ctx
      assert util.isError err, 'error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()




describe 'wrap', ()->

  it 'wrap test', (done)->

    init = (ctx, next)->
      ctx.num = 9
      next()
    end = (ctx, next)->
      assert.equal ctx.num, 99
      next()
    inFn = (ctx, next)->
      ctx.num *= 11
      next()

    wrapper = ficent.wrap [init], [end]


    wrapper([inFn]) {}, ()->
      done()
  it 'wrap test - no callback, no array', (done)->

    init = (ctx, next)->
      ctx.num = 9
      next()
    end = (ctx, next)->
      assert.equal ctx.num, 99
      done()
    inFn = (ctx, next)->
      ctx.num *= 11
      next()

    wrapper = ficent.wrap init, end


    wrapper(inFn) {}




describe 'toss', ()->


  it 'toss data ', (done)->
    debug '-----------------------------------------', 'toss data'
    ctx = {}
    ctx1 = {}
    ctx2 = {}

    f = ficent [
      (ctx, c1,c2, toss)->
        toss.setItem 'tossValue', 9
        toss()
      (ctx, c1,c2,toss)->
        ctx.tossed = toss.getItem('tossValue') is 9
        toss()
    ]
    # f (req,res,toss)
    f ctx, ctx1, ctx2, (err)->
      debug  'toss data', arguments
      expect err
        .toBe undefined

      assert ctx.tossed is true, 'must be tossed'

      done()
  it 'toss err 1 ', (done)->

    output = {}
    f = ficent.flow [
      (toss)->
        fs.rename "test/test0", 'test/test1', toss.err (err)->
          toss null
      (toss)->
        toss.a = 9
        toss()
    ]
    f (err)->
      debug err
      expect err
        .not.toBe null
      done()

  it 'toss err from oth ', (done)->
    check_board = {}
    oth = ficent [
      (_toss)->
        _toss null
      (_toss)->
        _toss.a.b.c.d.e = 9
        # throw new Error 'FAKE'
        debug 'oth ok??????????'
        _toss null
      (_toss)->
        _toss null
      (err, _toss)->
        _toss err, null
    ]
    output = {}
    f = ficent [
      (toss)->
        debug 'call oth'
        oth toss.err (err)->
          check_board.oth_cb = true
          debug 'OTHER callback err?', err
          toss null
      (toss)->
        toss null
    ]
    f (err)->
      debug 'out callback err?', err
      expect check_board.oth_cb
        .not.toBe true
      expect err
        .not.toBe null
      done()


  it 'toss err 2 ', (done)->

    output = {}
    f = ficent.flow [
      (toss)->
        fs.rename "test/test0", 'test/test1', toss
      (toss)->
        toss.a = 9
        toss()
    ]
    f (err)->
      debug 'out callback err?', err
      expect err
        .not.toBe null
      done()

  f = (callback)-> callback null, 5
  e = (callback)-> callback new Error 'in E'
  it 'no err ', (done)->
    a = ficent (_toss)->
      debug 1
      f _toss.err (err, val)->
        debug 2
        _toss null
    a (err)->

      debug 'err catch no err', err
      expect err
        .toBe null
      done()

  it 'catch ', (done)->
    a = ficent (callback)->
      throw new Error 'TEST'
      f callback.err (err, val)->
        callback null
    a (err)->

      debug 'catch ', err
      expect err
        .not.toBe null
      done()


  it 'catch inside ', (done)->
    a = ficent (callback)->
      f callback.err (err, val)->
        throw new Error 'TEST'
        callback null
    a (err)->

      debug 'catch  inside', err
      expect err
        .not.toBe null
      done()


  it 'toss before callbacked', (done)->
    a = ficent (callback)->
      e callback.err (err, val)->
        throw new Error 'TEST2'
        callback null
    a (err)->
      debug 'toss before callbacked ', err
      expect err
        .not.toBe null
      done()

  it 'double toss', (done)->
    g = ficent  [
      (_toss)->
        debug 'double toss', 'g'
        _toss.setItem 'g', 12
        _toss null, 12
    ]
    f = ficent  [
      (_toss)->
        debug 'double toss', 'f.a'
        _toss.setItem 'a', 11
        _toss null
      (_toss)->
        debug 'double toss', 'f g()'
        g _toss.storeArgs 'g2'
      (_toss)->
        debug 'double toss', 'ag', _toss.getItem 'g'
        expect _toss.getItem('g')
          .toEqual null
        _toss.setItem 'ag', _toss.getItem('a') * _toss.getItem('g2')
        _toss null, _toss
      ]

    outCall = (err, outCall)->
      debug 'double toss', 'outCall'
      expect err
        .toBe null
      expect outCall.getItem 'ag'
        .toEqual 11 * 12
      done()
    f outCall





describe 'double callback defence', ()->
  it 'err when double callback ', (done)->
    fx = ficent [
      (next)->
        next null
        next null
      (next)->
        setTimeout next, 1000
      (next)->
        setTimeout next, 1000
    ]
    fx (err)->

      debug '======================================'
      debug 'err when double callback:  expect not toEqual null =', err
      debug 'err ', err
      expect err
        .not.toEqual null
      done()


describe 'ficent seq, par', (done)->

  it 'par', (done)->
    input = [3, 6, 9].map (x)-> [x]
    taskFn = ficent.par (num, next)->
      debug 'par in', num
      next null, num * 1.5
    taskFn input, (err, results...)->
      debug 'par, callback', arguments
      # assert ctx.cnt is 5 , 'fork count 5 '
      expect results
        .toEqual [[4.5], [9], [13.5]]
      done()

  it 'ser', (done)->
    input = [3, 6, 9].map (x)-> [x]
    results = []
    taskFn = ficent.ser (num, next)->
      debug 'ser in', num
      results.push num * 1.5
      next null, num * 2
    taskFn input, (err, numbers)->
      debug 'ser, callback', results
      expect numbers
        .toEqual [6, 12, 18]
      # assert ctx.cnt is 5 , 'fork count 5 '
      done()

  it 'ser2', (done)->
    input = [3, 6, 9]
    results = []
    taskFn = ficent.ser (num, next)->
      debug 'ser in', num
      results.push num * 1.5
      next null, num * 2, num * 10
    taskFn input, (err, numbers)->
      debug 'ser, callback', results
      expect numbers
        .toEqual [[6, 30], [12, 60], [18, 90]]
      # assert ctx.cnt is 5 , 'fork count 5 '
      done()

describe 'storeArgs', (done)-> 

  it 'storeArgs', (done)->
    async_ab = (callback)->
      callback null, 1, 2
    taskFn = ficent [
      (_toss)->
        _toss.setItem 'c', 20
        async_ab _toss.storeArgs 'a', 'b'
      (err, _toss)->
        expect _toss.getItem 'a'
          .toEqual 1
        expect _toss.getItem 'b'
          .toEqual 2
        expect _toss.getItem 'c'
          .toEqual 20
        done()
    ]

    taskFn()


  it 'storeArgs  with Err', (done)->
    async_ab = (callback)->
      callback  new Error 'JUST'
    taskFn = ficent [
      (_toss)->
        _toss.setItem 'c', 20
        async_ab _toss.storeArgs 'a', 'b'
      (err, _toss)->
        expect err
          .not.toEqual null
        done()
    ]

    taskFn()





describe 'err?', ()->
  it 'crypt ', (done)->


    md5 = (v)-> require("crypto").createHash("md5").update(v).digest("hex")

    do ficent [
      (_toss)->
        fs.lstat 'package.json', _toss.err (err)->
          _toss null
      (_toss)->
        crypto = require 'crypto'
        salt = md5 crypto.randomBytes(40).readUInt32LE(0)
        _toss null
      (err,_toss)->

        debug 'err = ',err
        done()
    ]

describe 'isolate', ()->

  it 'run isolate', (done)->

    a = ficent (_toss)->
      _toss.setItem 'a', 9
      _toss.aa = 9
      _toss null
    a ()->
    b = ficent (_toss)->
      a = _toss.getItem 'a'
      debug '_toss.aa', _toss.aa
      expect a
        .not.toEqual 9
      expect _toss.aa
        .not.toEqual 9
        done()
      _toss null
    b ()->


describe 'error', ()->

  it 'err intercept', (done)->

    (ficent [
      (_toss)->
        _fn = ->
          _toss new Error 'Just Error'
        setTimeout _fn, 100
      (err, _toss)->
        _toss null
      (_toss)->
        _toss null, 9
    ]) (err, v)->
      expect err
        .toEqual null
      expect v
        .toEqual 9
      done()



  it 'err intercept with fork', (done)->
    debug 'err intercept with fork'

    (ficent [
      (_toss)->
        setTimeout _toss, 100
      [
        (_toss)->
          _fn9 = ->
            _toss new Error 'Just Error'
          setTimeout _fn9, 100
        (_toss)->
          _fn10 = ->
            _toss null
          setTimeout _fn10, 100
      ]
      (err, _toss)->
        _toss null
      (_toss)->
        _toss null, 9
    ]) (err, v)->
      expect err
        .toEqual null
      expect v
        .toEqual 9
      done()

  it 'err intercept with storeArgs', (done)->
    debug 'err intercept with storeArgs' 
    x = (callback)->
      _fn4 = ->
        callback new Error 'Just Error'
      setTimeout _fn4, 100

    (ficent [
      (_toss)->
        x _toss.storeArgs 'data'
      (err, _toss)->
        _toss null
      (_toss)->
        _toss null, 9
    ]) (err, v)->
      expect err
        .toEqual null
      expect v
        .toEqual 9
      done()
  it 'err intercept with storeArgs, fork', (done)->
    debug 'err intercept with storeArgs, fork'

    ext_func = ficent [
      (_toss)->
        setTimeout _toss, 100
      (_toss)->
        cnt = 0
        (ficent [
          (_toss)->
            cnt++
            _fn2 = ->
              if cnt < 2
                return _toss.goto 'first'
              debug 'throw error'
              _toss new Error 'Just Error'
            setTimeout _fn2, 100
        ]) _toss
      (err, _toss)->
        _toss err
    ]
    (ficent [
      (_toss)->
        setTimeout _toss, 100
      [
        (_toss)->
          ext_func _toss.storeArgs 'data'
        (_toss)->
          ext_func _toss
      ]
      (_toss)->
        _fn3 = ->
          _toss null, 'a'
        setTimeout _fn3, 100
      (err, _toss)->
        debug '======================================'
        debug 'err intercept with storeArgs, fork:  expect not toEqual null =', err
        expect err
          .not.toEqual null
        _toss null
      (_toss)->
        _toss null, 9
    ]) (err, v)->
      debug 'result =', err, v
      expect err
        .toEqual null
      expect v
        .toEqual 9
      done()




describe 'cancel', ()->
  it 'cancel', (done)->

    test = 9
    call = (ficent [
      (_toss)->
        setTimeout _toss, 200
      (_toss)->
        test = 10
        _toss null

    ]) (err, v)->

    call.cancel()
    chk = ()->
      expect test
        .toEqual 9
      done()
    setTimeout chk, 500
  it 'fork cancel', (done)->

    test = 9
    test2 = -9
    call = (ficent.fork [
      [
        (_toss)->
          setTimeout _toss, 200
        (_toss)->
          test = 10
          _toss null
      ]
      [
        (_toss)->
          setTimeout _toss, 200
        (_toss)->
          test2 = 10
          _toss null
      ]
    ]) (err, v)->

    call.cancel()
    chk = ()->
      expect test
        .toEqual 9
      expect test2
        .toEqual -9
      done()
    setTimeout chk, 500



describe 'context', ()->
  it 'this in extend fn', (done)->
    # class A
    #   constructor :()->
    #     @var7 = 7
    #     console.log 'A.constructor'

    action = ficent [
      (v, _toss)->
        @var7 = 7
        _toss null
      (v, _toss)->
        _toss null, v * @var7, @var7
    ]

    action 8, (err, mul, v)->
      expect err
        .toEqual null
      expect mul
        .toEqual 7 * 8
      expect v
        .toEqual 7
      done()




  it 'function level this', (done)->
    runable_fn = ficent [
      (new_val, callback)->
        if new_val
          @context_var = new_val
        callback null
      (doing, callback)->
        callback null, @context_var
    ]

    runable_fn 7, (err, val)->
      expect err
        .toEqual null
      expect val
        .toEqual 7
      runable_fn undefined, (err, val)->
        expect err
          .toEqual null
        expect val
          .toEqual undefined

        runable_fn 11, (err, val)->
          expect err
            .toEqual null
          expect val
            .toEqual 11
          done()
