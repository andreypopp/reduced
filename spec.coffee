{deepEqual, equal, ok} = require 'assert'
{asSeq, map, scan, fold,
  take, drop, takeWhile, dropWhile,
  filter, join, mapCat,
  reduced, produced} = require './index'
{resolve, all} = require 'kew'

describe 'creating seqs with asSeq', ->

  sum = (seq) ->
    reduced seq, ((v, a) -> a + v), 0

  it 'creates a seq from an array', (done) ->
    (sum asSeq [1..10])
      .then (x) ->
        equal x, 55
      .fin(done)
      .end()

  it 'creates a seq from a value', (done) ->
    (sum asSeq 10)
      .then (x) ->
        equal x, 10
      .fin(done)
      .end()

  it 'creates an empty seq from undethened', (done) ->
    (sum asSeq())
      .then (x) ->
        equal x, 0
      .fin(done)
      .end()

  it 'creates an empty seq from null', (done) ->
    (sum asSeq())
      .then (x) ->
        equal x, 0
      .fin(done)
      .end()

  it 'creates a seq from a promise', (done) ->
    (sum asSeq(resolve 10))
      .then (x) ->
        equal x, 10
      .fin(done)
      .end()

describe 'combinators', ->

  it 'provides map', (done) ->
    seq = map [1..10], (v) -> v + 1
    produced(seq)
      .then (v) ->
        deepEqual v, [2..11]
      .fin(done)
      .end()

  it 'provides scan', (done) ->
    seq = scan [1..5], ((v, a) -> v + a), 0
    produced(seq)
      .then (v) ->
        deepEqual v, [1, 3, 6, 10, 15]
      .fin(done)
      .end()

  it 'provides fold', (done) ->
    seq = fold [1..5], ((v, a) -> v + a), 0
    reduced(seq)
      .then (v) ->
        equal v, 15
      .fin(done)
      .end()

  it 'provides take', (done) ->
    seq = take [1..10], 5
    produced(seq)
      .then (v) ->
        deepEqual v, [1..5]
      .fin(done)
      .end()

  it 'provides drop', (done) ->
    seq = drop [1..10], 5
    produced(seq)
      .then (v) ->
        deepEqual v, [6..10]
      .fin(done)
      .end()

  it 'provides takeWhile', (done) ->
    seq = takeWhile [1..10], (v) -> v < 6
    produced(seq)
      .then (v) ->
        deepEqual v, [1..5]
      .fin(done)
      .end()

  it 'provides dropWhile', (done) ->
    seq = dropWhile [1..10], (v) -> v < 6
    produced(seq)
      .then (v) ->
        deepEqual v, [6..10]
      .fin(done)
      .end()

  it 'provides filter', (done) ->
    seq = filter [1..10], (v) -> v % 2 == 0
    produced(seq)
      .then (v) ->
        deepEqual v, [2, 4, 6, 8, 10]
      .fin(done)
      .end()

  it 'provides join', (done) ->
    c1 = produced(join [1..10])
      .then (v) ->
        deepEqual v, [1..10]

    c2 = produced(join [1..10].map((v) -> [v]))
      .then (v) ->
        deepEqual v, [1..10]

    c3 = produced(join [1, [2], 3])
      .then (v) ->
        deepEqual v, [1, 2, 3]

    all([c1, c2, c3]).fin(done).end()

  it 'provides mapCat', (done) ->
    seq = mapCat [1..10], (x) -> [x]
    c1 = produced(seq)
      .then (v) ->
        deepEqual v, [1..10]

    seq = mapCat [1..10], (x) -> if x % 2 == 0 then [x] else x
    c2 = produced(seq)
      .then (v) ->
        deepEqual v, [1..10]

    all([c1, c2]).fin(done).end()
