module("store", package.seeall)

local redtool = require "redtool"
local redis = require "resty.redis"
local config = require "config"

function init()
    local red = redis:new()
    local sub = redis:new()
    redtool.set_timeout(red, 1000)
    redtool.set_timeout(sub, 5000)
    redtool.open(red, config.REDIS_HOST, config.REDIS_PORT)
    redtool.open(sub, config.REDIS_HOST, config.REDIS_PORT)
    return red, sub
end

function get_channels(red, oid, uid)
    channels = red:lrange(string.format(config.IRC_USER_CHANNELS_FORMAT, oid, uid), 0, -1)
    return channels
end

function set_online(red, oid, cid, uid, uname)
    local res, err = red:hmset(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid, uname)
end

function set_offline(red, oid, cid, uid)
    local res, err = red:hdel(string.format(config.IRC_CHANNEL_ONLINE, oid, cid), uid)
end

function sub_channel(sub, key)
    local res, err = sub:subscribe(key)
    if not res then
        ngx.say("failed to subscribe: ", err)
        return ngx.exit(502)
    end
end

function unsub_channel(sub, key)
    local res, err = sub:unsubscribe(key)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function pubish_message(red, oid, cid, message, uname, uid)
    local msg_key = string.format(config.IRC_CHANNEL_MESSAGES, oid, cid)
    local pub_key = string.format(config.IRC_CHANNEL_PUBSUB, oid, cid)
    local timestamp = tostring(os.time())
    local msg = {timestamp, uid, uname, message}
    msg = table.concat(msg, ':')
    red:init_pipeline()
    red:zadd(msg_key, timestamp, msg)
    red:publish(pub_key, msg)
    local results, err = red:commit_pipeline()
    if not results then
        ngx.log(ngx.ERR, "failed to commit the pipelined requests: ", err)
        return
    end
end

function get_last_messages(red, oid, cid, timestamp)
    local key = string.format(config.IRC_CHANNEL_MESSAGES, oid, cid)
    local messages = red:zrangebyscore(key, tostring(timestamp), tostring(os.time()))
    -- limit messges
    return messages
end

function read_message(sub)
    res, err = sub:read_reply()
    if not res and not string.find(err, "timeout") then
        ngx.log(ngx.ERR, err)
        return
    end
    return res
end

function close(red, sub)
    redtool.close(red, 600000, config.REDIS_POOL_SIZE)
    redtool.close(sub, 600000, config.REDIS_POOL_SIZE)
end

