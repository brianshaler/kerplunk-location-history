_ = require 'lodash'
Promise = require 'when'

getTimezoneOffsetFromItems = require './getTimezoneOffsetFromItems'

module.exports = (System) ->
  ActivityItem = System.getModel 'ActivityItem'

  (startDate, endDate) ->
    me = System.getMe()
    where =
      identity: me._id
      $or: [
        {'location.0': {$gt: 0}}
        {'location.0': {$lt: 0}}
      ]
      postedAt:
        $gt: new Date startDate.getTime() - 86400000 / 2
        $lt: new Date endDate.getTime() + 86400000 / 2

    mpromise = ActivityItem
    .where where
    .sort postedAt: -1
    .find()

    Promise mpromise
    .then (items) ->
      offset = getTimezoneOffsetFromItems items
      minTime = startDate.getTime() - offset * 60 * 60 * 1000
      maxTime = endDate.getTime() - offset * 60 * 60 * 1000
      items = _.filter items, (item) ->
        t = item.postedAt.getTime()
        minTime <= t < maxTime
      items?[0]
