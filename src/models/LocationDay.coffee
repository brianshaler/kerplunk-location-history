###
# Location Day schema
###

moment = require 'moment'

module.exports = (mongoose) ->
  Schema = mongoose.Schema
  ObjectId = Schema.ObjectId

  LocationDaySchema = new Schema
    dateKey:
      type: String
      index:
        unique: true
      required: true
    year: Number
    month: Number
    day: Number
    date: Date
    city:
      type: ObjectId
      index: true
      ref: 'Place'
    inferred: Boolean
    userInput: Boolean
    createdAt:
      type: Date
      default: Date.now

  LocationDaySchema.statics.makeDateKey = (year, month, day) ->
    moment.utc [year, month, day]
      .format 'YYYY-MM-DD'

  mongoose.model 'LocationDay', LocationDaySchema
