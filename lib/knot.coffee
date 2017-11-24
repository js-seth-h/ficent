
_ = require 'lodash'
duct = require './duct'
Semaphore = require './semaphore'

debug = require('debug')('knot')

### 
Knot는 프로그램 처리 흐름상의 결절이다.
시작점이자 끝점으로 볼수있으며,
상태를 확인할수 있다.
내부 자료 타입에 따라서 3~4가지를 둔다.

  RefKnot - 무엇인가를 참조함 
  ListKnot - 내부가 Array, .push가 가능
  DictionaryKnot - 내부가 Dictionary(=Object), .set 가능
  NumberKnot - 내부가 Number, .inc(.increase) 가능
  
Knot 공통. = RefKnot
  결절 내부 공간에 대한 Get/Set
  .getStatus
  .setStatus

  특정 상황이 될때까지 대기 가능
  .wait = .waitOnce
    until: (knot)-> return false
    then : (knot)-> 

  wait는 한번만 처리하고 when은 반복 수행
  .when 
    if: (knot)-> return false
    then : (knot)-> 

  .manual : pullout을 그대로 호출함.


  reactivity 계열 - pullout호출을 자동화 시킴
    * consecution: 들어오는 즉시 나감. 처리함수의 연속.
    * asap : 가능한 빨리 큐에서 꺼냄. 비동기
    * debounce: 지연된 시간내의 것을 모아서.
    * throttle: 우선 들어온것 처리하고, given time 동안 처리를 지연하여 처리
    * interval: 지정된 간격으로 나감
    * backPressure:
        pullOut이 처리되면 연속 호출
        처리할 데이터가 없으면? setTimeout
        최초의 시작은? 자동으로 함.
  
  Puller 계열
    * 100% 커스텀.
    
  Outer 계열
    * serial 순차 처리
    * parallel 전체 동시 병렬 처리
    * nParallel 갯수 제한 동시 처리

  Handler
    * 100% 커스텀.

   
ListKnot() 
  .push 
  
  Puller 계열
    * all : 들어온 것을 그대로 내보냄
    * dequeue: 1개만 꺼냄
    * latest: 다 버리고 가장 마지막 것
    * reduce(init_acc, acc_fn): 리듀싱 함수 호출

DictionaryKnot 
  .set(path, value) 
  .get(path)
  Puller 계열
    * pairs : 모든 키,값의 쌍 [k,v]
    * pairObject: 모든 {key: 키값, value: 값} 구조
    * keys: 모든 Key만
    * values: 모든 value만
    * reduce(init_acc, acc_fn)  
  
  
    
NumKnot 
  .inc 
  
  Puller
    * current : 현재 값 읽기
    
 
대량 처리시의 문제.
이때는 puts로 전부 넣기가 무리고,
스트림처리식도 부족함. 동기화가 안되서, 막 밀어넣고 전부 버퍼링 되게됨.
BackPressure 개념뿐인데..
문제는 끝나는 시점이 정확하지 않다.
  끝 = .next() is null  + all pullout execute done

>> 해법
knot = RefKnot()
  .setStatus MongoCursor
  .backPressure()
  # .noPuller() 
  # .serial() / .parallel()
  
knot.puller.do (self)-> [ self.getStatus().next()  ]
knot.handler.do (data)-> ....
  .await (data, done)-> ...
  


###

_ASAP = (fn)-> setTimeout fn, 0
if process?.nextTick?
  _ASAP = process.nextTick


_proto = (klass, dict)->
  for own key, v of dict
    klass.prototype[key] = v

