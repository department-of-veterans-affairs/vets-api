# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Service History API endpoint', type: :request, skip_emis: true do
  include SchemaMatchers

  let(:scopes) { %w[profile email openid service_history.read] }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  def headers(auth)
    auth.merge('Accept' => 'application/json')
  end
  context 'Mock Emis' do
    before do
      allow(Settings.vet_verification).to receive(:mock_emis).and_return(true)
      allow(Settings.vet_verification).to receive(:mock_emis_host).and_return('https://vaausvrsapp81.aac.va.gov')
    end

    context 'with valid emis responses' do
      it 'returns the current users service history with one episode' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
                get '/services/veteran_verification/v0/service_history', params: nil, headers: headers(auth_header)
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(response).to match_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      it 'returns the current users service history with one episode when camel-inflected' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
                get '/services/veteran_verification/v0/service_history',
                    params: nil,
                    headers: headers(auth_header.merge(inflection_header))
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(response).to match_camelized_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      it 'returns the current users service history with multiple episodes' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
                get '/services/veteran_verification/v0/service_history', params: nil, headers: headers(auth_header)
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(JSON.parse(response.body)['data'].length).to eq(2)
                expect(response).to match_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      it 'returns the current users service history with multiple episodes when camel-inflected' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
                get '/services/veteran_verification/v0/service_history',
                    params: nil,
                    headers: headers(auth_header.merge(inflection_header))
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(JSON.parse(response.body)['data'].length).to eq(2)
                expect(response).to match_camelized_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      context 'with request for a jws' do
        it 'returns a jwt with the claims in the payload' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
              VCR.use_cassette('emis/get_deployment_v2/valid') do
                VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
                  get '/services/veteran_verification/v0/service_history',
                      params: nil,
                      headers: auth_header.merge('Accept' => 'application/jwt')
                  expect(response).to have_http_status(:ok)
                  expect(response.body).to be_a(String)

                  key_file = File.read("#{VeteranVerification::Engine.root}/spec/fixtures/verification_test.pem")
                  rsa_public = OpenSSL::PKey::RSA.new(key_file).public_key

                  # JWT is mocked above because it is used by the implementation code.
                  # Unfortunately, we also want to use the same module to verify the
                  # response coming back in the tests, so we reset the mock here.
                  # Otherwise, it just returns the fake JWT hash.
                  RSpec::Mocks.space.proxy_for(JWT).reset

                  claims = JWT.decode(response.body, rsa_public, true, algorithm: 'RS256').first

                  expect(claims['data'].first['type']).to eq('service_history_episodes')
                end
              end
            end
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
          get '/services/veteran_verification/v0/service_history', params: nil, headers: headers(auth_header)
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_response_schema('errors')
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        with_okta_user(scopes) do |auth_header|
          get '/services/veteran_verification/v0/service_history',
              params: nil,
              headers: headers(auth_header.merge(inflection_header))
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_camelized_response_schema('errors')
      end
    end
  end

  context 'Betamocks Emis' do
    before do
      allow(Settings.vet_verification).to receive(:mock_emis).and_return(false)
    end

    context 'with valid emis responses' do
      it 'returns the current users service history with one episode' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
                get '/services/veteran_verification/v0/service_history', params: nil, headers: headers(auth_header)
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(response).to match_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      it 'returns the current users service history with one episode when camel-inflected' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
                get '/services/veteran_verification/v0/service_history',
                    params: nil,
                    headers: headers(auth_header.merge(inflection_header))
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(response).to match_camelized_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      it 'returns the current users service history with multiple episodes' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
                get '/services/veteran_verification/v0/service_history', params: nil, headers: headers(auth_header)
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(JSON.parse(response.body)['data'].length).to eq(2)
                expect(response).to match_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      it 'returns the current users service history with multiple episodes when camel-inflected' do
        with_okta_user(scopes) do |auth_header|
          VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
            VCR.use_cassette('emis/get_deployment_v2/valid') do
              VCR.use_cassette('emis/get_military_service_episodes_v2/valid_multiple_episodes') do
                get '/services/veteran_verification/v0/service_history',
                    params: nil,
                    headers: headers(auth_header.merge(inflection_header))
                expect(response).to have_http_status(:ok)
                expect(response.body).to be_a(String)
                expect(JSON.parse(response.body)['data'].length).to eq(2)
                expect(response).to match_camelized_response_schema('service_and_deployment_history_response')
              end
            end
          end
        end
      end

      context 'with request for a jws' do
        it 'returns a jwt with the claims in the payload' do
          with_okta_user(scopes) do |auth_header|
            VCR.use_cassette('emis/get_guard_reserve_service_periods_v2/non_title_32') do
              VCR.use_cassette('emis/get_deployment_v2/valid') do
                VCR.use_cassette('emis/get_military_service_episodes_v2/valid') do
                  get '/services/veteran_verification/v0/service_history',
                      params: nil,
                      headers: auth_header.merge('Accept' => 'application/jwt')
                  expect(response).to have_http_status(:ok)
                  expect(response.body).to be_a(String)

                  key_file = File.read("#{VeteranVerification::Engine.root}/spec/fixtures/verification_test.pem")
                  rsa_public = OpenSSL::PKey::RSA.new(key_file).public_key

                  # JWT is mocked above because it is used by the implementation code.
                  # Unfortunately, we also want to use the same module to verify the
                  # response coming back in the tests, so we reset the mock here.
                  # Otherwise, it just returns the fake JWT hash.
                  RSpec::Mocks.space.proxy_for(JWT).reset

                  claims = JWT.decode(response.body, rsa_public, true, algorithm: 'RS256').first

                  expect(claims['data'].first['type']).to eq('service_history_episodes')
                end
              end
            end
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
          get '/services/veteran_verification/v0/service_history', params: nil, headers: headers(auth_header)
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_response_schema('errors')
      end

      it 'matches the errors camel-inflected schema', :aggregate_failures do
        with_okta_user(scopes) do |auth_header|
          get '/services/veteran_verification/v0/service_history',
              params: nil,
              headers: headers(auth_header.merge(inflection_header))
        end

        expect(response).to have_http_status(:bad_gateway)
        expect(response).to match_camelized_response_schema('errors')
      end
    end
  end
end
