# Description
#   Notify favorite track for the specified users.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_SOUNDCLOUD_CLIENTID: API client_id for SoundCloud
#   HUBOT_SOUNDCLOUD_USER_IDS: commma-separeted user_id for SoundCloud
#   HUBOT_SOUNDCLOUD_NOTIFY_ROOM_ID: room_id to notify
#
# Commands:
#   None
#
# Notes:
#
# Author:
#   Yusuke Fujiki (@fujikky)

API_INTERVAL = 5 * 60 * 1000 # 5 min
API_CLIENT_ID = process.env.HUBOT_SOUNDCLOUD_CLIENTID
API_USER_IDS = process.env.HUBOT_SOUNDCLOUD_USER_IDS
ROOM_ID = process.env.HUBOT_SOUNDCLOUD_NOTIFY_ROOM_ID

module.exports = (robot) ->
  unless (API_CLIENT_ID and API_USER_IDS)
    robot.messageRoom ROOM_ID, "HUBOT_SOUNDCLOUD_CLIENTID and HUBOT_SOUNDCLOUD_USER_IDS must be defined."
    return
    
  getFavorite = (userId) ->
    robot.http("https://api.soundcloud.com/users/#{userId}/favorites.json")
    .query({
      cliend_id: API_CLIENT_ID
    })
    .get(err, res, body) ->
      if res.statusCode is 200
        data = JSON.parse(body)
        # todo: filter latest non-posted track
        track = robot.random data
        robot.messageRoom ROOM_ID, "#{userId} liked! #{track.title} #{track.permalink_url}"
        
        # todo: save posted track id to local file
          
  userIds = API_USER_IDS.split(",") || []
    
  setInterval (->
    
    for userId of userIds
      getFavorite userId

  ), API_INTERVAL
  
