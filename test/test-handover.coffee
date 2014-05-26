ho = require '../handover'
assert = require 'assert'

debug = require('debug')('test')

describe 'handover', ()->

  func1 = (ctx, next)-> 
    ctx.a = true
    next()
  func2 = (ctx, next)-> 
    ctx.b = true
    next()

  it 'base ', (done)-> 

    ctx = 
      name : 'context base'
    
    f = ho [ func1, func2]
    # f (req,res,next)
    f ctx, (err, ctx )->
      debug  'arguments', arguments
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
      assert ctx.a , "must exist"
      assert ctx.b , "must exist"

      done()

  it 'base fork join ', (done)-> 

    ctx = {}
    
    f = ho [ [func1, func2] ]  
      
    # f (req,res,next)
    f ctx, (err, ctx)->
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
      assert err is undefined, 'no error'
      assert ctx.a , "must exist"
      assert ctx.b is undefined , "must not exist"

      done()

  it 'array multiplex ', (done)-> 

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
    g.parallel inputs, (errs, outputs, next2 )->
      
      debug 'outputs', outputs
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
      f.fnRetry 5
    ]
    # f (req,res,next)
    g ctx, (err, ctx)->
      debug 'err, ctx', err, ctx
      assert ctx.tryCnt is 2 , 'try 2 and success'
      assert err is undefined, "must exist"
      done()
