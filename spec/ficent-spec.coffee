process.env.DEBUG = "test, ficent"
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
    
    fx = ficent {desc: 'fx'}, [
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
    ctx = 
      name : 'context base'
    
    fx = ficent (err, ctx, next)->
      debug  'arguments', arguments
      throw new Error 'Fake'
    fx ctx, (err)->
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
        _toss.var 'a', true
        _toss null
      (_toss)-> 
        _toss.var 'b', true
        _toss.var 'ctx', {cnt: 0 }
        _toss null
      (_toss)-> 
        return _toss.goto 'here'
      (_toss)-> 
        _toss.var('ctx').cnt++
        _toss.var 'c', true
        _toss null
      (_toss)-> 
        _toss.var 'd', true
        _toss null
      (_toss)-> 
        _toss.var 'e', true
        _toss null
      'here'
      (_toss)-> 
        _toss.var 'g', true
        _toss null, _toss.var 'ctx'
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
        _toss.var 'a', true
        _toss null
      (_toss)-> 
        _toss.var 'b', true
        _toss.var 'ctx', {cnt: 0 }
        _toss null
      'here'
      (_toss)-> 
        _toss.var('ctx').cnt++
        _toss.var 'c', true
        _toss null
      (_toss)-> 
        _toss.var 'd', true
        _toss null
      (_toss)-> 
        _toss.var 'e', true
        _toss null
      (_toss)-> 

        f = _toss.var 'f'
        _toss.var 'f', true
        unless f
          return _toss.goto 'here'
        _toss null
      (_toss)-> 
        _toss.var 'g', true
        _toss null, _toss.var 'ctx'
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
        _toss.var 'a', 99
        _toss.return null, _toss
      (_toss)-> 
        _toss.var 'a', 88
        _toss null, _toss
    ]
    # f (req,res,next)
    f (err, obj)-> 
      debug 'err ', err
      expect err
        .toEqual null
      expect obj.var('a')
        .toEqual 99
      done()

  
