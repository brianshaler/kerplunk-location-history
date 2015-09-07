_ = require 'lodash'

module.exports = (items) ->
  return 0 unless items?.length > 0

  averageTime = 1 / items.length * _ items
    .map (item) -> item.postedAt.getTime()
    .reduce (memo, time) ->
      memo + time
    , 0

  sorted = _.sortBy items, (item) ->
    Math.abs item.postedAt.getTime() - averageTime

  Math.round sorted[0].location[0] / 180 * 12
