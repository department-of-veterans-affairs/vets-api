# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/vass_settings_helper'

RSpec.describe 'Vass::V0::Appointments - Topics', type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:uuid) { 'da1e1a40-1e63-f011-bec2-001dd80351ea' }
  let(:veteran_id) { 'vet-uuid-123' }
  let(:edipi) { '1234567890' }
  let(:jwt_secret) { 'test-jwt-secret' }
  let(:jti) { SecureRandom.uuid }
  let(:jwt_token) do
    # Generate a valid JWT token for testing
    payload = {
      sub: veteran_id,
      exp: 1.hour.from_now.to_i,
      iat: Time.current.to_i,
      jti:
    }
    JWT.encode(payload, jwt_secret, 'HS256')
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Stub VASS settings
    stub_vass_settings(jwt_secret:)

    # Set up session in Redis keyed by UUID (veteran_id) with jti stored in session data
    redis_client = Vass::RedisClient.build
    redis_client.save_session(uuid: veteran_id, jti:, edipi:, veteran_id:)
  end

  describe 'GET /vass/v0/topics' do
    let(:headers) do
      {
        'Authorization' => "Bearer #{jwt_token}",
        'Content-Type' => 'application/json'
      }
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized status' do
        get '/vass/v0/topics', headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_present
      end
    end

    context 'when user is authenticated' do
      it 'returns available topics successfully' do
        allow(StatsD).to receive(:increment).and_call_original

        expect(StatsD).to receive(:increment).with(
          'api.vass.controller.appointments.topics.success',
          hash_including(tags: array_including('service:vass', 'endpoint:topics'))
        ).and_call_original

        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/agent_skills/get_agent_skills_success',
                           match_requests_on: %i[method uri]) do
            get('/vass/v0/topics', headers:)

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)

            expect(json_response['data']).to be_present
            expect(json_response['data']['topics']).to be_an(Array)
            expect(json_response['data']['topics']).not_to be_empty

            # Verify topic structure
            first_topic = json_response['data']['topics'].first
            expect(first_topic).to have_key('topicId')
            expect(first_topic).to have_key('topicName')
            expect(first_topic['topicId']).to be_present
            expect(first_topic['topicName']).to be_present
          end
        end
      end

      it 'returns empty array when no agent skills available' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/agent_skills/get_agent_skills_empty',
                           match_requests_on: %i[method uri]) do
            get('/vass/v0/topics', headers:)

            expect(response).to have_http_status(:ok)
            json_response = JSON.parse(response.body)

            expect(json_response['data']).to be_present
            expect(json_response['data']['topics']).to eq([])
          end
        end
      end

      context 'when session is missing from Redis (token revoked)' do
        before do
          redis_client = Vass::RedisClient.build
          redis_client.delete_session(uuid: veteran_id)
        end

        it 'returns unauthorized status with revoked token error' do
          get('/vass/v0/topics', headers:)

          expect(response).to have_http_status(:unauthorized)
          json_response = JSON.parse(response.body)
          expect(json_response['errors']).to be_present
          expect(json_response['errors'].first['detail']).to eq('Token is invalid or already revoked')
        end
      end

      context 'when VASS API returns an error' do
        it 'returns bad gateway status' do
          VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/agent_skills/get_agent_skills_error',
                             match_requests_on: %i[method uri]) do
              get('/vass/v0/topics', headers:)

              expect(response).to have_http_status(:bad_gateway)
              json_response = JSON.parse(response.body)
              expect(json_response['errors']).to be_present
              expect(json_response['errors'].first['code']).to eq('vass_api_error')
            end
          end
        end
      end
    end
  end
end
