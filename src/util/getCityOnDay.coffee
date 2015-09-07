Promise = require 'when'

GetLocationDayWhere = require './getLocationDayWhere'
GetLocationDuringRange = require './getLocationDuringRange'
GetCity = require './getCity'

module.exports = (System) ->
  LocationDay = System.getModel 'LocationDay'

  getLocationDayWhere = GetLocationDayWhere System
  getLocationDuringRange = GetLocationDuringRange System
  getCity = GetCity System

  (year, month, day) ->
    todaysDateKey = LocationDay.makeDateKey year, month, day
    today = new Date Date.UTC year, month, day
    tmrw = new Date today.getTime() + 86400 * 1000
    lastWeek = new Date today.getTime() - 7 * 86400 * 1000
    lastMonth = new Date today.getTime() - 31 * 86400 * 1000

    # start by seeing if the day has been calculated
    getLocationDayWhere
      dateKey: todaysDateKey
    .then (loc) ->
      return loc if loc?.city
      # No? Okay look at posts from that day
      getLocationDuringRange today, tmrw
      .then (item) -> getCity item.location if item?.location
      .then (city) -> city: city
    .then (loc) ->
      return loc if loc?.city
      # No? Okay, find a LocationDay from up to a week before
      getLocationDayWhere
        date:
          $lt: today
          $gt: lastWeek
    .then (loc) ->
      return loc if loc?.city
      # No? Okay, find a posts from up to a week before
      getLocationDuringRange lastWeek, today
      .then (item) -> getCity item.location if item?.location
      .then (city) -> city: city
    .then (loc) ->
      return loc if loc?.city
      # No? Okay, find a LocationDay from up to a month before
      getLocationDayWhere
        date:
          $lt: today
          $gt: lastMonth
    .then (loc) ->
      return loc if loc?.city
      # No? Okay, find a posts from up to a month before
      getLocationDuringRange lastMonth, lastWeek
      .then (item) -> getCity item.location if item?.location
      .then (city) -> city: city
    .then (loc) ->
      return unless loc?.city
      return loc.city if loc?.dateKey == todaysDateKey
      return loc.city unless today < Date.now() - 86400 * 1000 * 7

      obj =
        dateKey: todaysDateKey
        year: year
        month: month
        day: day
        city: loc.city
        date: today
        inferred: true
        userInput: false
      #console.log 'new LocationDay', obj
      #return next null, obj
      locDay = new LocationDay obj
      mpromise = locDay.save()
      Promise mpromise
      .then -> loc.city
