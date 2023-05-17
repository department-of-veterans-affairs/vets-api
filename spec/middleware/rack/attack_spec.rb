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
    Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new($redis)
  end

  describe '#throttled_response' do
    it 'adds X-RateLimit-* headers to the response' do
      post('/v0/limited', headers:)
      expect(last_response.status).not_to eq(429)

      post('/v0/limited', headers:)
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
      post('/covid_vaccine/v0/registration', headers:)
      expect(last_response.status).not_to eq(429)
      put('/covid_vaccine/v0/registration/opt_out', headers:)
      expect(last_response.status).not_to eq(429)
      put('/covid_vaccine/v0/registration/opt_in', headers:)
      expect(last_response.status).not_to eq(429)
      put('/covid_vaccine/v0/registration/unauthenticated', headers:)
      expect(last_response.status).not_to eq(429)

      put('/covid_vaccine/v0/registration/opt_out', headers:)
      expect(last_response.status).to eq(429)
    end
  end

  describe 'check_in/ip' do
    let(:data) { { data: 'foo', status: 200 } }

    context 'when more than 10 requests' do
      context 'when GET endpoint' do
        before do
          allow_any_instance_of(CheckIn::V2::Session).to receive(:authorized?).and_return(true)
          allow_any_instance_of(V2::Lorota::Service).to receive(:check_in_data).and_return(data)

          10.times do
            get('/check_in/v2/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d', headers:)

            expect(last_response.status).to eq(200)
          end
        end

        it 'throttles with status 429' do
          get('/check_in/v2/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d', headers:)

          expect(last_response.status).to eq(429)
        end
      end

      context 'when POST endpoint' do
        let(:post_params) do
          { patient_check_ins: { uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d', appointment_ien: '450' } }
        end

        before do
          allow_any_instance_of(V2::Chip::Service).to receive(:create_check_in).and_return(data)

          10.times do
            post '/check_in/v2/patient_check_ins', post_params, headers

            expect(last_response.status).to eq(200)
          end
        end

        it 'throttles with status 429' do
          post '/check_in/v2/patient_check_ins', post_params, headers

          expect(last_response.status).to eq(429)
        end
      end
    end
  end

  describe 'medical_copays/ip' do
    before do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return([])
    end

    context 'when more than 20 requests' do
      before do
        20.times do
          get('/v0/medical_copays', headers:)

          expect(last_response.status).to eq(401)
        end
      end

      it 'throttles with status 429' do
        get('/v0/medical_copays', headers:)

        expect(last_response.status).to eq(429)
      end
    end
  end

  describe 'facility_locator/ip' do
    let(:endpoint) { '/facilities_api/v1/ccp/provider' }
    let(:headers) { { 'X-Real-Ip' => '1.2.3.4' } }
    let(:limit) { 8 }

    before do
      limit.times do
        get endpoint, nil, headers
        expect(last_response.status).not_to eq(429)
      end

      get endpoint, nil, other_headers
    end

    context 'response status for repeated requests from the same IP' do
      let(:other_headers) { headers }

      it 'limits requests' do
        expect(last_response.status).to eq(429)
      end
    end

    context 'response status for request from different IP' do
      let(:other_headers) { { 'X-Real-Ip' => '4.3.2.1' } }

      it 'limits requests' do
        expect(last_response.status).not_to eq(429)
      end
    end
  end

  describe 'vic rate-limits', run_at: 'Thu, 26 Dec 2015 15:54:20 GMT' do
    before do
      limit.times do
        post(endpoint, headers:)
        expect(last_response.status).not_to eq(429)
      end

      post endpoint, headers:
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
