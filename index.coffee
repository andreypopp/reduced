q = require 'kew'

SKIP = 0
END = 1

empty = ->
  next: (done) ->
    done(END) if done

box = (v) ->
  seen = false
  next: (done) ->
    unless seen
      seen = true
      done null, v if done
    else
      done END

array = (a) ->
  a = a.slice(0)
  next: (done) ->
    if a.length > 0
      value = a.shift()
      done(null, value) if done
    else
      done(END)

promise = (p) ->
  seen = false
  next: (done) ->
    unless seen
      seen = true
      p
        .then (v) ->
          done(null, v) if done
        .end()
    else
      done END

promiseNextValue = (seq) ->
  p = q.defer()
  resolve = p.resolve.bind(p)
  seq.next (s, v) ->
    if s == SKIP
      promiseNextValue(seq).then(resolve)
    else
      resolve [s, v]
  p

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

makeModule = (asSeq) ->

  mod =

    SKIP: SKIP
    END: END
    asSeq: asSeq
    empty: empty

    repeat: (v) ->
      next: (done) ->
        done(null, v)

    lazy: (seqFactory) ->
      seq = undefined
      next: (done) ->
        seq = asSeq seqFactory() unless seq?
        seq.next(done)

    map: (seq, f) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          if s? then done(s) else done(null, f v)

    scan: (seq, f, acc) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          if s?
            done s
          else
            acc = f(v, acc)
            done null, acc

    fold: (seq, f, acc) ->
      seq = asSeq seq
      computed = false
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

    take: (seq, n = 10) ->
      seq = asSeq seq
      next: (done) ->
        if n > 0
          n -= 1
          seq.next(done)
        else
          done(END)

    drop: (seq, n = 10) ->
      seq = asSeq seq
      next: (done) ->
        if n > 0
          n -= 1
          seq.next()
          done(SKIP)
        else
          seq.next(done)

    dropWhile: (seq, f) ->
      seq = asSeq seq
      seen = false
      next: (done) ->
        seq.next (s, v) ->
          return done(s) if s?
          if f(v) and not seen
            done(SKIP)
          else
            seen = true
            done(null, v)

    takeWhile: (seq, f) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          return done(s) if s?
          if f(v)
            done(null, v)
          else
            done(END)

    filter: (seq, f) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          if s? then done(s) else if f(v) then done(null, v) else done(SKIP)

    join: (seqs) ->
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

      next: (done) ->
        unless current then nextSeq(done) else nextCurrent(done)

    mapCat: (seq, f) =>
      mod.join(mod.map(seq, f))

    series: (f, seed) ->
      next: (done) ->
        asSeq(seed).next (s, v) =>
          seed = f v
          done(null, v)

    zip: (seqs...) ->
      return mod.empty() if seqs.length == 0
      seqs = seqs.map asSeq
      next: (done) =>
        values = for seq in seqs
          promiseNextValue(seq)
        q.all(values).then (values) ->
          for [s, v] in values
            return done(s) if s?
          done null, (v for [s, v] in values)

    reduced: (seq, f, s, p = null, n = 0) ->
      seq = asSeq seq
      p = p or q.defer()
      onValue = (ns, v) ->
        if ns == END
          p.resolve(s)
        else
          nv = if ns == SKIP then s else if f then f(v, s) else v
          setImmediate ->
            n = 0
            mod.reduced seq, f, nv, p, n + 1
      seq.next onValue
      p

    produced: (seq) ->
      mod.reduced(seq, ((v, s) -> s.concat [v]), [])

module.exports = makeModule(asSeq)
module.exports.makeModule = makeModule

module.exports.box = box
module.exports.promise = promise
module.exports.array = array
module.exports.promiseNextValue = promiseNextValue
