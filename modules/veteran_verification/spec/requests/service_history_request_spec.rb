# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Service History API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:scopes) { %w[profile email openid service_history.read] }

  context 'with valid emis responses' do
    it 'returns the current users service history with one episode' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('emis/get_deployment/valid') do
          VCR.use_cassette('emis/get_military_service_episodes/valid') do
            get '/services/veteran_verification/v0/service_history', params: nil, headers: auth_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(response).to match_response_schema('service_and_deployment_history_response')
          end
        end
      end
    end

    it 'returns the current users service history with multiple episodes' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('emis/get_deployment/valid') do
          VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
            get '/services/veteran_verification/v0/service_history', params: nil, headers: auth_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data'].length).to eq(2)
            expect(response).to match_response_schema('service_and_deployment_history_response')
          end
        end
      end
    end
  end

  context 'when emis response is invalid' do
    before do
      allow(EMISRedis::MilitaryInformation).to receive_message_chain(:for_user, :service_history) { nil }
    end

    it 'matches the errors schema', :aggregate_failures do
      with_okta_user(scopes) do |auth_header|
        get '/services/veteran_verification/v0/service_history', params: nil, headers: auth_header
      end

      expect(response).to have_http_status(:bad_gateway)
      expect(response).to match_response_schema('errors')
    end
  end
end
