{deepEqual, equal, ok} = require 'assert'
{asSeq, lazy,
  repeat, map, scan, fold, series,
  take, drop, takeWhile, dropWhile,
  filter, join, mapCat, zip,
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

  describe 'map', ->

    it 'map a function over seq', (done) ->
      seq = map [1..10], (v) -> v + 1
      produced(seq)
        .then (v) ->
          deepEqual v, [2..11]
        .fin(done)
        .end()

    it 'does not flatten', (done) ->
      seq = map [1..10], (v) -> [v + 1]
      produced(seq)
        .then (v) ->
          deepEqual v, [2..11].map (v) -> [v]
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

  describe 'take', ->

    it 'takes some number of elements from the start', (done) ->
      seq = take [1..10], 5
      produced(seq)
        .then (v) ->
          deepEqual v, [1..5]
        .fin(done)
        .end()

    it 'can take no elements', (done) ->
      seq = take [1..10], 0
      produced(seq)
        .then (v) ->
          deepEqual v, []
        .fin(done)
        .end()

  describe 'drop', ->

    it 'drop some number of elements from the start', (done) ->
      seq = drop [1..10], 5
      produced(seq)
        .then (v) ->
          deepEqual v, [6..10]
        .fin(done)
        .end()

    it 'can drop no elements', (done) ->
      seq = drop [1..10], 0
      produced(seq)
        .then (v) ->
          deepEqual v, [1..10]
        .fin(done)
        .end()

  it 'provides takeWhile', (done) ->
    seq = takeWhile [1..10].concat([1, 2]), (v) -> v < 6
    produced(seq)
      .then (v) ->
        deepEqual v, [1..5]
      .fin(done)
      .end()

  it 'provides dropWhile', (done) ->
    seq = dropWhile [1..10].concat([1, 2]), (v) -> v < 6
    produced(seq)
      .then (v) ->
        deepEqual v, [6..10].concat([1, 2])
      .fin(done)
      .end()

  it 'provides filter', (done) ->
    seq = filter [1..10], (v) -> v % 2 == 0
    produced(seq)
      .then (v) ->
        deepEqual v, [2, 4, 6, 8, 10]
      .fin(done)
      .end()
      
  describe 'zip', ->

    it 'zips several seqs into one', (done) ->
      seq = zip([1..10], [1..10], [101..200])
      produced(seq)
        .then (v) ->
          deepEqual v, [[1, 1, 101],
                        [2, 2, 102],
                        [3, 3, 103],
                        [4, 4, 104],
                        [5, 5, 105],
                        [6, 6, 106],
                        [7, 7, 107],
                        [8, 8, 108],
                        [9, 9, 109],
                        [10, 10, 110]]
        .fin(done)
        .end()

    it 'can zip nothing', (done) ->
      seq = zip()
      produced(seq)
        .then (v) ->
          deepEqual v, []
        .fin(done)
        .end()

  describe 'join', ->

    it 'joins', (done) ->
      produced(join [1..10])
        .then (v) ->
          deepEqual v, [1..10]
        .fin(done)
        .end()

    it 'flattens', (done) ->
      produced(join [1..10].map((v) -> [v]))
        .then (v) ->
          deepEqual v, [1..10]
        .fin(done)
        .end()

    it 'works with mixed returned values', (done) ->
      produced(join [1, [2], 3])
        .then (v) ->
          deepEqual v, [1, 2, 3]
        .fin(done)
        .end()

  describe 'mapCat', ->

    it 'maps and flattens', (done) ->
      seq = mapCat [1..10], (x) -> [x]
      produced(seq)
        .then (v) ->
          deepEqual v, [1..10]
        .fin(done)
        .end()

    it 'works with mixed returned values', (done) ->
      seq = mapCat [1..10], (x) -> if x % 2 == 0 then [x] else x
      produced(seq)
        .then (v) ->
          deepEqual v, [1..10]
        .fin(done)
        .end()

  it 'provides repeat', (done) ->
    seq = repeat 10
    produced(take seq, 5)
      .then (v) ->
        deepEqual v, [10, 10, 10, 10, 10]
      .fin(done)
      .end()

  describe 'series', ->

    it 'generates new value from the previous one', (done) ->
      seq = series ((v) -> v + 1), 0
      produced(take seq, 10)
        .then (v) ->
          deepEqual v, [0..9]
        .fin(done)
        .end()

    it 'flattens', (done) ->
      # TODO: that's arguable
      seq = series ((v) -> [v + 1]), 0
      produced(take seq, 10)
        .then (v) ->
          deepEqual v, [0..9]
        .fin(done)
        .end()

describe 'lazy', ->

  it 'can defer collection creation', (done) ->
    seq = lazy -> [1..10]
    produced(seq)
      .then (v) ->
        deepEqual v, [1..10]
      .fin(done)
      .end()
