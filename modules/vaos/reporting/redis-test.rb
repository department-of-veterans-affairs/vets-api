require 'redis'

REDIS_CONNECTION = Redis.new(host: "localhost")

def start_server
  system("redis-server")
end

def save(key, value)
  REDIS_CONNECTION.set(key, value)
end

def load(key)
  REDIS_CONNECTION.get(key)
end

#start_server
