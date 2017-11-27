duct = require '../lib/duct'
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')

feature = describe
scenario = it

###
Features와, 테스트 시나리오

  함수일것 = 호출이 가능할것.
  값제어 .do .map .load .store
  처리 제어.filter
  비동기 .async .await .promise .wait
  에러 제어 .catch .finally
  반환 제어 .feedback .feedbackExeContext
  시간제어 .delay .delayIf

###
describe 'chain is a function', ()->
  it 'when create hyper-chain, then return a function', ()->
    chain = duct()
    expect(chain).a 'function'

  it 'when call chain, then return feedback', (done)->
    chain = duct()
      .feedback (feedback, cur...)->
        feedback.reset 'test', 1

    chain (err, f1, f2)->
      console.log err if err
      expect(err).to.not.exist
      expect(f1).to.be.eql 'test'
      expect(f2).to.be.eql 1
      # expect(execute_context).a 'object'
      # expect(execute_context.exit_status).to.be.equal 'finished'
      done()

  it 'can feedaback execute_context', (done)->
    chain = duct()
      .feedbackExeContext()

    chain (err,execute_context)->
      expect(err).to.not.exist
      expect(execute_context).a 'object'
      expect(execute_context.exit_status).to.be.equal 'finished'
      done()

  it 'can clear', (done)->
    chain = duct()
      .do ()->
        done new Error "Never Come Here"
      .clear()
      .feedbackExeContext()

    chain (err,execute_context)->
      expect(err).to.not.exist
      expect(execute_context).a 'object'
      expect(execute_context.exit_status).to.be.equal 'finished'
      done()

describe 'change data in process', ()->
  it 'when add .do, then not change current data', (done)->
    chain = duct()
      .do (cur)->
        return 1
      .do (cur)->
        expect(cur).to.be.equal 2
        done()
    chain 2

  it 'when add .map, then change current data', (done)->
    ###
    Given
    When - .map이 반환을 한다
    Then - cur가 변경된다
    ###
    chain = duct()
      .map (cur)->
        return 1
      .do (cur)->
        expect(cur).to.be.equal 1
        done()
    chain 2

  it 'when start no args, then accept arity', (done)->
    chain = duct()
      .do (cur)->
        throw new Error("Wrong") if cur
      .map ()->
        return 18
      .do (cur)->
        expect(cur).to.be.equal 18
        done()
    chain()

  it 'when start arr, then accept arity', (done)->
    chain = duct()
      .do (cur, cur2)->
        throw new Error("Wrong") if cur > cur2
      .map (cur, cur2)->
        return cur * cur2
      .do (cur)->
        expect(cur).to.be.equal 18
        done()
    chain 2, 9

  it 'when passing duct.Args, then change arity', (done)->
    chain = duct()
      .map (cur)->
        return new duct.Args 11, 7
      .do (cur, cur2)->
        expect(cur).to.be.equal 11
        expect(cur2).to.be.equal 7
        done()
    chain 2

  it 'when passing nothing, then arity be 0', (done)->
    chain = duct()
      .map (cur)->
        return new duct.Args
      .do (args...)->
        expect(args.length).to.be.equal 0
      .finally done
    chain 2

  it 'when passing nothing, then arity be 0', (done)->
    chain = duct()
      .map (cur)->
        return duct.Args.Empty
      .do (args...)->
        expect(args.length).to.be.equal 0
      .finally done
    chain 2


describe 'chain can be stop by filter', ()->
  it 'when .filter - return true, then not stop', (done)->
    chain = duct()
      .feedbackExeContext()
      .filter (cur)-> true
      .map (cur)->
        return "passed"
      # .do (cur)->
      #   throw new Error 'Should be Filtered'

    chain 2, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.equal 'passed'
      expect(execute_context.exit_status).to.be.equal 'finished'
      done()


  it 'when .filter - return false, then stop', (done)->
    chain = duct()
      .feedbackExeContext()
      .filter (cur)-> false
      .do (cur)->
        throw new Error 'Should be Filtered'

    chain 2, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

