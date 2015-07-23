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
  
  it 'run function created by flow.fn', (done)-> 

    ctx = 
      name : 'context base'
    

    _fn = ficent.fn [
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
    f = ficent.fn [ f1, f2]
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
    
    f = ficent.fn [ 
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
    
    g = ficent.fn [func1, func2]

    f = ficent.fn [ g ]

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

    f = ficent.fn [ func1, func_mk_Err, func2, func_Err]
      
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

    f = ficent.fn [ func1, func_mk_Err, func2]
      
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

    f = ficent.fn [ func_mk_Err, func_Err]
      
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

    f = ficent.fn [ func_mk_Err, func_Err]
      
    # f (req,res,next)
    f ctx, (err)->
      debug 'end ', arguments 
      assert util.isError err, 'occerror error'
      done()

 

describe 'fork', ()->    
  it 'basic', (done)->
    forkingFns = []
    ctx = 
      cnt : 0
    for i  in [0...5]
      forkingFns.push (next)->  
        ctx.cnt++
        next()
    f = ficent.fork forkingFns
    f (err)->
      assert ctx.cnt is 5 , 'fork count 5 ' 
      done()

  it 'with Err', (done)->
    forkingFns = []
    ctx = 
      cnt : 0
    for i  in [0...5]
      forkingFns.push (next)->  
        ctx.cnt++
        next new Error 'JUST'
    f = ficent.fork forkingFns
    f (err)->
      assert util.isError err, 'error'
      assert ctx.cnt is 5 , 'fork count 5 ' 
      done()

  it 'with arguments', (done)->
    forkingFns = []
    ctx = 
      cnt : 0
    for i  in [0...5]
      forkingFns.push (num, next)->  
        ctx.cnt += num
        next()
    f = ficent.fork forkingFns
    f 5, (err)->
      assert ctx.cnt is 25 , 'fork count 25 ' 
      done()
 

  it 'with arguments, no callback', (done)->
    forkingFns = []
    ctx = 
      cnt : 0
    for i  in [0...5]
      forkingFns.push (num, next)->  
        ctx.cnt += num
        next()
    f = ficent.fork forkingFns
    f 5
    assert ctx.cnt is 25 , 'fork count 25 ' 
    done()
 


describe 'flow  - forkjoin', ()->    
  it 'base fork join ', (done)-> 
    ctx = {}
    f = ficent.fn [ [func1, func2, (ctx,next)-> 
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
    
    f = ficent.fn [ [func1, func2, (ctx, next)->
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

    ctx = {}
    ctx1 = {}
    ctx2 = {}
    
    f = ficent.fn [ 
      (ctx, c1,c2, toss)-> 
        toss.tossValue = 9
        toss()
      (ctx, c1,c2,toss)->   
        ctx.tossed = toss.tossValue is 9
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

    output = {}
    f = ficent.fn [ 
      [
        (toss)-> 
          toss.b = 7
          toss()
        (toss)->   
          toss.a = 9
          toss()
      ]
      (toss)->
        toss.c = toss.a * toss.b
        output = toss
        toss null
      [
        (toss)-> 
          toss.c2 = toss.c * 2
          toss()
        (toss)->   
          toss.c3 = toss.c * 3
          toss()
      ] 
    ] 
    f (err)->
      debug 'toss data in fork', err
      expect err 
        .toBe undefined
      assert output.c is 63, '= 7 * 9 '
      assert output.c2 is 126, 'c * 2'
      assert output.c3 is 189, 'c * 3 '
      done()

  it 'toss err 1 ', (done)-> 

    output = {}
    f = ficent.fn [ 
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
    f = ficent.fn [ 
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
        _toss.g = 12
        _toss null
    ]
    f = ficent [
      (_toss)->
        debug 'double toss', 'f.a'
        _toss.a = 11
        _toss null
      (_toss)->
        debug 'double toss', 'f g()'
        g _toss
      (_toss)->
        debug 'double toss', 'ag'
        _toss.ag = _toss.a * _toss.g
        _toss null
      ]

    outCall = (err)->
      debug 'double toss', 'outCall'
      expect err
        .toBe null
      expect outCall.ag 
        .toEqual 11 * 12 
      done()
    f outCall

 
  it 'double toss params', (done)->
    g = ficent [
      (_toss)->
        debug 'double toss', 'g'
        _toss.g = 12
        _toss null, 19
    ]
    f = ficent [
      (_toss)->
        debug 'double toss', 'f.a'
        _toss.a = 11
        _toss null
      (_toss)->
        debug 'double toss', 'f g()'
        g _toss
      (_toss)->
        debug 'double toss', 'ag', '_toss.params',_toss.params
        _toss.ag = _toss.a * _toss.params[0]
        _toss null
      ]

    outCall = (err)->
      debug 'double toss', 'outCall'
      expect err
        .toBe null
      expect outCall.ag 
        .toEqual 11 * 19
      done()
    f outCall
# describe 'ficent.join', ()->
#   it 'throw in out()', (done)->

#     join = ficent.join()
#     join.out ()->
#       


describe 'hint', ()->

  it 'hint', (done)-> 
    a = ficent { name: 'function a()'}, (callback)->
      callback null
    a (err)->
      debug 'hint callback', arguments
      expect err 
        .toBe null
      expect a.hint.name 
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
      name: 'function f()'
    , forkingFns
    f (err)->
      assert not util.isError err, 'error'
      assert ctx.cnt is 5 , 'fork count 5 ' 
      expect f.hint.name 
        .toEqual 'function f()'
      done()

  it 'hint on error  ', (done)-> 
    a = ficent { name: 'function a()'}, (callback)->
      throw new Error 'TEST'
      f callback.err (err, val)-> 
        callback null
    a (err)->

      debug 'catch ', err.toString(), err.hint
      expect err 
        .not.toBe null
      expect err.hint.name 
        .toEqual 'function a()'
      done()


  it 'hint on error when wrap ficent ', (done)-> 
    
    b = ficent 
      name: 'function b()'
    , (callback)->
      do ficent { name: 'function a()'}, (callback)->
        throw new Error 'TEST'
        f callback.err (err, val)-> 
          callback null

    b (err)->
      debug 'catch ', err.toString(), err.hint
      expect err 
        .not.toBe null
      expect err.hint.name 
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
      name: 'function f()'
    , forkingFns
    f (err)->
      assert util.isError err, 'error'
      assert ctx.cnt is 5 , 'fork count 5 ' 
      expect err.hint.name 
        .toEqual 'function f()'
      done()

