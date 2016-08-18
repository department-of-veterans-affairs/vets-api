require "fakeredis"

Redis.current = FakeRedis::Redis.new

RSpec.configure do |config|
  config.before(:each) do
    Redis.current.flushall
  end
end