describe 'toss function', ()->
  it 'function', (done)-> 
    ctx = {}
    f = ficent.flow [ 
      (_toss)-> 
        _toss.var 'a', true
        _toss.setValue = (x)->
          ctx.x = x
        _toss null
      (_toss)-> 
        _toss.setValue 10
        _toss null
      (_toss)-> 
        _toss.var 'g', true
        _toss null, _toss.var 'ctx'
    ]
    # f (req,res,next)
    f (err, obj)-> 
      debug 'err ', err
      expect err
        .toEqual null
      expect ctx.x
        .toEqual 10
      done()

  it 'cross ficent', (done)-> 
    ctx = {}
    g = ficent.flow (_toss)->
      # _toss.setValue 112
      _toss null, 112
    f = ficent.flow [ 
      (_toss)-> 
        _toss.setValue = (x)->
          ctx.x = x
        _toss null
      (_toss)->
        g (err, num)->
          _toss.setValue num
          _toss null
      (_toss)-> 
        _toss null
    ]
    # f (req,res,next)
    f (err)-> 
      debug 'err ', err
      expect err
        .toEqual null
      expect ctx.x
        .toEqual 112
      done()

  it 'cross ficent with toss.err', (done)-> 
    ctx = {}
    g = ficent.flow (_toss)->
      _toss null, 112
    f = ficent.flow [ 
      (_toss)-> 
        _toss.setValue = (x)->
          ctx.x = x
        _toss null
      (_toss)->
        g _toss.err (err, num)->
          _toss.setValue num
          _toss null
      (_toss)-> 
        _toss null
    ]
    # f (req,res,next)
    f (err)-> 
      debug 'err ', err
      expect err
        .toEqual null
      expect ctx.x
        .toEqual 112
      done()
  it 'cross ficent with toss.setVar', (done)-> 
    ctx = {}
    g = ficent.flow (_toss)-> 
      _toss null, 'g-string'
    f = ficent.flow [  
      (_toss)->
        g _toss.setVar 'g-value'
      (_toss)-> 
        _toss null, _toss.var 'g-value'
    ]
    # f (req,res,next)
    f (err, g_value)-> 
      debug 'err ', err
      expect err
        .toEqual null 
      expect g_value
        .toEqual 'g-string'
      done()

  # it 'cross ficent with ficent.serial', (done)-> 
  #   ctx = {}
  #   f = ficent.flow {desc:'ser-wrap' }, [ 
  #     (_toss)-> 
  #       _toss.setValue = (x)->
  #         ctx.x = x
  #       _toss null
  #     (_toss)->
  #       _fn  = ficent.ser {desc:'ser-test'}, [ (x, _toss)->
  #         _toss.setValue x
  #         _toss.getMulti = ()->
  #           return x * x 
  #         _toss null 
  #       ]
  #       _fn [200], _toss
  #     (_toss)->
  #       _toss null, _toss.getMulti()
  #   ]
  #   # f (req,res,next)
  #   f (err, m )-> 
  #     debug 'err ', err
  #     expect err
  #       .toEqual null
  #     expect ctx.x
  #       .toEqual 200
  #     expect m
  #       .toEqual 200 * 200 
  #     done()
  # it 'cross ficent with ficent.parallel', (done)-> 
  #   ctx = {}
  #   f = ficent.flow {desc:'par-wrap' }, [ 
  #     (_toss)-> 
  #       _toss.setValue = (x)->
  #         ctx.x = x
  #       _toss null
  #     (_toss)->
  #       _fn  = ficent.par {desc:'par-test'}, [ (x, _toss)->
  #         _toss.setValue x
  #         _toss.getMulti = ()->
  #           return x * x 
  #         _toss null 
  #       ]
  #       _fn [200], _toss
  #     (_toss)->
  #       _toss null, _toss.getMulti()
  #   ]
  #   # f (req,res,next)
  #   f (err, m )-> 
  #     debug 'err ', err
  #     expect err
  #       .toEqual null
  #     expect ctx.x
  #       .toEqual 200
  #     expect m
  #       .toEqual 200 * 200 
  #     done()