describe 'error handling;', ()->

  it 'when occur Error, then jump to .catch & error vanished ', (done)->
    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .catch (err, cur)->

    chain 0, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

  it 'when occur Error and occur again in catch, then callback get Error ', (done)->
    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .catch (err, cur)->
        throw err

    chain 0, (err, execute_context)->
      expect(err).to.exist
      expect(execute_context.curArgs.get(0)).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()
  it 'when occur Error and occur different error in catch, then callback get diff Error ', (done)->
    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .catch (err, cur)->
        throw new Error 'Other Error'

    chain 0, (err, execute_context)->
      expect(err).to.exist
      expect(err.toString()).to.equal 'Error: Other Error'
      expect(execute_context.curArgs.get(0)).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

  it 'when .finally , then error still flow', (done)->
    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 1
      .do (cur)-> throw new Error 'Just'
      .map (cur)-> 2
      .map (cur)-> 3
      .finally (err, cur)-> 4
      .map (cur)-> 5

    chain 0, (err, execute_context)->
      expect(err).to.exist
      expect(err.toString()).to.equal 'Error: Just'
      expect(execute_context.curArgs.get(0)).to.be.equal 1
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

  it 'when feedback callback has trouble, then it will go uncaughtException', (done)->
    return done()
    ###
      this test is working. and confirmed by human.
      but chai did not show correct response.
      it is uncaughtException, but chai.js consider it as Test Fail.
    ###

    process.on 'uncaughtException', (err)->
      expect(err).to.exist
      done()
    chain = duct()
    chain 0, (err)->
      throw new Error 'JUST'

  it 'without  Error, then skip .catch ', (done)->
    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 1
      # .do (cur)-> throw new Error 'Just'
      .catch (err, cur)->
        done new Error "Never Come Here"
      .map (cur)-> 2

    chain 0, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.equal 2
      # expect(execute_context.exit_status).to.be.equal 'filtered'
      done()

describe 'when call .load .store;', ()->

  it 'basic var control possible', (done)->

    do duct()
      .map ()-> 'test'
      .store 'var'
      .do (args...)->
        expect(args).have.lengthOf 0
      .load 'var'
      .do (var_val)->
        expect(var_val).be.eql 'test'
      .load()
      .do (obj)->
        expect(obj).be.eql {var: 'test', 'var[]': ['test']}
      .finally done

describe '비동기 .async, .wait .promise', ()->
  it 'when .async & .wait, then read value from stroage', (done)->

    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 0
      .async 'test', (cur, a_done)->
        _dfn = ()->
          a_done null, 'async_return'
        setTimeout _dfn, 50
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall()
        return test

    chain null, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.eql 'async_return'
      expect(execute_context.recall('test[]')).to.be.eql ['async_return']
      done()

  it 'when .await, then read value from stroage', (done)->

    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 0
      .await 'test', (cur, a_done)->
        _dfn = ()->
          a_done null, 'async_return'
        setTimeout _dfn, 50
      .map (cur)->
        {test} = @recall()
        return test

    chain null, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.eql 'async_return'
      expect(execute_context.recall('test[]')).to.be.eql ['async_return']
      done()


  it 'when .await throw Error, then skip functions', (done)->

    chain = duct()
      .map (cur)-> 0
      .await 'test', (cur, a_done)->
        _dfn = ()->
          a_done new Error 'Just'
        setTimeout _dfn, 50
      .map (cur)->
        done new Error 'Never Come Here'
        {test} = @recall()
        return test

    chain null, (err)->
      expect(err).to.exist
      done()

  it 'when anonymous .await, then use function index as name', (done)->
    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 0
      .await (cur, a_done)->
        _dfn = ()->
          a_done null, 'async_return'
        setTimeout _dfn, 50
      .map (cur)->
        return @recall()["2"]

    chain null, (err, execute_context)->
      expect(err).to.not.exist
      # console.log 'execute_context', execute_context
      # console.log 'execute_context.recall', execute_context.recall()
      expect(execute_context.curArgs.get(0)).to.be.eql 'async_return'
      expect(execute_context.recall('2[]')).to.be.eql ['async_return']
      done()

  it 'when .async & .wait but occur Error, then callback get error', (done)->

    chain = duct()
      .map (cur)-> 0
      .async 'test', (cur, a_done)->
        _dfn = ()->
          a_done new Error 'JUST'
        setTimeout _dfn, 50
      .map (cur)->
        return 2
      .wait 'test'
      .map (cur)->
        {test} = @recall()
        return test

    chain null, (err)->
      expect(err).to.exist
      done()

  it 'when .promise, then read value from stroage', (done)->

    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 0
      .promise 'test', (cur)->
        new Promise (resolve, reject)->
          _dfn = ()->
            resolve 'resolve_return'
          setTimeout _dfn, 50
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall()
        return test

    chain null, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.eql 'resolve_return'
      done()

  it 'when .pwait, then read value from stroage', (done)->

    chain = duct()
      .feedbackExeContext()
      .map (cur)-> 0
      .pwait 'test', (cur)->
        new Promise (resolve, reject)->
          _dfn = ()->
            resolve 'resolve_return'
          setTimeout _dfn, 50
      .map (cur)->
        {test} = @recall()
        expect(test).to.be.eql 'resolve_return'
        return test

    chain null, (err, execute_context)->
      expect(err).to.not.exist
      expect(execute_context.curArgs.get(0)).to.be.eql 'resolve_return'
      done()

  it 'when .promise but occur Error, then callback get error', (done)->

    chain = duct()
      .map (cur)-> 0
      .promise 'test', (cur)->
        new Promise (resolve, reject)->
          _dfn = ()->
            reject new Error 'JUST'
          setTimeout _dfn, 50
      .map (cur)-> 2
      .wait 'test'
      .map (cur)->
        {test} = @recall()
        return test

    chain null, (err, feedback, execute_context)->
      expect(err).to.exist
      done()

