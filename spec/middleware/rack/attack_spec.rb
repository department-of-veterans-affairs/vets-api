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
      expect(last_response).not_to have_http_status(:too_many_requests)

      post('/v0/limited', headers:)
      expect(last_response).to have_http_status(:too_many_requests)
      expect(last_response.headers).to include(
        'X-RateLimit-Limit',
        'X-RateLimit-Remaining',
        'X-RateLimit-Reset'
      )
    end
  end

  describe 'check_in/ip' do
    let(:data) { { data: 'foo', status: 200 } }

    context 'when more than 10 requests' do
      context 'when GET endpoint' do
        before do
          allow_any_instance_of(CheckIn::V2::Session).to receive(:authorized?).and_return(true)
          allow_any_instance_of(V2::Lorota::Service).to receive(:check_in_data).and_return(data)
          allow_any_instance_of(V2::Chip::Service).to receive(:set_echeckin_started).and_return(data)

          10.times do
            get('/check_in/v2/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d', headers:)

            expect(last_response).to have_http_status(:ok)
          end
        end

        it 'throttles with status 429' do
          get('/check_in/v2/patient_check_ins/d602d9eb-9a31-484f-9637-13ab0b507e0d', headers:)

          expect(last_response).to have_http_status(:too_many_requests)
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

            expect(last_response).to have_http_status(:ok)
          end
        end

        it 'throttles with status 429' do
          post '/check_in/v2/patient_check_ins', post_params, headers

          expect(last_response).to have_http_status(:too_many_requests)
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

          expect(last_response).to have_http_status(:unauthorized)
        end
      end

      it 'throttles with status 429' do
        get('/v0/medical_copays', headers:)

        expect(last_response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'facilities_api/v2/va/ip' do
    let(:endpoint) { '/facilities_api/v2/va' }
    let(:headers) { { 'X-Real-Ip' => '1.2.3.4' } }
    let(:limit) { 30 }

    before do
      limit.times do
        post endpoint, nil, headers
        expect(last_response).not_to have_http_status(:too_many_requests)
      end

      post endpoint, nil, other_headers
    end

    context 'response status for repeated requests from the same IP' do
      let(:other_headers) { headers }

      it 'limits requests' do
        expect(last_response).to have_http_status(:too_many_requests)
      end
    end

    context 'response status for request from different IP' do
      let(:other_headers) { { 'X-Real-Ip' => '4.3.2.1' } }

      it 'does not limit request' do
        expect(last_response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'facilities_api/v2/ccp/ip' do
    let(:endpoint) { '/facilities_api/v2/ccp/provider' }
    let(:headers) { { 'X-Real-Ip' => '1.2.3.4' } }
    let(:limit) { 8 }

    before do
      limit.times do
        get endpoint, nil, headers
        expect(last_response).not_to have_http_status(:too_many_requests)
      end

      get endpoint, nil, other_headers
    end

    context 'response status for repeated requests from the same IP' do
      let(:other_headers) { headers }

      it 'limits requests' do
        expect(last_response).to have_http_status(:too_many_requests)
      end
    end

    context 'response status for request from different IP' do
      let(:other_headers) { { 'X-Real-Ip' => '4.3.2.1' } }

      it 'limits requests' do
        expect(last_response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'ask_va_api/zip_state_validation' do
    let(:endpoint) { '/ask_va_api/v0/zip_state_validation' }
    let(:headers) { { 'X-Real-Ip' => '1.2.3.4' } }
    let(:params) { { zip_code: '12345', state_code: 'VA' } }
    let(:limit) { 60 }

    before do
      allow(Settings).to receive(:vsp_environment).and_return('production')
      allow(Flipper).to receive(:enabled?).and_call_original
      allow(Flipper).to receive(:enabled?).with(:ask_va_api_maintenance_mode).and_return(false)
      allow(AskVAApi::ZipStateValidation::ZipStateValidator).to receive(:call).and_return(
        Struct.new(:valid, :error_code, :error_message).new(true, nil, nil)
      )

      limit.times do
        post endpoint, params, headers
        expect(last_response).to have_http_status(:ok)
      end
    end

    it 'throttles with status 429' do
      post endpoint, params, headers

      expect(last_response).to have_http_status(:too_many_requests)
    end

    it 'does not throttle a different IP' do
      other_headers = { 'X-Real-Ip' => '4.3.2.1' }

      post endpoint, params, other_headers

      expect(last_response).to have_http_status(:ok)
    end
  end

  describe 'education_benefits_claims/v0/ip' do
    let(:endpoint) { '/v0/education_benefits_claims/1995' }
    let(:headers) { { 'X-Real-Ip' => '1.2.3.4' } }
    let(:limit) { 15 }

    before do
      limit.times do
        post endpoint, nil, headers
        expect(last_response).not_to have_http_status(:too_many_requests)
      end

      post endpoint, nil, other_headers
    end

    context 'response status for repeated requests from the same IP' do
      let(:other_headers) { headers }

      it 'limits requests' do
        expect(last_response).to have_http_status(:too_many_requests)
      end
    end

    context 'response status for request from different IP' do
      let(:other_headers) { { 'X-Real-Ip' => '4.3.2.1' } }

      it 'limits requests' do
        expect(last_response).not_to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'vic rate-limits', run_at: 'Thu, 26 Dec 2015 15:54:20 GMT' do
    before do
      limit.times do
        post(endpoint, headers:)
        expect(last_response).not_to have_http_status(:too_many_requests)
      end

      post endpoint, headers:
    end

    context 'profile photo upload' do
      let(:limit) { 8 }
      let(:endpoint) { '/v0/vic/profile_photo_attachments' }

      it 'limits requests' do
        expect(last_response).to have_http_status(:too_many_requests)
      end
    end

    context 'supporting doc upload' do
      let(:limit) { 8 }
      let(:endpoint) { '/v0/vic/supporting_documentation_attachments' }

      it 'limits requests' do
        expect(last_response).to have_http_status(:too_many_requests)
      end
    end

    context 'form submission' do
      let(:limit) { 10 }
      let(:endpoint) { '/v0/vic/vic_submissions' }

      it 'limits requests' do
        expect(last_response).to have_http_status(:too_many_requests)
      end
    end
  end

  describe 'appointments' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/appointments', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/appointments', headers:)).to have_http_status(:too_many_requests)
        end
      end

      context 'when POST endpoint' do
        let(:post_params) do
          { appt: { id: '12345' } }
        end

        before do
          30.times do
            expect(post('/vaos/v2/appointments', post_params:, headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(post('/vaos/v2/appointments', post_params:, headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'clinics' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/locations/983/clinics?clinic_ids=570,945',
                       headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/locations/983/clinics?clinic_ids=570,945',
                     headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'providers' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/providers/12345', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/providers/12345', headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'patients' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/eligibility', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/eligibility', headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'cc_eligibility' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/community_care/eligibility/PrimaryCare', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/community_care/eligibility/PrimaryCare',
                     headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'scheduling_configurations' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/scheduling/configurations', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/scheduling/configurations', headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'facilities' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/facilities', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/facilities', headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'relationships' do
    context 'when more than 30 requests' do
      context 'when GET endpoint' do
        before do
          30.times do
            expect(get('/vaos/v2/relationships', headers:)).to have_http_status(:unauthorized)
          end
        end

        it 'throttles with status 429' do
          expect(get('/vaos/v2/relationships', headers:)).to have_http_status(:too_many_requests)
        end
      end
    end
  end

  describe 'BIO form endpoints (form214192, form21p530a, form210779, form212680)' do
    let(:headers) { { 'X-Real-Ip' => '1.2.3.4' } }
    let(:limit) { 30 }

    %w[
      /v0/form214192
      /v0/form21p530a
      /v0/form210779
      /v0/form212680
    ].each do |endpoint|
      context "when POST #{endpoint}" do
        before do
          limit.times do
            post endpoint, { form_data: '{}' }.to_json, headers.merge('CONTENT_TYPE' => 'application/json')
            expect(last_response).not_to have_http_status(:too_many_requests)
          end

          post endpoint, { form_data: '{}' }.to_json, other_headers.merge('CONTENT_TYPE' => 'application/json')
        end

        context 'response status for repeated requests from the same IP' do
          let(:other_headers) { headers }

          it 'throttles with status 429' do
            expect(last_response).to have_http_status(:too_many_requests)
          end
        end

        context 'response status for request from different IP' do
          let(:other_headers) { { 'X-Real-Ip' => '4.3.2.1' } }

          it 'does not throttle' do
            expect(last_response).not_to have_http_status(:too_many_requests)
          end
        end
      end
    end
  end
end
