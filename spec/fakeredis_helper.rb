require "fakeredis"

RSpec.configure do |config|
  config.before(:each) do
    Redis.current.flushall
  end
end
