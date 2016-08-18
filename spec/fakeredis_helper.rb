require "fakeredis/rspec"

Redis.current = FakeRedis::Redis.new