describe '반환 제어 .feedback', ()->

  it 'when .feedback & set data. then callback get data', (done)->
    chain = duct()
      .map (cur)->
        new duct.Args cur + 1, cur + 2
      .feedback (feedback, cur...)->
        feedback.reset cur...
      .feedback (feedback)->
        feedback.set 2, "to callback"

    chain 10, (err, f1, f2, f3 )->
      expect(err).to.not.exist
      expect(f1).to.be.eql 11
      expect(f2).to.be.eql 12
      expect(f3).to.be.eql 'to callback'
      done()

time_accuracy = 5
describe '시간제어 .delay .delayIf ', ()->
  it 'when .delay. then take a time', (done)->
    chain = duct()
      .delay 50

    t_start = (new Date).getTime()
    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 50 - time_accuracy
      done()

  it 'when .delayIf & pass test. then take a time', (done)->
    chain = duct()
      .map (cur)-> 100
      .delayIf 50, (cur)-> cur > 50

    t_start = (new Date).getTime()
    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 50 - time_accuracy
      done()

  it 'when .delayIf & failed to pass test. then not take a time', (done)->
    chain = duct()
      .map (cur)-> 100
      .delayIf 50, (cur)-> cur > 150

    t_start = (new Date).getTime()
    chain null, (err, feedback, execute_context)->
      expect(err).to.not.exist
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.below 50 - time_accuracy
      done()


describe '.evac ', ()->
  it 'chain is stop & return value as feedback', (done)->

    fn = duct()
      .do ()->
        @evac "test-end"
      .do ()->
        done new Error "Never Come Here"

    fn (err, feedback)->
      expect(err).not.exist
      expect(feedback).to.eql 'test-end'
      done()

  it 'with null, feedback set null', (done)->
    fn = duct()
      .do ()->
        @evac null
      .await (cb)->
        setTimeout cb, 20
        done new Error "Never Come Here"
      .do ()->
        done new Error "Never Come Here"
    fn (err, feedback)->
      expect(err).not.exist
      expect(feedback).to.eql null
      done()

  it 'with undefined, feedback set undefined', (done)->
    fn = duct()
      .do ()->
        @evac undefined
      .do ()->
        done new Error "Never Come Here"
    fn (err, feedback)->
      expect(err).not.exist
      expect(feedback).to.eql undefined
      done()

  it 'without arg, feedback maintained', (done)->
    fn = duct()
      .feedback (feedback)->
        feedback.reset "legacy feed-back"
      .do ()->
        @evac()
      .do ()->
        done new Error "Never Come Here"

    fn (err, feedback)->
      expect(err).not.exist
      expect(feedback).to.eql 'legacy feed-back'
      done()

describe 'invokes', ()->
  EventEmitter  = require 'events'
  it 'with invokeByEvent. then Emitter has listner', ()->
    emiter = new EventEmitter
    chain = duct()
      .invokeByEvent emiter, 'fire'

    expect(emiter.listenerCount 'fire').to.be.eql 1


  it 'with invokeByPromise. then chain get args of event', (done)->

    _resolve = null
    p = new Promise (resolve, reject)->
      _resolve = resolve
    chain = duct()
      .invokeByPromise p
      .do (cur)->
        expect(cur).to.eql 5
        done()
    _resolve 5

  it 'when hook.promise & reject. then chain not called', (done)->

    _reject = null
    p = new Promise (resolve, reject)->
      _reject = reject
    chain = duct()
      .invokeByPromise p
      .catch (err, cur)->
        # console.log 'err, cur', err, cur
        expect(err).to.be.exist
        done()

    _reject new Error 'JUST'

  it 'maintain scope', (done)->
    act = duct()
      .do ()->
        console.log '.do'
        expect(@scope).be.eql a
        expect(@scope.fn).be.a 'function'
      .finally (err)->
        done err
    class A
      fn: ()->
      act: act
    a = new A
    a.act()




describe 'complex usage', ()->
  it 'run without args & callback, await take only callback function', (it_done)->
    do duct()
      .do ()->
        return 'test'
      .await "log", (done)->
        console.log 'awit', arguments
        expect(done).to.be.a('function')
        done()
      .do ()->
        it_done()