class RefKnot
  constructor:()->
    @status = null
    @reset()
    @serial()
  getStatus: ()-> @status
  setStatus: (@status)-> 
    
  reset: ()->
    @trigger = duct() 
    @puller = duct() # 데이터 추출 루틴
    @outer = duct() # 방출 제어 루틴.
    @handler = duct() # 개별 방출 핸들러
    return this
    
  pullOut: (callback)->
    self = this
    _fn = duct()
      .await "data", (done)->
        debug 'call puller'
        self.puller self, done
      .load "data"
      .await (data, done)->
        debug 'call outter'
        self.outer data, done
      .do (data)->
        self.trigger 'after-pullout', data
    _fn (err)->
      if callback
        callback err, self 
    return this

  setHandler: (@handler)->
    return this
  setDataHandler: (@handler)->
    return this
  doHandling: (data, callback)->
    @handler data, callback
    return this
  

  # auto reactivity 계열 
  consecution : ()->
    self = this
    self.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-change'
        debug 'consecution call pullOut'
        self.pullOut()
    return self

  asap: ()->
    self = this
    self.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-change'
        _ASAP ()-> self.pullOut()
    return self

  backPressure: (msec)->
    self = this
    self.trigger.clear()
      .do (timing_name, data)->
        return if timing_name isnt 'after-pullout'
        _pullout = ()-> self.pullOut()
        if data.length > 0
          _ASAP _pullout
        else
          setTimeout _pullout, msec

  interval : (msec)->
    self = this
    self.trigger.clear()
    _tick = ()->
      self.pullOut()
    setInterval _tick, msec
    return self

  throttle: (msec)->
    self = this
    self.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-change'
        return if self.tid
        _dfn = ()->
          self.tid = null
          self.pullOut()
        self.tid = setTimeout _dfn, msec
        self.pullOut()
    return self

  debounce : (msec)->
    self = this
    self.trigger.clear()
      .do (timing_name)->
        return if timing_name isnt 'after-change'
        return if self.tid
        _dfn = ()->
          self.tid = null
          self.pullOut()
        self.tid = setTimeout _dfn, msec
    return self
      
  #outter 계열   
  par : ()-> @parallel()
  parallel : ()->
    self = this
    self.outer.clear().await (data, done)->
      _fn = duct() 
      _.forEach data, (datum, inx)->
        _fn.async inx, (done)->
          self.doHandling datum, done
      _fn.wait()
      _fn done
    return self

  ser : ()-> @serial()
  serial : ()->
    self = this
    self.outer.clear().await (data, done)->
      _fn = duct() 
      _.forEach data, (datum, inx)->
        _fn.await inx, (done)->
          self.doHandling datum, done
      _fn done
    return self
 
  nPar : (concurrent)-> @nParallel concurrent
  nParallel : (concurrent)->
    self = this
    s = new Semaphore concurrent
    self.outer.clear().await (data, done)->
      _fn = duct() 
      _.forEach data, (datum, inx)->
        _fn.async inx, (done)->
          s.enter ()->
            self.doHandling datum, (err)->
              s.leave()
              done err
      _fn.wait()
      _fn done
    return self

class ListKnot extends RefKnot 
  constructor: ()->
    super()
    @setStatus []
    @all()
    
  push: (args...)->
    @getStatus().push args...  
    @trigger("after-change")
    return this
  pushAll: (list)->
    @getStatus().push list...  
    @trigger("after-change")
    return this
  all: ()->
    self = this
    self.puller.clear().do (knot)->
      list = knot.getStatus()
      knot.setStatus []
      @feedback.reset list
    return self
  latest: ()->
    self = this
    self.puller.clear().do (knot)->
      list = knot.getStatus()
      knot.setStatus []
      @feedback.reset [ _.last list ]
    return self
  reduce: (reduce_fn)->
    self = this
    self.puller.clear().do (knot)->
      list = knot.getStatus()
      knot.setStatus []
      val = reduce_fn list
      @feedback.reset [val]
    return self
    
class DictionaryKnot extends RefKnot 
  constructor: ()->
    super()
    @setStatus {} 
  set: (key, value)->
    _.set(@getStatus(), key, value)    
    @trigger("after-change")
  get: (key, value)->
    _.get(@getStatus(), key)
    @trigger("after-change")
    
class NumKnot extends RefKnot 
  constructor: ()->
    super()
    @setStatus 0 
  inc: (diff)->
    @setStatus @getStatus() + diff 
  current: ()->
    self = this
    self.puller.clear().do (self)->
      val = self.getStatus()
      @feedback.reset [val]
    return self
    
    
  
module.exports = exports = 
  Ref : RefKnot
  List : ListKnot
  Num : NumKnot
  Dictionary : DictionaryKnot