describe 'fork', ()->    
  it 'basic', (done)-> 

    f = ficent.fork {desc: 'fx'}, [
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
      assert ctx.cnt is 5 , 'fork count 5 ' 
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

    f = ficent {desc: 'fx'}, [
      [ 
        (ctx, _toss)->  
          _toss null, 1, 2
        (ctx, _toss)->
          _toss null, 'a', 'b'
      ]
      (ctx, _toss)->
        debug 'param', _toss.args()
        _toss null, _toss.args()...
    ]
    f (err, result )->
      # assert ctx.cnt is 5 , 'fork count 5 ' 
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
      assert util.isError err.errors[2], 'error'
      debug err.toString()
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
        toss.var 'tossValue', 9
        toss()
      (ctx, c1,c2,toss)->   
        ctx.tossed = toss.var('tossValue') is 9
        toss()
    ]
    # f (req,res,toss)
    f ctx, ctx1, ctx2, (err)->
      debug  'toss data', arguments
      expect err 
        .toBe undefined

      assert ctx.tossed is true, 'must be tossed'

      done()
 
  it 'toss data in fork ', (done)-> 
    debug '---------------------', 'toss data in fork'
    # output = {}
    f = ficent.flow [ 
      [
        (toss)-> 
          toss.var 'b', 7
          toss()
        (toss)->   
          toss.var 'a', 9
          toss()
      ]
      (toss)->
        debug 'a?, b?', toss.var('a'), toss.var('b')
        toss.var 'c', toss.var('a') * toss.var('b')
        # output = toss
        # debug 'when FN 3 ', toss.toss_props()
        toss null
      [
        (toss)-> 
          # debug 'FN4-1 = ', toss.toss_props() 
          toss.var 'c2', toss.var('c') * 2
          debug 'mk c2', toss.var('c')
          toss()
        (toss)->   
          # debug 'FN4-1 = ', toss.toss_props()
          toss.var 'c3', toss.var('c') * 3
          debug 'mk c3', toss.var('c')
          # l = ''
          # l += "#{k}:#{v},"  for own k, v of toss

          toss()
      ] 
      (toss)->
        toss null, toss
    ] 
    f (err, output)->
      debug '========================'
      debug 'toss data in fork'
      if err
        console.error err
        console.error err.stack
      try
        for own k, v of arguments.callee
          debug 'kv', k, v
        expect err 
          .toBe null

        expect output.var('c')
          .toEqual 63
        # assert output.c is 63, '= 7 * 9 '
        expect output.var('c2')
          .toEqual 126
        expect output.var('c3')
          .toEqual 189
        # assert output.c2 is 126, 'c * 2'
        # assert output.c3 is 189, 'c * 3 '
      catch e 
        console.error e
        console.error e.stack

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
      debug err
      expect err 
        .not.toBe null
      done()

  f = (callback)-> callback null, 5
  e = (callback)-> callback new Error 'in E'
  it 'no err ', (done)-> 
    a = ficent (callback)->
      debug 1
      f callback.err (err, val)-> 
        debug 2
        callback null
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
    g = ficent [
      (_toss)->
        debug 'double toss', 'g'
        _toss.var 'g', 12
        _toss null
    ]
    f = ficent [
      (_toss)->
        debug 'double toss', 'f.a'
        _toss.var 'a', 11
        _toss null
      (_toss)->
        debug 'double toss', 'f g()'
        g _toss
      (_toss)->
        debug 'double toss', 'ag'
        _toss.var 'ag', _toss.var('a') * _toss.var('g')
        _toss null, _toss
      ]

    outCall = (err, outCall)->
      debug 'double toss', 'outCall'
      expect err
        .toBe null
      expect outCall.var 'ag' 
        .toEqual 11 * 12 
      done()
    f outCall

 
  it 'double toss args()', (done)->
    g = ficent [
      (_toss)->
        debug 'double toss', 'g'
        _toss.var 'g', 12
        _toss null, 19
    ]
    f = ficent [
      (_toss)->
        debug 'double toss', 'f.a'
        _toss.var 'a', 11
        _toss null
      (_toss)->
        debug 'double toss', 'f g()'
        g _toss
      (_toss)->
        debug 'a, b',  _toss.var('a'), _toss.var 'g'
        _toss.var 'ag', _toss.var('a') * _toss.var 'g'
        _toss null
      (_toss)->
        debug 'back 1,2,3'
        _toss null, 1, 2, 3
      (_toss)->
        debug 'args()', _toss.args()
        _toss.var 'in_args', _toss.args()
        _toss null
      (_toss)->
        expect _toss.var 'ag' 
          .toEqual 11 * 12
        expect _toss.var 'in_args'
          .toEqual [1,2,3]
        _toss null
    ]

    outCall = (err)->
      debug 'double toss', 'outCall'      
      expect err
        .toBe null

      done()
    f outCall

# describe 'ficent.join', ()->
#   it 'throw in out()', (done)->

#     join = ficent.join()
#     join.out ()->
#         

