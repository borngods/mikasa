module("store", package.seeall)

local utils = require "utils"
local config = require "config"

function get_organization_user(red, uid, oid)
    local res, err = red:hmget(string.format(config.IRC_ORGANIZATION_USERS_FORMAT, oid), uid)
    if err then
        ngx.log(ngx.ERR, err)
        return ngx.exit(502)
    end
    if res[1] == ngx.null then
        return false
    end
    return true
end

function get_channels(red, oid, uid)
    local channels, err = red:hgetall(string.format(config.IRC_USER_CHANNELS_FORMAT, oid, uid))
    if not channels then
        ngx.log(ngx.ERR, err)
        return ngx.exit(502)
    end
    local chan = {}
    local tmp = nil
    table.foreach(channels, function(k, v)
        if k % 2 ~= 0 then
            tmp = v
        else
            chan[tmp] = v
        end
    end)
    return chan
end

function set_online(red, oid, cid, uid, uname)
    local res, err = red:hmset(string.format(config.IRC_CHANNEL_ONLINE_FORMAT, oid, cid), uid, uname)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function set_offline(red, oid, cid, uid)
    local res, err = red:hdel(string.format(config.IRC_CHANNEL_ONLINE_FORMAT, oid, cid), uid)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function subscribe(red, keys)
    local res, err = red:subscribe(unpack(keys))
    if not res then
        ngx.say("failed to subscribe: ", err)
        return ngx.exit(502)
    end
end

function unsubscribe(red, key)
    local res, err = red:unsubscribe(key)
    if not res then
        ngx.log(ngx.ERR, err)
    end
end

function publish_online_users(red, oid, channels)
    local map = {}
    for key, chan in pairs(channels) do
        local users, err = red:hgetall(string.format(config.IRC_CHANNEL_ONLINE_FORMAT, oid, chan.id))
        if not users then
            ngx.log(ngx.ERR, err)
        else
            map[key] = string.format("%s:%s", chan.name, table.concat(users, "|"))
        end
    end
    broadcast_without_store(
        red, utils.get_keys(map),
        function(key) return map[key] end
    )
end

function broadcast_without_store(red, keys, message_func)
    for _, key in pairs(keys) do
        local res, err = red:publish(key, message_func(key))
        if not res then
            ngx.log(ngx.ERR, res)
        end
    end
end

function pubish_message(red, oid, cid, message, uname, uid)
    local msg_key = string.format(config.IRC_CHANNEL_MESSAGES_FORMAT, oid, cid)
    local pub_key = string.format(config.IRC_CHANNEL_PUBSUB_FORMAT, oid, cid)
    local timestamp = tostring(os.time())
    local msg = table.concat({timestamp, uid, uname, message}, ':')
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
    local key = string.format(config.IRC_CHANNEL_MESSAGES_FORMAT, oid, cid)
    local messages = red:zrangebyscore(key, tostring(timestamp), tostring(os.time()))
    -- limit messges
    return messages
end

function read_message(red)
    local res, err = red:read_reply()
    if not res and not string.find(err, "timeout") then
        ngx.log(ngx.ERR, err)
        return nil, nil, nil
    elseif res then
        return res[1], res[2], res[3]
    end
end

