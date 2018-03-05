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

  describe 'vic submission rate-limiting' do
    context 'for submissions and uploads' do
      before do
        limit.times do
          post endpoint, {}, 'REMOTE_ADDR' => '1.2.3.4'
          expect(last_response.status).to_not eq(429)
        end

        post endpoint, {}, 'REMOTE_ADDR' => '1.2.3.4'
      end

      context 'profile photo' do
        let(:limit) { 4 }
        let(:endpoint) { '/v0/vic/profile_photo_attachments' }
        it 'limits profile photo uploads' do
          expect(last_response.status).to eq(429)
        end
      end

      context 'supporting docs' do
        let(:limit) { 6 }
        let(:endpoint) { '/v0/vic/supporting_documentation_attachments' }
        it 'limits supporting documentation uploads' do
          expect(last_response.status).to eq(429)
        end
      end

      context 'submissions' do
        let(:limit) { 5 }
        let(:endpoint) { '/v0/vic/submissions' }
        it 'limits submissions' do
          expect(last_response.status).to eq(429)
        end
      end
    end

    context 'vic downloads' do
      it 'limits profile photo downloads' do
        4.times do
          get '/v0/vic/profile_photo_attachments', {}, 'REMOTE_ADDR' => '1.2.3.4'
          expect(last_response.status).to_not eq(429)
        end

        get '/v0/vic/profile_photo_attachments', {}, 'REMOTE_ADDR' => '1.2.3.4'
        expect(last_response.status).to eq(429)
      end
    end
  end

  before(:all) do
    Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.current)
  end

  before(:each) do
    Rack::Attack.cache.store.flushdb
  end
end
