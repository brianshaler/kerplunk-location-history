_ = require 'lodash'
React = require 'react'
moment = require 'moment'

{DOM} = React

getCities = (history) ->
  _.reduce history, (memo, item) ->
    return memo unless item?.data?.venue?.location?.city
    location = item.data.venue.location
    memo[location.city] = location
    memo[location.city].name = location.city
    memo
  , {}

module.exports = React.createFactory React.createClass
  getInitialState: ->
    history: []
    loading: false
    location: @props.location
    savedLocation: @props.location
    citiesByName: @props.citiesByName ? {}

  onClose: (e) ->
    e.preventDefault()
    @props.onClose()

  getCity: (city) ->
    console.log 'getCity', city.name, city
    url = '/admin/place/search.json'
    @props.request.get url, {keyword: city.name}, (err, data) =>
      return unless @isMounted()
      return console.log err if err
      return console.log 'no results for', city.name unless data?.length > 0
      results = _.sortBy data, (c) ->
        score = if c.name == city.name then 100 else -100
        score += c.population / Math.pow 10, 9
        console.log 'score', c.name, score
        -score
      citiesByName = _.clone @state.citiesByName
      citiesByName[city.name] = results[0]
      console.log 'result', city.name, results[0]
      @setState
        citiesByName: citiesByName
    citiesByName = _.clone @state.citiesByName
    citiesByName[city.name] =
      name: city.name
      cityId: 'loading cityId'
      lat: city.lat
      lng: city.lng
    @setState
      citiesByName: citiesByName

  getCities: (cities) ->
    console.log 'getcities', cities
    _.map cities, (city) =>
      existing = _.find @state.cities, (c) ->
        c.name == city.name
      if !existing
        @getCity city

      name: city.name
      cityId: existing?.cityId
      lat: city.lat
      lng: city.lng

  componentDidMount: ->
    console.log 'sup'
    key = "history-#{@props.dateKey}"

    @history = ReactiveData.Item
      key: key
      Repository: @props.Repository
    @history.listen @, 'history'

    history = @props.Repository.getLatest(key) ? []

    if history.length > 0
      cities = getCities history
      @setState
        loading: false
        history: history
        cities: @getCities cities
      return

    @setState
      loading: true
      history: history

    year = @props.year
    month = @props.month
    day = @props.day

    url = "/admin/location/posts/#{moment.utc([year,month,day]).format('YYYY/MM/DD')}.json"
    # console.log url

    @props.request.get url, null, (err, data) =>
      return unless @isMounted()
      return console.log err if err
      return unless data?.posts?.length > 0
      history = @props.Repository.getLatest(key) ? {}
      @props.Repository.update key, data.posts
      cities = getCities data.posts
      console.log 'getCitiesByName', cities
      @setState
        loading: false
        cities: @getCities cities

  componentWillUnmount: ->
    @history.unlisten @

  search: (e) ->
    value = e.target.value
    console.log 'search', value

  commitLocation: (e) ->
    e.preventDefault?()
    {year, month, day} = @props
    url = "/admin/location/edit/#{moment.utc([year,month,day]).format('YYYY/MM/DD')}.json"
    options =
      cityId: @state.location.cityId
    @props.request.post url, options, (err, data) =>
      if data?.state?.location
        @setState
          savedLocation: data.state.location
          location: data.state.location
      console.log 'response', err, data

  render: ->
    ItemComponent = @props.getComponent @props.globals.public.streamItem

    locationSegments = [@state.location.name]
    if @state.location.region
      locationSegments.push @state.location.region
    if @state.location.country
      locationSegments.push @state.location.country
    displayCurrentLocation = locationSegments.join ', '

    history = @state.history ? []
    CityAutocomplete = @props.getComponent 'kerplunk-city-autocomplete:input'

    #cities = getCities history
    cities = @state.citiesByName

    YMD = [@props.year, @props.month, @props.day]
    yesterdayYMD = new Date Date.UTC YMD[0], YMD[1], YMD[2] - 1
    tomorrowYMD = new Date Date.UTC YMD[0], YMD[1], YMD[2] + 1

    DOM.section
      className: 'content'
    ,
      # a
      #   style:
      #     float: 'right'
      #   href: '#'
      #   onClick: @onClose
      # , '[x]'
      DOM.h3 null, 'edit day'
      DOM.div null,
        DOM.div null,
          DOM.a
            href: "/admin/location/edit/#{moment.utc(yesterdayYMD).format('YYYY/MM/DD')}"
            onClick: @props.pushState
            style:
              float: 'left'
          , "< #{moment.utc(yesterdayYMD).format('MMM D')}"
          DOM.a
            href: "/admin/location/edit/#{moment.utc(tomorrowYMD).format('YYYY/MM/DD')}"
            onClick: @props.pushState
            style:
              float: 'right'
          , "#{moment.utc(tomorrowYMD).format('MMM D')} >"
        DOM.div className: 'clearfix'
        DOM.div null,
          CityAutocomplete _.extend {}, @props,
            onChange: @search
            city: @state.location
            location: @props.location?.location ? @state.location?.location
            onSelect: (city) =>
              console.log 'setting location', city
              @setState
                location: city
          # DOM.input
          #   defaultValue: displayCurrentLocation
          #   onChange: @search
          #   city: @state.location
          DOM.input
            style:
              display: 'none' if @state?.location?.name == @state.savedLocation?.name
            type: 'button'
            onClick: @commitLocation
            value: 'save'
          _.map cities, (city, index) =>
            DOM.div
              key: "city-#{index}"
            ,
              city.name
              ' '
              DOM.a
                href: '#' + city.cityId
                onClick: (e) =>
                  e.preventDefault()
                  @setState
                    location: city
              , 'save'
        DOM.div null,
          DOM.strong null, displayCurrentLocation
      # DOM.pre null, JSON.stringify @props, null, 2
      # DOM.pre null, JSON.stringify @state, null, 2
      if history?.length > 0
        _.map history, (item) =>
          ItemComponent _.extend {}, @props, {
            key: "history-#{item._id}"
            item: item
            itemId: item._id
          }
      else
        DOM.div null, 'no items..'
