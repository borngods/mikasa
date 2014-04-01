module("config", package.seeall)

REDIS_HOST = "127.0.0.1"
REDIS_PORT = 6379
REDIS_PASSWORD = nil
REDIS_POOL_SIZE = 100

SESSION_KEY = "tid"
SESSION_HOST = "127.0.0.1"
SESSION_PORT = 6379
SESSION_PASSWORD = nil
SESSION_POOL_SIZE = 1000

SESSION_FORMAT = "session:%s"

IRC_USER_CHANNELS_FORMAT = "irc:%s:user_%s:channels"
IRC_CHANNEL_ONLINE = "irc:%s:%s:online"
IRC_CHANNEL_PUBSUB = "irc:%s:%s:pubsub"
IRC_CHANNEL_MESSAGES = "irc:%s:%s:messages"
