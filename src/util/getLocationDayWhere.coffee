_ = require 'lodash'
Promise = require 'when'

module.exports = (System) ->
  LocationDay = System.getModel 'LocationDay'

  (where) ->
    mpromise = LocationDay
    .where where
    .sort
      date: -1
    .populate 'city'
    .limit 1
    Promise mpromise
    .then (items) ->
      console.log 'items', where, items
      items?[0]
