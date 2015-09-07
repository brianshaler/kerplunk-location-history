Promise = require 'when'

module.exports = (System) ->
  LocationDay = System.getModel 'LocationDay'

  (where) ->
    mpromise = LocationDay
    .where where
    .populate 'city'
    .findOne()
    Promise mpromise
