q = require 'kew'

SKIP = 0
END = 1

empty = ->
  depth: 1
  next: (done) ->
    done(END) if done

box = (v) ->
  seen = false
  depth: 1
  next: (done) ->
    unless seen
      seen = true
      done null, v if done
    else
      done END

array = (a) ->
  a = a.slice(0)
  depth: 1
  next: (done) ->
    if a.length > 0
      value = a.shift()
      done(null, value) if done
    else
      done(END)

promise = (p) ->
  seen = false
  depth: 1
  next: (done) ->
    unless seen
      seen = true
      p
        .then (v) ->
          done(null, v) if done
        .end()
    else
      done END

asSeq = (v) ->
  if v?.next?
    v
  else if Array.isArray(v)
    array(v)
  else if v?.then?
    promise(v)
  else if not v?
    empty()
  else
    box(v)

repeat = (v) ->
  depth: 0
  next: (done) ->
    done(null, v)

map = (seq, f) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    seq.next (s, v) ->
      if s? then done(s) else done(null, f v)

scan = (seq, f, acc) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    seq.next (s, v) ->
      if s?
        done s
      else
        acc = f(v, acc)
        done null, acc

fold = (seq, f, acc) ->
  seq = asSeq seq
  computed = false
  depth: seq.depth + 1
  next: (done) ->
    seq.next (s, v) ->
      if computed
        done(END)
      else if s == END
        computed = true
        done(null, acc)
      else if s?
        done(s)
      else
        acc = f(v, acc)
        done SKIP

take = (seq, n = 10) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    if n > 0
      n -= 1
      seq.next(done)
    else
      done(END)

drop = (seq, n = 10) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    if n > 0
      n -= 1
      seq.next()
      done(SKIP)
    else
      seq.next(done)

dropWhile = (seq, f) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    seq.next (s, v) ->
      return done(s) if s?
      if f(v)
        done(SKIP)
      else
        done(null, v)

takeWhile = (seq, f) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    seq.next (s, v) ->
      return done(s) if s?
      if f(v)
        done(null, v)
      else
        done(END)

filter = (seq, f) ->
  seq = asSeq seq
  depth: seq.depth + 1
  next: (done) ->
    seq.next (s, v) ->
      if s? then done(s) else if f(v) then done(null, v) else done(SKIP)

join = (seqs) ->
  seqs = asSeq seqs
  current = undefined

  nextCurrent = (done) ->
    current.next (s, v) ->
      if s == END
        current = undefined
        nextSeq(done)
      else
        done(s, v)

  nextSeq = (done) ->
    seqs.next (s, seq) ->
      if s == END
        done(END)
      else
        current = asSeq seq
        nextCurrent(done)

  depth: seqs.depth
  next: (done) ->
    unless current then nextSeq(done) else nextCurrent(done)

mapCat = (seq, f) ->
  join(map(seq, f))

reduced = (seq, f, s, p = null, n = 0) ->
  seq = asSeq seq
  p = p or q.defer()
  yieldAfter = 3000 / seq.depth
  onValue = (ns, v) ->
    if ns == END
      p.resolve(s)
    else
      nv = if ns == SKIP then s else if f then f(v, s) else v

      if n >= yieldAfter
        setImmediate ->
          n = 0
          reduced seq, f, nv, p, n + 1
      else
        reduced seq, f, nv, p, n + 1
  seq.next onValue
  p

produced = (seq) ->
  reduced(seq, ((v, s) -> s.concat [v]), [])

module.exports = {
  asSeq, empty, box, promise, array, repeat,
  map, scan, fold,
  take, drop, takeWhile, dropWhile, filter, join, mapCat,
  reduced, produced}
