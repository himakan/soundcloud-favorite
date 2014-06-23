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

API_INTERVAL = parseInt(process.env.HUBOT_SOUNDCLOUD_FETCH_INTERVAL, 10)
API_INTERVAL = (5 * 60 * 1000) if isNaN(API_INTERVAL) # 5 min
API_CLIENT_ID = process.env.HUBOT_SOUNDCLOUD_CLIENTID

Request = require('request')

class SoundCloudStore
  _cache = null

  @getRoomId: (msg) ->
    if msg.message.data
      return msg.message.data.room_id
    else if msg.message.room
      return msg.message.room
    else
      throw "`message` has no room_id:"

  @getAllStores: (robot) ->
    stores = []

    userIds = robot.brain.get("soundcloud")
    if not userIds
      return stores

    for userId, data of userIds
      stores.push(new SoundCloudStore(robot, userId))

    return stores

  @getRoomUsers: (robot, roomId) ->
    userIds = robot.brain.get("soundcloud")
    users = []

    for userId, user of userIds
      console.log("userId", userId)
      console.log("user", user)
      if user.rooms.indexOf(roomId) != -1
        users.push userId

    console.log("users", roomId)
    return users

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

  robot.respond /soundcloud-fav list$/i, (msg) ->
    roomId = SoundCloudStore.getRoomId(msg)
    console.log("roomId : #{roomId}")

    users = SoundCloudStore.getRoomUsers(robot, roomId)

    if users.length == 0
      msg.reply "Empty list in room '#{roomId}'!"
      return

    msg.reply "List of room '#{roomId}'\n#{users.join("\n")}"

  robot.respond /soundcloud-fav listen (.*)$/i, (msg) ->
    unless API_CLIENT_ID
      msg.reply "HUBOT_SOUNDCLOUD_CLIENTID must be defined."
      return

    userId = msg.match[1].trim()

    unless userId
      msg.reply "Tell me soundcloud user_id!"
      return

    store = new SoundCloudStore(robot, userId)
    roomId = SoundCloudStore.getRoomId(msg)

    if store.addRoom(roomId)
      msg.reply "OK! Added User:'#{userId}' Room:'#{roomId}'"
      return

    msg.reply "Already exist User:'#{userId}' Room:'#{roomId}'"

  robot.respond /soundcloud-fav ignore (.*)$/i, (msg) ->
    msg.reply "Sorry, waiting for implementation!"

  runAll = () ->
    stores = SoundCloudStore.getAllStores(robot)
    for store in stores
      getFav store
    return

  getFav = (store) ->
    if store.getRooms().length == 0
      return

    options =
      url: "https://api.soundcloud.com/users/#{store.userId}/favorites.json?client_id=#{API_CLIENT_ID}"

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

      return
    return

  setTimeout runAll, 3000
  setInterval runAll, API_INTERVAL
  return
