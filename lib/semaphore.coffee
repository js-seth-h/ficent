
class Semaphore
  constructor: (max)->
    @available = max
    @queue = []
  enter: (fn)->
    @queue.push fn
    @runAvailable()
  leave: ()->
    @available++
    @runAvailable()
  runAvailable: ()->
    return if @queue.length is 0
    return if @available is 0
    @available--
    fn = @queue.shift()
    fn()
  destroy: ()->
    @available = 0
    @queue = []

module.exports = exports = Semaphore