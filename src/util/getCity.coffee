_ = require 'lodash'
Promise = require 'when'

getDistance = require './getDistance'

module.exports = (System) ->
  Place = System.getModel 'Place'

  (lng, lat) ->
    if lng instanceof Array and lng.length == 2
      [lng, lat] = lng

    return unless typeof lng is 'number' and typeof lat is 'number'

    where =
      location:
        $near:
          $geometry:
            type: 'Point'
            coordinates: [lng, lat]
          $maxDistance: 200000
      'data.cityId':
        $exists: true

    mpromise = Place
    .where where
    .limit 20
    .exec()
    .then (cities) ->
      return unless cities?.length > 0
      cities = _.map cities, (city) ->
        city = city.toObject()
        city.dist = getDistance city.location, [lng, lat]
        city.input = [lng, lat]
        city.sortVal = -Math.sqrt(Math.sqrt(city.data.population)) / (city.dist+20)
        city
      cities = _.sortBy cities, (city) -> city.sortVal
      cities[0]

    Promise mpromise
