Promise = require 'when'

module.exports = (System) ->
  ActivityItem = System.getModel 'ActivityItem'
  ->
    me = System.getMe()
    where =
      identity: me._id
      $or: [
        {'location.0': {$gt: 0}}
        {'location.0': {$lt: 0}}
      ]

    mpromise = ActivityItem
    .where where
    .sort postedAt: -1
    .findOne()
    Promise mpromise
