# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::ProvidersController, type: :request do
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:provider_id) { 'test-provider-id' }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'GET `show`' do
    context 'when called without authorization' do
      let(:resp) do
        {
          'errors' => [
            {
              'title' => 'Not authorized',
              'detail' => 'Not authorized',
              'code' => '401',
              'status' => '401'
            }
          ]
        }
      end

      it 'throws unauthorized exception' do
        get "/vaos/v2/providers/#{provider_id}"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when called with valid provider_id' do
      let(:test_token) do
        {
          token_type: 'Bearer',
          expires_in: 900,
          access_token: 'test-token',
          scope: 'test-scope'
        }
      end

      let(:test_provider) do
        {
          'id' => provider_id,
          'name' => 'Timothy Bob',
          'isActive' => true,
          'individualProviders' => [
            {
              'name' => 'Timothy Bob',
              'npi' => 'test-npi'
            }
          ],
          'providerOrganization' => {
            'name' => 'test-provider-org-name'
          },
          'location' => {
            'name' => 'Test Medical Complex',
            'address' => '207 Davishill Ln',
            'latitude' => 33.058736,
            'longitude' => -80.032819,
            'timezone' => 'America/New_York'
          },
          'networkIds' => [
            'sandbox-network-test'
          ],
          'schedulingNotes' => 'New patients need to send their previous records to the office prior to their appt.',
          'appointmentTypes' => [
            {
              'id' => 'off',
              'name' => 'Office Visit',
              'isSelfSchedulable' => true
            }
          ],
          'specialties' => [
            {
              'id' => 'test-id',
              'name' => 'Urology'
            }
          ],
          'visitMode' => 'phone'
        }
      end
      let(:resp) { { 'data' => { 'id' => provider_id, 'type' => 'providers', 'attributes' => test_provider } } }

      before do
        sign_in_as(create(:user, :loa3))
      end

      it 'returns the provider information' do
        VCR.use_cassette('vaos/eps/providers/data_200', match_requests_on: %i[method path],
                                                        erb: { provider_id: }) do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            get "/vaos/v2/providers/#{provider_id}", headers: inflection_header
          end
        end

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(resp)
      end
    end

    context 'when eps api called with invalid token' do
      let(:unauth_failure_message) do
        {
          'title' => 'Operation failed',
          'detail' => 'Operation failed',
          'code' => 'VA900',
          'source' => {
            'vamf_url' => "https://api.wellhive.com/care-navigation/v1/provider-services/#{provider_id}",
            'vamf_body' => "{\n  \"name\": \"Unauthorized\"\n}",
            'vamf_status' => 401
          },
          'status' => '400'
        }
      end
      let(:error_resp) { { 'errors' => [unauth_failure_message] } }

      before do
        sign_in_as(create(:user, :loa3))
      end

      it 'returns 400 bad request' do
        VCR.use_cassette('vaos/eps/providers/data_401', match_requests_on: %i[method path],
                                                        erb: { provider_id: }) do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            get "/vaos/v2/providers/#{provider_id}"
          end
        end

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq(error_resp)
      end
    end

    context 'when eps api returns internal service exception' do
      let(:bad_gateway_msg) do
        {
          'title' => 'Bad Gateway',
          'detail' => 'Received an an invalid response from the upstream server',
          'code' => 'VAOS_502',
          'source' => {
            'vamf_url' => "https://api.wellhive.com/care-navigation/v1/provider-services/#{provider_id}",
            'vamf_body' => "{\n  \"error\": \"Internal Service Exception\"\n}",
            'vamf_status' => 500
          },
          'status' => '502'
        }
      end
      let(:error_resp) { { 'errors' => [bad_gateway_msg] } }

      before do
        sign_in_as(create(:user, :loa3))
      end

      it 'returns 502 bad gateway' do
        VCR.use_cassette('vaos/eps/providers/data_500', match_requests_on: %i[method path],
                                                        erb: { provider_id: }) do
          VCR.use_cassette('vaos/eps/token/token_200', match_requests_on: %i[method path]) do
            get "/vaos/v2/providers/#{provider_id}"
          end
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(JSON.parse(response.body)).to eq(error_resp)
      end
    end
  end
end
