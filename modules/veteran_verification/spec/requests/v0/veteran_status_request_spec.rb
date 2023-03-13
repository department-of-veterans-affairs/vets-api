# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Status API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:scopes) { %w[profile email openid veteran_status.read] }

  context 'mock emis' do
    before do
      allow(Settings.vet_verification).to receive(:mock_emis).and_return(true)
      allow(Settings.vet_verification).to receive(:mock_emis_host).and_return('https://vaausvrsapp81.aac.va.gov')
    end

    context 'with valid emis responses' do
      it 'returns true if the user is a veteran' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_veteran_status/valid') do
            get '/services/veteran_verification/v0/status', params: nil, headers: auth_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['veteran_status']).to eq('confirmed')
          end
        end
      end

      it 'returns not_confirmed if the user is not a veteran' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_veteran_status/valid_non_veteran') do
            get '/services/veteran_verification/v0/status', params: nil, headers: auth_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['veteran_status']).to eq('not confirmed')
          end
        end
      end
    end

    context 'when emis response is invalid' do
      before do
        allow(EMISRedis::MilitaryInformationV2).to receive(:for_user).and_return(nil)
      end

      it 'matches the errors schema', :aggregate_failures do
        with_okta_user(scopes) do |auth_header|
          get '/services/veteran_verification/v0/status', params: nil, headers: auth_header

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
          expect(JSON.parse(response.body)['errors'].first['code']).to eq 'EMIS_STATUS502'
        end
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        with_okta_user(scopes) do |auth_header|
          get '/services/veteran_verification/v0/status',
              params: nil,
              headers: auth_header.merge('X-Key-Inflection' => 'camel')

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('errors')
          expect(JSON.parse(response.body)['errors'].first['code']).to eq 'EMIS_STATUS502'
        end
      end
    end
  end

  context 'betamocks emis' do
    before do
      allow(Settings.vet_verification).to receive(:mock_emis).and_return(false)
    end

    context 'with valid emis responses' do
      it 'returns true if the user is a veteran' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_veteran_status/valid') do
            get '/services/veteran_verification/v0/status', params: nil, headers: auth_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['veteran_status']).to eq('confirmed')
          end
        end
      end

      it 'returns not_confirmed if the user is not a veteran' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_veteran_status/valid_non_veteran') do
            get '/services/veteran_verification/v0/status', params: nil, headers: auth_header
            expect(response).to have_http_status(:ok)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['data']['attributes']['veteran_status']).to eq('not confirmed')
          end
        end
      end
    end

    context 'when emis response is invalid' do
      before do
        allow(EMISRedis::MilitaryInformation).to receive(:for_user).and_return(nil)
      end

      it 'matches the errors schema', :aggregate_failures do
        with_okta_user(scopes) do |auth_header|
          get '/services/veteran_verification/v0/status', params: nil, headers: auth_header

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
          expect(JSON.parse(response.body)['errors'].first['code']).to eq 'EMIS_STATUS502'
        end
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        with_okta_user(scopes) do |auth_header|
          get '/services/veteran_verification/v0/status',
              params: nil,
              headers: auth_header.merge('X-Key-Inflection' => 'camel')

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('errors')
          expect(JSON.parse(response.body)['errors'].first['code']).to eq 'EMIS_STATUS502'
        end
      end
    end
  end
end
