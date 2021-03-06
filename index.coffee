q = require 'kew'

SKIP = 0
END = 1

empty = ->
  next: (done) ->
    done(END) if done

valueAsSeq = (v) ->
  seen = false
  next: (done) ->
    unless seen
      seen = true
      done null, v if done
    else
      done END

arrayAsSeq = (a) ->
  a = a.slice(0)
  next: (done) ->
    if a.length > 0
      value = a.shift()
      done(null, value) if done
    else
      done(END)

promiseAsSeq = (p) ->
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
  if not v?
    empty()
  else if v?.next?
    v
  else if Array.isArray(v)
    arrayAsSeq(v)
  else if v?.then?
    promiseAsSeq(v)
  else
    valueAsSeq(v)

makeModule = (asSeq, yieldEvery = 100) ->

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

    # m a, (a -> b) -> m b
    map: (seq, f) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          if s? then done(s) else done(null, f v)

    # m a, (a, b -> b), b -> m b
    scan: (seq, f, acc) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          if s?
            done s
          else
            acc = f(v, acc)
            done null, acc

    # m a, (a, b -> b), b -> m b
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

    # m a, int -> m a
    take: (seq, n = 10) ->
      seq = asSeq seq
      next: (done) ->
        if n > 0
          seq.next (s, v) ->
            return done(s) if s?
            n -= 1
            done(null, v)
        else
          done(END)

    # m a, int -> m a
    drop: (seq, n = 10) ->
      seq = asSeq seq
      next: (done) ->
        if n > 0
          seq.next (s, v) ->
            return done(s) if s?
            n -= 1
            done(SKIP)
        else
          seq.next(done)

    # m a, (a -> bool) -> m a
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

    # m a, (a -> bool) -> m a
    takeWhile: (seq, f) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          return done(s) if s?
          if f(v)
            done(null, v)
          else
            done(END)

    # m a, (a -> bool) -> m a
    filter: (seq, f) ->
      seq = asSeq seq
      next: (done) ->
        seq.next (s, v) ->
          return done(s) if s?
          if f(v)
            done(null, v)
          else
            done(SKIP)

    # m m a -> m a
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

    # m a, (a -> m b) -> m b
    mapCat: (seq, f) =>
      mod.join(mod.map(seq, f))

    # (a -> m b), m a -> m b
    series: (f, seed) ->
      next: (done) ->
        asSeq(seed).next (s, v) =>
          return done(s) if s?
          seed = f v
          done(null, v)

    # m a, int -> m m a
    window: (seq, n) ->
      seq = asSeq seq
      buffer = []
      next: (done) ->
        seq.next (s, v) ->
          if s == END and buffer.length > 0
            value = buffer.slice(0)
            buffer.shift()
            done(null, value)
            return

          return done(s) if s?

          if buffer.length < n
            buffer.push(v)
            done(SKIP)
          else
            value = buffer.slice(0)
            buffer.shift()
            buffer.push(v)
            done(null, value)

    # m a, m b, ... -> m (a, b, ...)
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
          if n > yieldEvery
            n = 0
            setImmediate ->
              mod.reduced seq, f, nv, p, n + 1
          else
            mod.reduced seq, f, nv, p, n + 1
      seq.next onValue
      p

    produced: (seq) ->
      mod.reduced(seq, ((v, s) -> s.concat [v]), [])

module.exports = makeModule(asSeq)
module.exports.makeModule = makeModule

module.exports.valueAsSeq = valueAsSeq
module.exports.promiseAsSeq = promiseAsSeq
module.exports.arrayAsSeq = arrayAsSeq
module.exports.promiseNextValue = promiseNextValue
