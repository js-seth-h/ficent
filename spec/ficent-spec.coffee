process.env.DEBUG = "test"
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
    

    ficent.do ctx, [
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
  
  it 'run function created by flow.fn', (done)-> 

    ctx = 
      name : 'context base'
    

    _fn = ficent.fn [
      func1, 
      func2
    ]
    _fn ctx, (err, ctx)->
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
    f (err )->
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
    f ctx, ctx1, ctx2, (err, ctx )->
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
    f ctx, (err, ctx )->
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
    f ctx, (err, ctx)->
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
    f ctx, (err, ctx)->
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
    f ctx, (err, ctx)->
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
    f ctx, (err, ctx)->
      debug 'end ', arguments 
      assert util.isError err, 'occerror error'
      done()


describe 'retry', ()->    
   
  it 'retry and fail ', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt
      next new Error 'FAKE'
    f = ficent.fn [ func_mk_Err ]

    g = ficent.fn [
      ficent.retry 3, f
    ]
    # f (req,res,next)
    debug 'RETRY'
    g ctx, (err, ctx)->
      # debug err, ctx
      assert util.isError err, 'error'
      assert ctx.tryCnt is 3 , 'try 3'
      assert err, "must exist"
      done()
 
  it 'retry and success', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt
      if ctx.tryCnt is 2
        return next()
      next new Error 'FAKE'
    f = ficent.fn [ func_mk_Err ]

    g = ficent.retry 5, f
    
    # f (req,res,next)
    g ctx, (err, ctx)->
      debug 'err, ctx', err, ctx
      assert not util.isError err, 'no error'
      assert ctx.tryCnt is 2 , 'try 2 and success' 
      done()

  it 'call retry directly ', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt, ctx
      if ctx.tryCnt is 2
        return next null, ctx
      next new Error 'FAKE just fn' 

    g = ficent.retry 5, func_mk_Err
    
    # f (req,res,next)
    g ctx, (err, ctx)->
      debug 'err, ctx', err, ctx
      assert not util.isError err, 'no error'
      assert ctx.tryCnt is 2 , 'try 2 and success' 
      done()

  it 'call retry in flow', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt, ctx
      if ctx.tryCnt is 2
        return next null, ctx
      next new Error 'FAKE just fn' 

    g = ficent.fn [
      ficent.retry 5, func_mk_Err
    ]
    # f (req,res,next)
    g ctx, (err, ctx)->
      debug 'err, ctx', err, ctx
      assert not util.isError err, 'no error'
      assert ctx.tryCnt is 2 , 'try 2 and success' 
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
 
  it 'do with arguments', (done)->
    forkingFns = []
    ctx = 
      cnt : 0
    for i  in [0...5]
      forkingFns.push (num, next)->  
        ctx.cnt += num
        next()
    f = ficent.fork.do 5, forkingFns, (err)->
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
      
    f ctx, (err, ctx)->
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
    f ctx, (err, ctx)->
      debug 'errs, ctx', err, ctx  
      assert util.isError err, 'error'
      assert util.isError err.errors[2], 'error'
      debug err.toString()
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()
  

   


describe 'run now', ()->   
  it 'flow.do', (done)->    
    ficent.do {num:5}, [
      (ctx, next)-> 
        ctx.num += 10
        next()
      (ctx, next)-> 
        ctx.num -= 100
        next()
      (ctx, next)-> 
        assert.equal ctx.num, -85
        done()
    ]  


  it 'flow.run with no arg', (done)->    
    ficent.do  [
      (next)-> 
        # console.log 'arguments= ' ,arguments
        next()
      (next)-> 
        done()
    ]  





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
 
describe 'delay', ()->    
  it 'delayed ', (done)-> 

    str = "A"
    fn = ()->
      str += "C"
    dfn = ficent.delay 100, fn

    dfn()
    str += 'B'

    setTimeout ()->
      expect(str).toEqual "ABC"
      done()

    , 100
 

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
    f ctx, ctx1, ctx2, (err, ctx )->
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
    f (err )->
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
    f (err )->
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
    f (err )->
      debug err
      expect err 
        .not.toBe null
      done()

describe 'err catch', ()->
  f = (callback)-> callback null, 5
  e = (callback)-> callback new Error 'in E'
  it 'no err ', (done)-> 
    a = ficent.err (callback)->
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
    a = ficent.err (callback)->
      throw new Error 'TEST'
      f callback.err (err, val)-> 
        callback null
    a (err)->

      debug 'catch ', err
      expect err 
        .not.toBe null
      done()


  it 'catch inside ', (done)-> 
    a = ficent.err (callback)->
      f callback.err (err, val)-> 
        throw new Error 'TEST'
        callback null
    a (err)->

      debug 'catch  inside', err
      expect err 
        .not.toBe null
      done()


  it 'toss before callbacked', (done)-> 
    a = ficent.err (callback)->
      e callback.err (err, val)-> 
        throw new Error 'TEST2'
        callback null
    a (err)->
      debug 'toss before callbacked ', err
      expect err 
        .not.toBe null
      done()