describe 'hint', ()->

  it 'hint', (done)-> 
    a = ficent { nick: 'function a()'}, (callback)->
      callback null
    a (err)->
      debug 'hint callback', arguments
      expect err 
        .toBe null
      expect a.nick 
        .toEqual 'function a()'
      done() 
  
  it 'hint fork', (done)-> 
    ctx = 
      cnt : 0

    forkingFns = [0...5].map (cnt)->
      return (next)->  
        ctx.cnt++
        next null
    f = ficent.fork 
      nick: 'function f()'
    , forkingFns
    f (err)->
      assert not util.isError err, 'error'
      assert ctx.cnt is 5 , 'fork count 5 ' 
      expect f.nick 
        .toEqual 'function f()'
      done()

  it 'hint on error  ', (done)-> 
    a = ficent { nick: 'function a()'}, (callback)->
      throw new Error 'TEST'
      f callback.err (err, val)-> 
        callback null
    a (err)->

      debug 'catch ', err.toString(), err.hint
      expect err 
        .not.toBe null
      expect err.hint.nick 
        .toEqual 'function a()'
      expect err.ficentFn.nick 
        .toEqual 'function a()'

      done()


  it 'hint on error when wrap ficent ', (done)-> 
    
    b = ficent 
      nick: 'function b()'
    , (callback)->
      do ficent { nick: 'function a()'}, (callback)->
        throw new Error 'TEST'
        f callback.err (err, val)-> 
          callback null

    b (err)->
      debug 'catch ', err.toString(), err.hint
      expect err 
        .not.toBe null
      expect err.ficentFn.nick 
        .toEqual 'function a()'
      expect err.hint.nick 
        .toEqual 'function a()'
      done()





  it 'hint on error with fork', (done)->
    ctx = 
      cnt : 0

    forkingFns = [0...5].map (cnt)->
      return (next)->  
        ctx.cnt++
        next new Error 'Fake'
    f = ficent.fork 
      nick: 'function f()'
    , forkingFns
    f (err)->
      assert util.isError err, 'error'
      assert ctx.cnt is 5 , 'fork count 5 ' 
      # expect err.hint.nick 
      #   .toEqual 'function f()'
      done()



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
      debug 'err ', err
      expect err
        .not.toEqual null
      done()



# describe 'ficent complex', ()->    

#   it ' seq - mux - seq ', (done)-> 
      
#     debug '========================================================'
#     debug ' ficent complex'
#     f = ficent [
#       (param, _toss)->
#         # debug 'F1', arguments
#         _toss null, 1
#       [
#         (param, _toss)->

#           # debug 'F2', arguments
#           _toss null, 2
#         (param, _toss)->
#           # debug 'F3', arguments
#           _toss null, 3
#       ]
#       (err, param, _toss)->
#         # debug 'F4', arguments
#         _toss null, 4
#     ]


#     f {}, (err, param, _toss)->
#       expect err
#         .toEqual null
#       done()



describe 'ficent seq, par', (done)->    
  # it 'flow ', (done)->  
  #   callback = (err)-> 
  #     expect err
  #       .toEqual null
  #     # assert not util.isError err, 'no error'
  #     expect ctx.a 
  #       .toBeTruthy()
  #     expect ctx.b
  #       .toBeTruthy()
  #     done() 
  #   ctx = 
  #     name : 'context base'
    

  #   ficent.do ctx, [
  #       func1, 
  #       func2
  #     ], callback

  # it 'fork', (done)->
  #   forkingFns = []
  #   ctx = 
  #     cnt : 0
  #   for i  in [0...5]
  #     forkingFns.push (next)->  
  #       ctx.cnt++
  #       next()
  #   # f = ficent.fork forkingFns
  #   callback = (err)->
  #     assert ctx.cnt is 5 , 'fork count 5 ' 
  #     done()

  #   ficent.do [forkingFns], callback

  it 'par', (done)->  
    input = [3, 6, 9]
    taskFn = ficent.par (num, next)->
      debug 'par in', num 
      next null, num * 1.5 
    taskFn input, (err, results)->
      debug 'par, callback', arguments
      # assert ctx.cnt is 5 , 'fork count 5 ' 
      expect results
        .toEqual [4.5, 9, 13.5]
      done()

  it 'ser', (done)-> 
    input = [3, 6, 9]
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

  it 'setVar', (done)->
    async_ab = (callback)->
      callback null, 1, 2 
    taskFn = ficent [
      (_toss)->
        _toss.var 'c', 20
        async_ab _toss.setVar 'a', 'b'
      (err, _toss)->
        expect _toss.var 'a'
          .toEqual 1 
        expect _toss.var 'b'
          .toEqual 2
        expect _toss.var 'c'
          .toEqual 20
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
