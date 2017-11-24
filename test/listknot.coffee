knot = require '../lib/knot'
duct = require '../lib/duct'

ListKnot = knot.List 
chai = require 'chai'
expect = chai.expect
debug = require('debug')('test')
_ = require 'lodash'
feature = describe
scenario = it

describe 'ListKnot Triggers;', ()->

  it 'consecution', (done)->
      box = new ListKnot()
        .consecution()
      box.handler.feedback (feedback, cur)->
        debug 'feedback.set'
        feedback.set 0, cur * cur

      box.push 9
      debug 'check expect'
      expect(box.getStatus()).to.have.lengthOf 0
      done()

  it 'asap', (done)->
      box = new ListKnot()
        .asap()
      box.handler.feedback (feedback, cur)->
        feedback.set 0, cur * cur

      box.push 9
      expect(box.getStatus()).to.have.lengthOf 1
      _dfn = ()->
        expect(box.getStatus()).to.have.lengthOf 0
        done()
      setTimeout _dfn, 10

  it 'debounce', (done)->
      box = new ListKnot()
        .debounce 20
      box.handler.feedback (feedback, cur)->
        feedback.set 0, cur * cur

      box.push 9
      expect(box.getStatus()).to.have.lengthOf 1

      setTimeout (()->
        box.push 20
        expect(box.getStatus()).to.have.lengthOf 2
      ), 10

      _dfn = ()->
        expect(box.getStatus()).to.have.lengthOf 0
        done()
      setTimeout _dfn, 25

  it 'interval', (done)->
      box = new ListKnot()
        .interval 20
      box.handler.feedback (feedback, cur)->
        feedback.set 0, cur * cur

      box.push 9
      expect(box.getStatus()).to.have.lengthOf 1

      setTimeout (()->
        expect(box.getStatus()).to.have.lengthOf 0
        box.push 20
        expect(box.getStatus()).to.have.lengthOf 1
      ), 25

      _dfn = ()->
        expect(box.getStatus()).to.have.lengthOf 0
        done()
      setTimeout _dfn, 45



describe 'ListKnot.parallel', ()->
  it 'when start and callbacked, then fullfill', (done)->

    result = []
    box = new ListKnot()
      .pushAll [0...10]
      .parallel()

    box.handler
      .map (cur)-> cur * cur
      .feedback (feedback, cur)-> 
        result.push cur

    box.pullOut (err, ListKnot)->
      resut = result.sort (a,b)->  a - b 
      expect(resut ).be.eql [0...10].map (x)-> x * x
      done() 

describe 'ListKnot.serial', ()->
  it 'when start and callbacked, then result serialed', (done)->
    
    result = []
    box = new ListKnot()
      .pushAll [0...10]
      .serial()

    last = -1
    box.handler
      .do (cur)->
        expect(last + 1).be.eql cur
        last = cur
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        result.push cur

    box.pullOut (err, ListKnot)->
      expect(result).be.eql [0...10].map (x)-> x * x
      done()



describe 'ListKnot.nParallel', ()->
  it 'when start and callbacked, then feedbacks fullfill ', (done)->

    result = []
    box = new ListKnot()
      .pushAll [0...10]
      .parallel()
      
    box.handler
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        result.push cur
        # feedback.set 0, cur
    
    box.pullOut (err, ListKnot)->
      resut = result.sort (a,b)->  a - b 
      expect(resut ).be.eql [0...10].map (x)-> x * x
      done()

  it 'when start and callbacked, then feedbacks fullfill & concurrent limited ', (done)->

    result = []
    box = new ListKnot()
      .pushAll [0...10]
      .nParallel 2

    box.handler
      .map (cur)-> cur * cur
      .async 'test', (cur, a_done)->
        _dfn = ()->
          a_done null
        setTimeout _dfn, 5
      .feedback (feedback, cur)->
        # feedback.set 0, cur
        result.push cur

    t_start = (new Date).getTime()
    time_accuracy = 5
    box.pullOut (err, ListKnot)->
      t_end = (new Date).getTime()
      t_gap = t_end - t_start
      expect(t_gap).be.least 5 * 10 / 2 - time_accuracy 
      resut = result.sort (a,b)->  a - b 
      expect(resut ).be.eql [0...10].map (x)-> x * x
      done()

describe 'ListKnot.reduce', ()->
  it 'reduce', (done)->
    result = 0
    box = new ListKnot()
      .pushAll [0...10]
      .reduce (list)->
        return _.sum list
      .parallel()

    box.handler
      .feedback (feedback, cur)->
        # feedback.set 0, cur
        result = cur

    box.pullOut (err, ListKnot)->
      expect(result).be.eql _.sum [0...10]
      done()



describe 'ListKnot setHandler', ()->
  it 'setHandler', (done)->

    result = []
    _han = duct()
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        # feedback.set 0, cur
        result.push cur

    box = new ListKnot()
      .pushAll [0...10]
      .parallel()
      .setHandler _han
      .pullOut (err, ListKnot)->
        resut = result.sort (a,b)->  a - b 
        expect(resut ).be.eql [0...10].map (x)-> x * x
        done()

  it 'setDataHandler', (done)->

    result = []
    _han = duct()
      .map (cur)-> cur * cur
      .feedback (feedback, cur)->
        # feedback.set 0, cur
        result.push cur

    box = new ListKnot()
      .pushAll [0...10]
      .parallel()
      .setDataHandler _han
      .pullOut (err, ListKnot)->
        resut = result.sort (a,b)->  a - b 
        expect(resut ).be.eql [0...10].map (x)-> x * x
        done()
