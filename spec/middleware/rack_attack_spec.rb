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

  describe 'vic rate-limits', run_at: 'Thu, 26 Dec 2015 15:54:20 GMT' do
    let(:session) { FactoryBot.build(:session) }
    let(:anon_headers) { { 'REMOTE_ADDR' => '1.2.3.4' } }
    let(:auth_headers) { anon_headers.merge('HTTP_AUTHORIZATION' => "Token token=#{session.token}") }

    before do
      expect(::Session).to receive(:exists?).at_least(:once).and_return(true) if headers.include?('HTTP_AUTHORIZATION')

      limit.times do
        post endpoint, {}, headers
        expect(last_response.status).to_not eq(429)
      end

      post endpoint, {}, headers
    end

    context 'profile photo upload' do
      let(:limit) { 4 }
      let(:endpoint) { '/v0/vic/profile_photo_attachments' }

      context 'with an anonymous user' do
        let(:headers) { anon_headers }
        it 'limits requests' do
          expect(last_response.status).to eq(429)
        end
      end

      context 'with a logged in user' do
        let(:headers) { auth_headers }

        it 'does not limit requests' do
          expect(last_response.status).not_to eq(429)
        end
      end
    end

    context 'supporting doc upload' do
      let(:limit) { 6 }
      let(:endpoint) { '/v0/vic/supporting_documentation_attachments' }

      context 'with an anonymous user' do
        let(:headers) { anon_headers }
        it 'limits requests' do
          expect(last_response.status).to eq(429)
        end
      end

      context 'with a logged in user' do
        let(:headers) { auth_headers }

        it 'does not limit requests' do
          expect(last_response.status).not_to eq(429)
        end
      end
    end

    context 'form submission' do
      let(:limit) { 5 }
      let(:endpoint) { '/v0/vic/submissions' }

      context 'with an anonymous user' do
        let(:headers) { anon_headers }
        it 'limits requests' do
          expect(last_response.status).to eq(429)
        end
      end

      context 'with a logged in user' do
        let(:headers) { auth_headers }

        it 'does not limit requests' do
          expect(last_response.status).not_to eq(429)
        end
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
