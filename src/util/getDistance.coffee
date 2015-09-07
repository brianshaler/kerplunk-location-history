toRad = (deg) -> Math.PI * deg / 180

module.exports = (p1, p2) ->
  [lon1, lat1] = p1
  [lon2, lat2] = p2
  R = 3959 # miles; R(km):6371
  dLat = toRad lat2 - lat1
  dLon = toRad lon2 - lon1
  lat1 = toRad lat1
  lat2 = toRad lat2
  a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
  a += Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2)
  c = 2 * Math.atan2 Math.sqrt(a), Math.sqrt(1 - a)
  d = R * c
