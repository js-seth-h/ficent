ho = require '../handover'
assert = require 'assert'
util = require 'util'

debug = require('debug')('handover-test')

func1 = (ctx, next)-> 
  ctx.a = true
  next()
func2 = (ctx, next)-> 
  ctx.b = true
  next()
describe 'handover', ()->    
  it 'base ', (done)-> 

    ctx = 
      name : 'context base'
    
    f = ho [ func1, func2]
    # f (req,res,next)
    f ctx, (err, ctx )->
      debug  'arguments', arguments
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()

  it 'context * 3 ', (done)-> 

    ctx = {}
    ctx1 = {}
    ctx2 = {}
    
    f = ho [ 
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

  it 'nesting ', (done)-> 

    ctx = {}
    
    g = ho [func1, func2]

    f = ho [ g ]

    # f (req,res,next)
    f ctx, (err, ctx )->
      debug  'arguments', arguments
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()


  it 'error jump ', (done)-> 

    ctx = {}
    func_mk_Err = (ctx, next)->
      debug 'mk Err'
      next new Error 'FAKE'
    func_Err = (err, ctx, next)->
      debug 'got Err',err
      assert err, 'must get Error'
      next()

    f = ho [ func1, func_mk_Err, func2, func_Err]
      
    # f (req,res,next)
    f ctx, (err, ctx)->
      debug 'end ', arguments 
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b is undefined , "must not exist"

      done()


   
  it 'retry ', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt
      next new Error 'FAKE'
    f = ho [ func_mk_Err ]

    g = ho [
      f.fnRetry 3
    ]
    # f (req,res,next)
    debug 'RETRY'
    g ctx, (err, ctx)->
      debug err, ctx
      assert util.isError err, 'error'
      assert ctx.tryCnt is 3 , 'try 3'
      assert err, "must exist"
      done()
 
  it 'retry stop', (done)-> 

    ctx = 
      tryCnt : 0
    
    func_mk_Err = (ctx, next)->
      ctx.tryCnt++
      debug 'mk Err', ctx.tryCnt
      if ctx.tryCnt is 2
        return next()
      next new Error 'FAKE'
    f = ho [ func_mk_Err ]

    g = ho [
      ho.retry 5, f
    ]
    # f (req,res,next)
    g ctx, (err, ctx)->
      debug 'err, ctx', err, ctx
      assert not util.isError err, 'no error'
      assert ctx.tryCnt is 2 , 'try 2 and success' 
      done()

describe 'handover SIDM', ()->   
  it 'SIDM no err check ', (done)-> 

    ctx = {
      name: 'this is multiplex context'
      } 
    g = ho [
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
    ho.map inputs, g, (errs, results )-> 
      debug 'results', errs, results     
      assert not util.isError errs, 'no error'
      assert.equal results[1].num, 10, 
      done() 
  it 'SIDM err  ', (done)-> 

    ctx = {
      name: 'this is multiplex context'
      } 
    g = ho [
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
    ho.map inputs, g,  (errs, results )->      
      debug 'results', errs, results 
      assert util.isError errs, 'error'
      assert results[2].num is 40, 'not correct '
      done()



describe 'handover forkjoin', ()->    
  it 'base fork join ', (done)-> 

    ctx = {}
    
    f = ho [ [func1, func2] ]  
      
    # f (req,res,next)
    f ctx, (err, ctx)->
      debug 'errs, ctx', err, ctx     
      assert not util.isError err, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b , "must exist" 
      done()
   
  it 'base fork join ', (done)-> 

    ctx = {}
    
    f = ho [ [func1, func2, (ctx, next)->
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



describe 'handover compose', ()->    
  it 'compose', (done)-> 
    f1 = (a, b, next)-> 
      # console.log 'f1', a, b, next
      # return next new Error 'E'
      next null, a * b, a, b
    f2 = (a, b, c, next)-> 
      # console.log 'f2', a, b, c, next
      next null, a + b + c, a, b, c
    fn = ho.compose f1, f2

    fn 2,3, (err, output, a, b, c)->

      # console.log 'err ', err
      # console.log   output, a, b, c
      assert.equal err, null
      assert.equal output, 11
      assert.equal a, 6
      assert.equal b, 2
      assert.equal c, 3
      done()
 
describe 'handover map', ()->    
  it 'map', (done)->    
    data = [2..5]
    fn = (n, next)-> 
      # console.log 'fn', n
      next null, n * n
    ho.map data, fn, (errs, results)->
      # console.log 'err ' , errs
      # console.log 'results ' , results
      assert.equal results[0], 4
      done()


  it 'map obj', (done)->    
    data = 
      9 : 6
      2 : 8
    fn = (k, v, next)-> 
      console.log 'fn', k, v
      next null, k * v
    ho.map data, fn, (errs, results)->
      console.log 'err ' , errs
      console.log 'results ' , results
      assert.equal results[2], 16
      done()