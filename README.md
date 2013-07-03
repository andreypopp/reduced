# reduced

Some notes:

  * pull-style lazy sequences
  * a set of combinators for them
  * modelled after clojure/reducers
  * plays well with arrays, promises and other monads (theoretically)
  * see specs for docs

Brief example:

    {equal} = require 'assert'
    {fold, take, repeat, reduced} = require 'reduced'

    # compute a sum of a seq
    sum = (seq) ->
      fold(seq, ((v, s) -> v + s), 0)

    # sum of a hundred of 1s
    sum100 = sum(take repeat(1), 100)

    reduced(sum100).then (v) ->
      equal v, 100

## reduced is a parametrized module (functor)

You can use reduced with other types of monads — there's `makeModule` function
which created another instance of `reduced` module.

    var reducedForStreams = reduced.makeModule(function(stream) {
      // make seq from a stream
    });

That way `reducedForStreams` would have exactly the same function available as
original `reduce` module but those functions will work only on streams.
