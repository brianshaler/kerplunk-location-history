GetCity = require './getCity'
GetLastLocation = require './getLastLocation'

module.exports = (System) ->
  getLastLocation = GetLastLocation System
  getCity = GetCity System

  (data = {}) ->
    getLastLocation()
    .then (item) ->
      return unless item
      data.location = item.location
      data.text = item.message
      data.item = item
      data.timestamp = item.postedAt
      item.location
    .then getCity
    .then (city) ->
      if city?.name
        data.city = city.name
      data
