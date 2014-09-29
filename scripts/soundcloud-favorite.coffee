# Description
#   Notify soundcloud favorited track for the specified users.
#
# Dependencies:
#   "request": "~> 2.34"
#
# Configuration:
#   HUBOT_SOUNDCLOUD_CLIENTID: API client_id for SoundCloud
#
# Commands:
#   hubot soundcloud-fav add <user_name> - Add user in current room
#   hubot soundcloud-fav remove <user_name> - Remove user in current room
#   hubot soundcloud-fav list - List users in current room
#
# Notes:
#   None
#
# Author:
#   Yusuke Fujiki (@fujikky)

API_INTERVAL = parseInt(process.env.HUBOT_SOUNDCLOUD_FETCH_INTERVAL, 10)
API_INTERVAL = (10 * 60 * 1000) if isNaN(API_INTERVAL) # 10 min
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
      @getRooms().push roomId
      @save()
      return true

    return false

  removeRoom: (roomId) ->
    index = _cache[@userId].rooms.indexOf(roomId)
    if index != -1
      @robot.logger.debug "Add roomId: '#{roomId}'"
      @getRooms().splice index, 1
      @save()
      return true

    return false

  getRooms: ->
    _cache[@userId].rooms

  hasTrack: (trackId) ->
    return _cache[@userId].trackIds.indexOf(trackId) != -1

  addTrack: (trackId) ->
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

  commonError = (msg) ->
    unless API_CLIENT_ID
      msg.reply "HUBOT_SOUNDCLOUD_CLIENTID must be defined."
      return false
    return true

  getUserId = (msg) ->
    userId = msg.match[1].trim()

    unless userId
      msg.reply "Tell me soundcloud user_id!"
      return false

    return userId

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

      try
        # notify to each rooms
        for roomId in store.getRooms()
          robot.messageRoom roomId, """
            @#{store.userId} fav! #{track.title}
            #{track.permalink_url}
          """
      catch error
        robot.logger.error "Slack API Error #{error}"
        return

      # save track id to brain
      if not store.addTrack track.id
        return

      return
    return

  robot.respond /soundcloud-fav list$/i, (msg) ->
    unless commonError msg
      return

    roomId = SoundCloudStore.getRoomId(msg)
    users = SoundCloudStore.getRoomUsers(robot, roomId)

    if users.length == 0
      msg.reply "Empty list in room '#{roomId}'!"
      return

    msg.reply "List of room '#{roomId}'\n#{users.join("\n")}"

  robot.respond /soundcloud-fav add (.*)$/i, (msg) ->
    unless commonError msg
      return

    unless userId = getUserId msg
      return

    store = new SoundCloudStore(robot, userId)
    roomId = SoundCloudStore.getRoomId(msg)

    if store.addRoom(roomId)
      msg.reply "OK! Added user '#{userId}' in room '#{roomId}'."
      return

    msg.reply "Already exists user '#{userId}' in room '#{roomId}'."

  robot.respond /soundcloud-fav remove (.*)$/i, (msg) ->
    unless commonError msg
      return

    unless userId = getUserId msg
      return

    store = new SoundCloudStore(robot, userId)
    roomId = SoundCloudStore.getRoomId(msg)

    if store.removeRoom(roomId)
      msg.reply "OK! Removed user '#{userId}' in room '#{roomId}'."
      return

    msg.reply "Not exist user '#{userId}' in room '#{roomId}'."

  setTimeout runAll, 3000
  setInterval runAll, API_INTERVAL
  return
