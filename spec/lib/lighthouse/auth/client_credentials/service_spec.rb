# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/auth/client_credentials/service'

RSpec.describe Auth::ClientCredentials::Service do
  let(:url) { 'https://sandbox-api.va.gov/oauth2/api/system/v1/token' }
  let(:client_id) { '1234567890' }
  let(:api_scopes) { %w[api.read api.write] }
  let(:aud_claim_url) { 'https://deptva-eval.okta.com/oauth2/1234567890/v1/token' }
  let(:key_location) { 'spec/support/certificates/lhdd-fake-private.pem' }

  before do
    t = Time.zone.local(2022, 1, 30, 10, 0, 0)
    Timecop.freeze(t)
  end

  describe 'get access_token from Lighthouse API' do
    context 'when successful' do
      it 'returns a status of 200' do
        service = Auth::ClientCredentials::Service.new(url, api_scopes, client_id, aud_claim_url, key_location)

        VCR.use_cassette('lighthouse/auth/client_credentials/token_200') do
          access_token = service.get_token
          expect(access_token).not_to be_nil
        end
      end
    end

    context 'when invalid client_id provided' do
      it 'returns a 400' do
        service = Auth::ClientCredentials::Service.new(url, api_scopes, '', aud_claim_url, key_location)

        VCR.use_cassette('lighthouse/auth/client_credentials/invalid_client_id_400') do
          expect { service.get_token }.to raise_error do |error|
            expect(error).to be_a(Faraday::ClientError)
            expect(error.response[:status]).to eq(400)
            expect(error.response[:body]['error']).to eq('invalid_client')
            expect(error.response[:body]['error_description']).to eq('A client_id must be provided in the request.')
          end
        end
      end
    end

    context 'when invalid aud_claim_id provided' do
      it 'returns a 401' do
        error_message = 'The audience claim for client_assertion must be the endpoint invoked for the request.'
        service = Auth::ClientCredentials::Service.new(url, api_scopes, client_id, '', key_location)

        VCR.use_cassette('lighthouse/auth/client_credentials/invalid_assertion_401') do
          expect { service.get_token }.to raise_error do |error|
            expect(error).to be_a(Faraday::ClientError)
            expect(error.response[:status]).to eq(401)
            expect(error.response[:body]['error']).to eq('invalid_client')
            expect(error.response[:body]['error_description']).to eq(error_message)
          end
        end
      end
    end

    context 'when invalid scopes are provided' do
      it 'returns a 400' do
        fake_scopes = %w[direct.deposit.fake direct.deposit.write]
        error_message = 'One or more scopes are not configured for the authorization server resource.'
        service = Auth::ClientCredentials::Service.new(url, fake_scopes, client_id, aud_claim_url, key_location)

        VCR.use_cassette('lighthouse/auth/client_credentials/invalid_scopes_400') do
          expect { service.get_token }.to raise_error do |error|
            expect(error).to be_a(Faraday::ClientError)
            expect(error.response[:status]).to eq(400)
            expect(error.response[:body]['error']).to eq('invalid_scope')
            expect(error.response[:body]['error_description']).to eq(error_message)
          end
        end
      end
    end
  end
end
