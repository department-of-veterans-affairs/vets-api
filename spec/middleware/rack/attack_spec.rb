# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rack::Attack do
  include Rack::Test::Methods

  let(:headers) { { 'REMOTE_ADDR' => '1.2.3.4' } }

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
      post '/v0/limited', headers: headers
      expect(last_response.status).not_to eq(429)

      post '/v0/limited', headers: headers
      expect(last_response.status).to eq(429)
      expect(last_response.headers).to include(
        'X-RateLimit-Limit',
        'X-RateLimit-Remaining',
        'X-RateLimit-Reset'
      )
    end
  end

  describe 'covid_vaccine' do
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

  describe 'check_in/ip' do
    let(:data) { { data: 'foo', status: 200 } }

    context 'when more than 10 requests' do
      context 'when GET endpoint' do
        before do
          allow_any_instance_of(ChipApi::Service).to receive(:get_check_in).and_return(data)

          10.times do
            get '/check_in/v0/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d', headers: headers

            expect(last_response.status).to eq(200)
          end
        end

        it 'throttles with status 429' do
          get '/check_in/v0/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d', headers: headers

          expect(last_response.status).to eq(429)
        end
      end

      context 'when POST endpoint' do
        let(:post_params) { { patient_check_ins: { id: 'd602d9eb-9a31-484f-9637-13ab0b507e0d' } } }

        before do
          allow_any_instance_of(ChipApi::Service).to receive(:create_check_in).and_return(data)

          10.times do
            post '/check_in/v0/patient_check_ins', post_params, headers # rubocop:disable Rails/HttpPositionalArguments

            expect(last_response.status).to eq(200)
          end
        end

        it 'throttles with status 429' do
          post '/check_in/v0/patient_check_ins', post_params, headers # rubocop:disable Rails/HttpPositionalArguments

          expect(last_response.status).to eq(429)
        end
      end
    end
  end

  describe 'vic rate-limits', run_at: 'Thu, 26 Dec 2015 15:54:20 GMT' do
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
