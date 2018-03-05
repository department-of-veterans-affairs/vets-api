# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack::Attack do
  include Rack::Test::Methods

  def app
    Rails.application
  end

  describe '#throttled_response' do
    it 'adds X-RateLimit-* headers to the response' do
      post '/v0/limited', {}, 'REMOTE_ADDR' => '1.2.3.4'
      expect(last_response.status).to_not eq(429)

      post '/v0/limited', {}, 'REMOTE_ADDR' => '1.2.3.4'
      expect(last_response.status).to eq(429)
      expect(last_response.headers).to include(
        'X-RateLimit-Limit',
        'X-RateLimit-Remaining',
        'X-RateLimit-Reset'
      )
    end
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

  describe 'vic submission limits' do
    let(:request_type) { post }

    context 'with an anonymous user' do
      it 'limits profile photo uploads' do
        4.times do
          post '/v0/vic/profile_photo_attachments', {}, 'REMOTE_ADDR' => '1.2.3.4'
          expect(last_response.status).to_not eq(429)
        end

        post '/v0/vic/profile_photo_attachments'
        expect(last_response.status).to eq(429)
      end

      it 'limits profile photo downloads' do
        4.times do
          get '/v0/vic/profile_photo_attachments', {}, 'REMOTE_ADDR' => '1.2.3.4'
          expect(last_response.status).to_not eq(429)
        end

        get '/v0/vic/profile_photo_attachments'
        expect(last_response.status).to eq(429)
      end
    end

    # context 'with a logged in user' do

    # end
  end

  before(:all) do
    Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.current)
  end

  before(:each) do
    Rack::Attack.cache.store.flushdb
  end
end
