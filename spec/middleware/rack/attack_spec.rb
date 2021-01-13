# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack::Attack do
  include Rack::Test::Methods

  def app
    Rails.application
  end

  before do
    Rack::Attack.cache.store.flushdb
  end

  before(:all) do
    Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.current)
  end

  describe '#throttled_response' do
    it 'adds X-RateLimit-* headers to the response' do
      post '/v0/limited', headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      expect(last_response.status).not_to eq(429)

      post '/v0/limited', headers: { 'REMOTE_ADDR' => '1.2.3.4' }
      expect(last_response.status).to eq(429)
      expect(last_response.headers).to include(
        'X-RateLimit-Limit',
        'X-RateLimit-Remaining',
        'X-RateLimit-Reset'
      )
    end
  end

  describe 'covid_vaccine' do
    let(:headers) { { 'REMOTE_ADDR' => '1.2.3.4' } }

    it 'limits requests for any post and put endpoints to 4 in 5 minutes' do
      post '/covid_vaccine/v0/registration', headers: headers
      expect(last_response.status).not_to eq(429)
      put '/covid_vaccine/v0/registration/opt_out', headers: headers
      expect(last_response.status).not_to eq(429)
      put '/covid_vaccine/v0/registration/opt_in', headers: headers
      expect(last_response.status).not_to eq(429)
      put '/covid_vaccine/v0/registration/unauthenticated', headers: headers
      expect(last_response.status).not_to eq(429)

      put '/covid_vaccine/v0/registration/opt_out', headers: headers
      expect(last_response.status).to eq(429)
    end
  end

  describe 'vic rate-limits', run_at: 'Thu, 26 Dec 2015 15:54:20 GMT' do
    let(:headers) { { 'REMOTE_ADDR' => '1.2.3.4' } }

    before do
      limit.times do
        post endpoint, headers: headers
        expect(last_response.status).not_to eq(429)
      end

      post endpoint, headers: headers
    end

    context 'profile photo upload' do
      let(:limit) { 8 }
      let(:endpoint) { '/v0/vic/profile_photo_attachments' }

      it 'limits requests' do
        expect(last_response.status).to eq(429)
      end
    end

    context 'supporting doc upload' do
      let(:limit) { 8 }
      let(:endpoint) { '/v0/vic/supporting_documentation_attachments' }

      it 'limits requests' do
        expect(last_response.status).to eq(429)
      end
    end

    context 'form submission' do
      let(:limit) { 10 }
      let(:endpoint) { '/v0/vic/vic_submissions' }

      it 'limits requests' do
        expect(last_response.status).to eq(429)
      end
    end

    context 'evss claims' do
      let(:limit) { 12 }
      let(:endpoint) { '/v0/evss_claims_async' }

      it 'limits requests' do
        expect(last_response.status).to eq(429)
      end
    end
  end
end
