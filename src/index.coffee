fs = require 'fs'

_ = require 'lodash'
Promise = require 'when'
es = require 'event-stream'
moment = require 'moment'

LocationDaySchema = require './models/LocationDay'

getTimezoneOffsetFromItems = require './util/getTimezoneOffsetFromItems'

GetLastLocation = require './util/getLastLocation'
GetCurrentCity = require './util/getCurrentCity'
GetCityOnDay = require './util/getCityOnDay'

module.exports = (System) ->
  LocationDay = System.registerModel 'LocationDay', LocationDaySchema

  ActivityItem = System.getModel 'ActivityItem'
  Place = System.getModel 'Place'

  saveLevelCityToMongo = System.getMethod 'kerplunk-place', 'saveLevelCityToMongo'

  getBlogSettings = System.getMethod 'kerplunk-blog', 'getBlogSettings'

  getLastLocation = GetLastLocation System
  getCityOnDay = GetCityOnDay System
  getCurrentCity = GetCurrentCity System

  getTown = (lng, lat, next) ->
    where =
      location:
        $near:
          $geometry:
            type: 'Point'
            coordinates: [lng, lat]
          $maxDistance: 200000
      'data.cityId':
        $exists: true
    Place
    .where where
    .findOne (err, city) ->
      if err
        console.log 'error?', err.stack
      console.error err if err
      return next() if err
      return next null, city

  get = (req, res, next) ->
    locations = []
    fromDate = req.query.from
    d = new Date()
    toDate = req.query.to ? "#{d.getFullYear()}-#{d.getMonth()+1}-#{d.getDate()}"
    #locations.push toDate

    [fromYear, fromMonth, fromDate] = fromDate.split '-'
    [toYear, toMonth, toDate] = toDate.split '-'

    currentDate = new Date Date.UTC parseInt(fromYear), parseInt(fromMonth)-1, parseInt(fromDate)
    endDate = new Date Date.UTC parseInt(toYear), parseInt(toMonth)-1, parseInt(toDate)
    currentCity = null

    #locations.push new Date Date.UTC(parseInt(fromYear), parseInt(fromMonth)-1, parseInt(fromDate))
    #locations.push new Date Date.UTC(toYear, toMonth, toDate)

    formatCityName = (city) ->
      return null unless city?
      region = if city?.region?.length > 0
        "#{city.region}, "
      else
        ""
      "#{city.name}, #{region}#{city.country}"

    cityToOutput = (city) ->
      obj =
        city: city.name
        region: city.region
        country: city.country
        lng: city.location[0]
        lat: city.location[1]
        cityId: city.cityId

    done = ->
      return res.send [] unless locations.length > 1
      changes = []
      for i in [1..locations.length-1]
        fromCity = locations[i-1]
        toCity = locations[i]
        data =
          from: formatCityName fromCity.city
          from_location: cityToOutput fromCity.city
          to: formatCityName toCity.city
          to_location: cityToOutput toCity.city
          on: moment(locations[i].on).format('YYYY-MM-DD')
        changes.push data
      res.send changes

    checkNextDate = (prefetched) ->
      return done() unless currentDate?.getTime?() > 0
      currentTime = currentDate.getTime()

      return done() if currentTime > Date.now()
      return done() if currentTime > endDate.getTime()

      nextDate = new Date(currentTime + 86400*1000 * 1.5) #compensate for timezone madness, maybe.
      nextDate = new Date Date.UTC(nextDate.getFullYear(), nextDate.getMonth(), nextDate.getDate())

      year = currentDate.getFullYear()
      month = currentDate.getMonth()
      day = currentDate.getDate()

      if prefetched?[year]?[month]?[day]?
        city = prefetched[year][month][day]
        cityName = formatCityName city
        if !currentCity? or cityName != formatCityName currentCity
          locations.push
            city: city
            on: currentDate
          currentCity = city
        currentDate = nextDate
        checkNextDate prefetched
        return

      # use external getCityOnDay
      getCityOnDay year, month, day
      .then (city) ->
        if city
          cityName = formatCityName city
          #locations.push currentCity unless locations.length > 5
          if !currentCity? or cityName != formatCityName currentCity
            locations.push
              city: city
              on: currentDate
            currentCity = city
        currentDate = nextDate
        checkNextDate prefetched
      .catch (err) ->
        console.log 'error', err?.stack ? err
        currentDate = nextDate
        checkNextDate prefetched


    where =
      date:
        '$gte': currentDate
        '$lte': endDate

    LocationDay
    .where where
    .populate 'city'
    .find (err, locs) ->
      data = {}
      if locs?.length > 0
        for loc in locs
          y = loc.year
          m = loc.month
          d = loc.day
          data[y] = {} unless data[y]
          data[y][m] = {} unless data[y][m]
          data[y][m][d] = loc.city
      checkNextDate data

  getPostsOnDay = (year, month, day, next) ->
    parsedDate = Date.UTC year, month, day
    startDate = new Date parsedDate - 86400000 * 0.5
    endDate = new Date parsedDate + 86400000 * 1.5

    me = System.getMe()

    where =
      identity: me._id
      postedAt:
        '$gt': startDate
        '$lt': endDate

    ActivityItem
    .where where
    .populate 'identity'
    .sort postedAt: -1
    .find (err, items) ->
      next err, items


  myLastLocation = (req, res, next) ->
    getLastLocation()
    .done (item) ->
      res.send item
    , (err) ->
      next err

  clearNear = (lng, lat, next) ->
    where =
      location:
        $near:
          $geometry:
            type: 'Point'
            coordinates: [lng, lat]
          $maxDistance: 100000

    Place
    .where where
    .find (err, cities) ->
      console.error err if err
      cityIds = _.map cities, '_id'
      cityNames = _.map cities, 'name'
      # console.log cityNames
      console.log 'cities to clear', cityNames, JSON.stringify where
      LocationDay
      .where
        inferred: true
        userInput: false
        city:
          $in: cityIds
      .remove (err, count) ->
        return next err if err
        next null, count

  routes:
    admin:
      '/admin/location/get': 'get'
      '/admin/location/clearnear': 'clearNear'
      '/admin/location/byday/:year/:month/:day': 'getCityOnDay'
      '/admin/location/edit/:year/:month/:day': 'editDay'
      '/admin/location/posts/:year/:month/:day': 'getPostsOnDay'
    public:
      '/location/get': 'get'
      '/posts/day/:year/:month/:day': 'getPostsOnDay'

  handlers:
    get: get
    clearNear: (req, res, next) ->
      lng = parseFloat req.query.lng
      lat = parseFloat req.query.lat
      clearNear lng, lat, (err, count) ->
        return next err if err
        res.send
          message: 'removed'
          count: count
    editDay: (req, res, next) ->
      {year, month, day} = req.params
      year = parseInt year
      month = -1 + parseInt month
      day = parseInt day

      done = (city) ->
        data =
          date: new Date Date.UTC year, month, day
          dateKey: LocationDay.makeDateKey year, month, day
          year: year
          month: month
          day: day
          location: city
          title: "#{moment.utc([year, month, day]).format('MMM D')}: Where was I?"
        res.render 'editDay', data

      saveIt = (place) ->
        console.log 'saveIt', place
        # where =
        #   year: year
        #   month: month
        #   day: day
        where =
          dateKey: LocationDay.makeDateKey year, month, day
        LocationDay
        .where where
        .findOne (err, locDay) ->
          return next err if err
          if !locDay
            console.log 'create new locDay'
            obj =
              dateKey: LocationDay.makeDateKey year, month, day
              year: year
              month: month
              day: day
              city: place._id
              date: new Date Date.UTC year, month, day
            locDay = new LocationDay obj
          locDay.inferred = false
          locDay.userInput = true
          locDay.city = place._id
          console.log 'locDay', locDay
          locDay.save (err) ->
            return next err if err
            clearNear place.location[0], place.location[1], (err, count) ->
              return next err if err
              done place.data

      if req.body?.cityId
        cityId = req.body.cityId
        where =
          'data.cityId': cityId
        Place
        .where where
        .findOne (err, place) ->
          return next err if err
          if place
            return saveIt place
          saveLevelCityToMongo cityId, (err, place) =>
            return next err if err
            saveIt place
        return

      getCityOnDay year, month, day
      .done (city) ->
        done city
      , (err) ->
        next err

    getCityOnDay: (req, res, next) ->
      {year, month, day} = req.params
      year = parseInt year
      month = -1 + parseInt month
      day = parseInt day
      getCityOnDay year, month, day
      .then (city) ->
        res.send city: city
      .catch (err) ->
        next err

    getPostsOnDay: (req, res, next) ->
      {year, month, day} = req.params
      console.log "getPostsOnDay", year, month, day
      year = parseInt year
      month = -1 + parseInt month
      day = parseInt day
      startDate = new Date Date.UTC year, month, day
      endDate = new Date startDate.getTime() + 86400000
      getPostsOnDay year, month, day, (err, items) ->
        return next err if err
        offset = getTimezoneOffsetFromItems items
        minTime = startDate.getTime() - offset * 60 * 60 * 1000
        maxTime = endDate.getTime() - offset * 60 * 60 * 1000
        items = _.filter items, (item) ->
          t = item.postedAt.getTime()
          minTime <= t < maxTime
        if req.params.format == 'json'
          res.send
            posts: items ? []
        else
          themes = System.getGlobal 'public.blog.themes'
          blogSettings = getBlogSettings?()
          themeName = blogSettings?.theme
          unless themes[themeName]?.components?.layout
            console.log themeName, 'not found. using', blogSettings?.theme, 'instead'
            themeName = blogSettings?.theme
          theme = themes[themeName]
          res.render 'kerplunk-stream:list',
            layout: theme?.components?.layout
            blogSettings: blogSettings
            data: items


  events:
    ask:
      getTown:
        do: (data) ->
          deferred = Promise.defer()
          getTown data.parameters.lng, data.parameters.lat, (err, city) ->
            data.answer = city
            deferred.resolve data
          deferred.promise
    me:
      location:
        last:
          do: getCurrentCity
    init:
      post: ->
        getCurrentCity()
        .then (city) ->
          console.log 'I was last seen in', city.city

module.exports.getTimezoneOffsetFromItems = getTimezoneOffsetFromItems
