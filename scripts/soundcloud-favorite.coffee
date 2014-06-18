# Description
#   Notify favorite track for the specified users.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_SOUNDCLOUD_CLIENTID: API client_id for SoundCloud
#
# Commands:
#   None
#
# Notes:
#
# Author:
#   Yusuke Fujiki (@fujikky)

API_INTERVAL = process.env.HUBOT_SOUNDCLOUD_FETCH_INTERVAL || 60 * 1000 #35 * 60 * 1000 # 5 min
API_CLIENT_ID = process.env.HUBOT_SOUNDCLOUD_CLIENTID

Request = require('request')

class SoundCloudStore
  _cache = null

  @getAllStores: (robot) ->
    stores = []

    userIds = robot.brain.get("soundcloud")
    if not userIds
      return stores

    for userId, data of userIds
      stores.push(new SoundCloudStore(robot, userId))

    return stores

  @reset: (robot) ->
    robot.brain.soundcloud = null

  constructor: (robot, userId) ->
    @robot = robot
    @userId = userId
    _cache = robot.brain.get("soundcloud")

    if not _cache
      _cache = {}

    if not _cache[userId]
      _cache[userId] = {
        rooms: [],
        trackIds: []
      }

    @save()

  addRoom: (roomId) ->
    if _cache[@userId].rooms.indexOf(roomId) == -1
      @robot.logger.debug "Add roomId: '#{roomId}'"
      _cache[@userId].rooms.push roomId
      @save()
      return true

    return false

  getRooms: ->
    _cache[@userId].rooms

  hasTrack: (trackId) ->
    return _cache[@userId].trackIds.indexOf(trackId) != -1

  addTrack: (trackId) ->
    console.log trackId
    console.log _cache[@userId].trackIds
    if _cache[@userId].trackIds.indexOf(trackId) == -1
      @robot.logger.debug "Add trackId: '#{trackId}'"
      _cache[@userId].trackIds.push trackId
      @save()
      return true

    return false

  save: () ->
    @robot.brain.set "soundcloud", _cache
    @robot.logger.debug "Saved!: #{JSON.stringify(_cache)}"

module.exports = (robot) ->

  robot.respond /soundcloud fav(orite) reset$/i, (msg) ->
    SoundCloudStore.reset()
    msg.reply "Resetted all my SoundCloud's data!"

  robot.respond /soundcloud fav(orite)? (.*)$/i, (msg) ->
    unless API_CLIENT_ID
      msg.reply "HUBOT_SOUNDCLOUD_CLIENTID must be defined."
      return

    userId = msg.match[2].trim()

    unless userId
      msg.reply "Tell me soundcloud user_id!"
      return

    robot.logger.debug "userId: #{userId}"
    store = new SoundCloudStore(robot, userId)
    robot.logger.debug "store ok"
    roomId = if msg.message.data
      msg.message.data.room_id
    else if msg.message.room
      msg.message.room
    else
      throw "`message` has no room_id:"

    robot.logger.debug "will add"
    console.log store.addRoom.toString()

    if store.addRoom roomId
      robot.logger.debug "did add"
      msg.reply "OK! Added User:'#{userId}' Room:'#{roomId}'"
      return

    robot.logger.debug "did not add"
    msg.reply = "Already exist User:'#{userId}' Room:'#{roomId}'"

  getFav = () ->
    stores = SoundCloudStore.getAllStores(robot)
    for store in stores

      options =
        url: "https://api.soundcloud.com/users/#{store.userId}/favorites.json?client_id=#{API_CLIENT_ID}"

      console.log options
      Request.get options, (error, response, body) =>
        unless response.statusCode == 200
          robot.logger.error "SoundCloud API Error #{response.statusCode}"
          return

        tracks = JSON.parse(body)

        if tracks.length == 0
          return

        # get latest track
        track = tracks[0]

        # save track id to brain
        if not store.addTrack track.id
          return

        # notify to each rooms
        for roomId in store.getRooms()
          robot.messageRoom roomId, """
            @#{store.userId} fav! #{track.title}
            #{track.permalink_url}
          """
          continue

        return
    return

  setTimeout getFav, 3000
  setInterval getFav, API_INTERVAL
