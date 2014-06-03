flyway = require '../src'
assert = require 'assert'
util = require 'util'

debug = require('debug')('test')

func1 = (ctx, next)-> 
  ctx.a = true
  next()
func2 = (ctx, next)-> 
  ctx.b = true
  next()

describe 'flow', ()->    
  it 'run with context arguments ', (done)-> 

    ctx = 
      name : 'context base'
    
    f = flyway [ func1, func2]
    # f (req,res,next)
    f ctx, (err, ctx )->
      debug  'arguments', arguments
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()

  it 'run with multiple context arguments ', (done)-> 

    ctx = {}
    ctx1 = {}
    ctx2 = {}
    
    f = flyway [ 
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
    
    g = flyway [func1, func2]

    f = flyway [ g ]

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

    f = flyway [ func1, func_mk_Err, func2, func_Err]
      
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

    f = flyway [ func1, func_mk_Err, func2]
      
    # f (req,res,next)
    f ctx, (err, ctx)->
      debug 'end ', arguments 
      assert util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b is undefined , "must not exist"

      done()


describe 'retry', ()->    
   
  it 'retry and fail ', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt
      next new Error 'FAKE'
    f = flyway [ func_mk_Err ]

    g = flyway [
      flyway.retry 3, f
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
    f = flyway [ func_mk_Err ]

    g = flyway.retry 5, f
    
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

    g = flyway.retry 5, func_mk_Err
    
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

    g = flyway [
      flyway.retry 5, func_mk_Err
    ]
    # f (req,res,next)
    g ctx, (err, ctx)->
      debug 'err, ctx', err, ctx
      assert not util.isError err, 'no error'
      assert ctx.tryCnt is 2 , 'try 2 and success' 
      done() 


describe 'map', ()->   
  it 'map', (done)->    
    data = [2..5]
    fn = (n, next)-> 
      # console.log 'fn', n
      next null, n * n
    flyway.map(fn) data, (errs, results)->
      # console.log 'err ' , errs
      # console.log 'results ' , results
      assert.equal results[0], 4
      done()


  it 'map obj', (done)->    
    data = 
      9 : 6
      2 : 8
    fn = (k, v, next)-> 
      # console.log 'fn', k, v
      next null, k * v
    flyway.map(fn) data, (errs, results)->
      # console.log 'err ' , errs
      # console.log 'results ' , results
      assert.equal results[2], 16
      done()

  it 'with CTX / no err check ', (done)-> 

    ctx = {
      name: 'this is multiplex context'
      } 
    g = flyway [
      (ctx, next)-> 
        ctx.num = ctx.num * ctx.num 
        next()
      (ctx, next)-> 
        ctx.num = ctx.num * 10
        next()
    ]
    inputs = []
    for x in [0..3]
      inputs[x] = 
        num : x 
    debug 'inputs',inputs
    # flyway.map inputs, g, (errs, results )->
    flyway.map(g) inputs, (errs, results )->  
      debug 'results', errs, results     
      assert not util.isError errs, 'no error'
      assert.equal results[1].num, 10, 
      done() 
  it 'with CTX / SIDM err  ', (done)-> 

    ctx = {
      name: 'this is multiplex context'
      } 
    g = flyway [
      (ctx, next)-> 
        ctx.num = ctx.num * ctx.num 
        if ctx.num is 1
          return next new Error "FAKE 1"
        next()
      (ctx, next)-> 
        debug 'f2 ', ctx, next
        ctx.num = ctx.num * 10
        if ctx.num is 0
          return next new Error "FAKE 2"
        next()
    ]
    inputs = []
    for x in [0..3]
      inputs[x] = 
        num : x 
    flyway.map(g) inputs,  (errs, results )->      
      debug 'results err', errs, results 
      assert util.isError errs, 'error'
      assert results[2].num is 40, 'not correct '
      done()
 

describe 'flow  - forkjoin', ()->    
  it 'base fork join ', (done)-> 

    ctx = {}
    
    f = flyway [ [func1, func2, (ctx,next)-> 
      ctx.zzz = 9
      debug 'fj', ctx
      next()
     ] ]  
      
    # f (req,res,next)
    f ctx, (err, ctx)->
      debug 'errs, ctx', err, ctx     
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist" 
      done()
   
  it 'with Err ', (done)-> 

    ctx = {}
    
    f = flyway [ [func1, func2, (ctx, next)->
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
  
  

describe 'chain', ()->     
  it 'basic', (done)-> 
    f1 = (a, b, next)-> 
      # console.log 'f1', a, b, next
      # return next new Error 'E'
      next null, a * b, a, b
    f2 = (a, b, c, next)-> 
      # console.log 'f2', a, b, c, next
      next null, a + b + c, a, b, c
    fn = flyway.chain [f1, f2]

    fn 2,3, (err, output, a, b, c)->

      # console.log 'err ', err
      # console.log   output, a, b, c
      assert.equal err, null
      assert.equal output, 11
      assert.equal a, 6
      assert.equal b, 2
      assert.equal c, 3
      done()
  it 'fork in chain', (done)-> 
    f1 = (a, b, next)-> 
      # console.log 'f1', a, b, next
      # return next new Error 'E'
      next null, a * b, a, b
    f2 = (a, b, c, next)-> 
      # console.log 'f2', a, b, c, next
      next null, a + b + c, a, b, c
    f3 = (a, b, c, d, next)-> next null, a + b +  c + d
    f4 = (a, b, c, d, next)-> next null, a - b, c - d
    f5 = (output, next)-> next null, output[0] * output[1][1] + output[1][0] 
    # f5 = (arr, next)-> flyway.map arr, fn, next
    fn = flyway.chain [f1, f2, [f3, f4], f5]

    fn 2,3, (err, output)->
      debug 'chain out', arguments
      # console.log 'err ', err
      # console.log   output, a, b, c
      assert.equal err, null
      assert.equal output, -17
      # assert.equal output[0], 22
      # assert.equal output[1][0], 5
      done()

  it 'fork', (done)-> 

    f3 = (a, b, c, d, next)-> next null, a + b +  c + d
    f4 = (a, b, c, d, next)-> next null, a - b, c - d
     # f5 = (arr, next)-> flyway.map arr, fn, next
    fn = flyway.fork [f3, f4]

    fn 2,3, 4, 5, (err, output)->
      debug 'chain out', arguments
      # console.log 'err ', err
      # console.log   output
      assert.equal err, null
      assert.equal output[0], 14
      assert.equal output[1][0], -1 
      assert.equal output[1][1], -1 
      # assert.equal output[0], 22
      # assert.equal output[1][0], 5
      done() 

  it 'map chain', (done)-> 
    f1 = (a, b, next)-> 
      # console.log 'f1', a, b, next
      # return next new Error 'E'
      next null, [a..b] 
    fn = (num, next)-> next null, num * num
    # f5 = (arr, next)-> flyway.map arr, fn, next
    fn = flyway.chain [f1, flyway.map flyway.chain [ fn, fn] ]

    fn 2,3, (err, output)->
      debug 'chain out', arguments
      # console.log 'err ', err
      # console.log   output, a, b, c
      assert.equal err, null
      assert.equal output[0], 16
      assert.equal output[1], 81
      # assert.equal output[0], 22
      # assert.equal output[1][0], 5
      done()
  it 'map reduce ', (done)-> 
    f1 = (a, b, next)-> 
      # console.log 'f1', a, b, next
      # return next new Error 'E'
      next null, [a..b] 
    fn = (num, next)-> next null, num * num
    fnR = (output, next)->
      v = output.reduce (acc , e)-> 
        acc + e
      next null, v 

    fnR = flyway.reduce 0, (acc , e, next)-> next null, acc + e
    # f5 = (arr, next)-> flyway.map arr, fn, next
    fn = flyway.chain [f1, (flyway.map flyway.chain [ fn, fn]), fnR ]

    fn 2,3, (err, output)->
      debug 'chain out', arguments
      # console.log 'err ', err
      # console.log   output, a, b, c
      assert.equal err, null
      assert.equal output, 97
      # assert.equal output[0], 22
      # assert.equal output[1][0], 5
      done()
 

describe 'series', ()->   
  it 'series', (done)->    
    data = [2..5]
    fn = (n, next)-> 
      # console.log 'fn', n
      next null, n * n
    flyway.series(fn) data, (errs, results)->
      # console.log 'err ' , errs
      # console.log 'results ' , results
      assert.equal results[0], 4
      done()



describe 'run now', ()->   
  it 'flow.run', (done)->    
    flyway.run {num:5}, [
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
    flyway.run  [
      (next)-> 
        # console.log 'arguments= ' ,arguments
        next()
      (next)-> 
        done()
    ]  


  it 'chain.run', (done)->    
    flyway.chain.run 5, [
      (num, next)-> 
        num += 10
        next(null, num)
      (num, next)-> 
        num -= 100
        next(null, num)
      (num, next)-> 
        assert.equal num, -85
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

    wrapper = flyway.wrap [init], [end]
    
    
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

    wrapper = flyway.wrap init, end
    
    
    wrapper(inFn) {}

# describe 'callback', ()->
#   it 'should take callback', (done)->

#     fire = (next)->
#       setTimeout next, 50

#     C1 = flyway.callback()
#     fire C1
#     C1.then ()->
#       done()
#   it 'should take passed callback', (done)->

#     fire = (next)-> next()
#     C1 = flyway.callback()
#     fire C1
#     C1.then ()->
#       done()
#   it 'should pass output when passed callback', (done)->

#     fire = (next)-> next null, 1,2,3,4,5
#     C1 = flyway.callback()
#     fire C1
#     C1.then (err, args...)->

#       expect(args).toEqual [1,2,3,4,5]
#       done()

#   it 'should take callback and output', (done)->

#     fire = (next)->
#       c = ()->  next null, 1,2,3,4,5
#       setTimeout c, 50
#       # c()
      
#     C1 = flyway.callback()
#     fire C1
#     C1.then (err, args...)->

#       expect(args).toEqual [1,2,3,4,5]
#       done()


#   it 'should wait all', (done)->

#     fire1 = (next)->
#       c = ()->  next null, 1,2,3,4
#       setTimeout c, 50
#       # c()
      
#     fire2 = (next)->
#       c = ()->  next null, 9,10,11
#       setTimeout c, 50
#       # c()
      
#     C1 = flyway.callback()
#     fire1 C1
#     C2 = flyway.callback()
#     fire2 C2
#     flyway.callback.waitAll(C1,C2).then (err, args)->
#       expect(args).toEqual [[1,2,3,4], [9,10,11]]
#       done()

#   it 'should work with done', (done)->

#     fire = (next)-> next.done()
#     C1 = flyway.callback()
#     fire C1
#     C1.then ()->
#       done()

#   it 'should pass error', (done)->

#     fire = (next)-> 
#       c = ()->  next new Error 'FAKE'
#       setTimeout c, 50
#       # c()

#     C1 = flyway.callback()
#     fire C1
#     C1.then (err)->
#       expect(err.name).toBe 'Error'
#       done()



# describe 'join', ()->

#   it 'should work', (done)->

#     join = flyway.join()

#     join.in()
#     join.in()


#     join.out (err, values...)->


describe 'delay', ()->    
  it 'delayed ', (done)-> 

    str = "A"
    fn = ()->
      str += "C"
    dfn = flyway.delay 100, fn

    dfn()
    str += 'B'

    setTimeout ()->
      expect(str).toEqual "ABC"
      done()

    , 100

  it 'run directly', (done)-> 
    str = "A"
    fn = (inStr = 'C')->
      str += inStr
    flyway.do flyway.delay 150, fn
    flyway.do 'D', flyway.delay  50, fn

    setTimeout ()->
      expect(str).toEqual "ADC"
      done()

    , 200
