# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack::Attack do
  include Rack::Test::Methods

  def app
    Rails.application
  end

  describe 'feedback submission limits' do
    it 'responds with 429 after 5 requests' do
      5.times do
        post '/v0/feedback', {}, 'REMOTE_ADDR' => '1.2.3.4'
        expect(last_response.status).to_not eq(429)
      end

      post '/v0/feedback', {}, 'REMOTE_ADDR' => '1.2.3.4'
      expect(last_response.status).to eq(429)
    end
  end

  before(:all) do
    Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.current)
  end

  before(:each) do
    Rack::Attack.cache.store.flushdb
  end
end
