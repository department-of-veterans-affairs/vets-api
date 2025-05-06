# frozen_string_literal: true

# require 'rails_helper'
require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::VetVerificationStatuses', type: :request do
  let!(:user) { sis_user(icn: '1012667145V762142') }

  before do
    sign_in_as(user)
    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('blahblech')
  end

  describe '#show' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
          get '/mobile/v0/vet_verification_status', headers: sis_headers
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns veteran confirmation status' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
          get '/mobile/v0/vet_verification_status', headers: sis_headers
        end

        parsed_body = JSON.parse(response.body)
        expect(parsed_body['data']['attributes']['veteranStatus']).to eq('confirmed')
      end

      it 'removes the Veterans ICN from the response before sending' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
          get '/mobile/v0/vet_verification_status', headers: sis_headers
        end

        parsed_body = JSON.parse(response.body)
        expect(parsed_body['data']['id']).to eq('')
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/veteran_verification/status/401_response') do
          get '/mobile/v0/vet_verification_status', headers: sis_headers
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when ICN not found' do
      let(:user) { sis_user(icn: '1012667145V762141') }

      before do
        sign_in_as(user)
        allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('blahblech')
      end

      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response') do
          get '/mobile/v0/vet_verification_status', headers: sis_headers
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns a person_not_found reason' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response') do
          get '/mobile/v0/vet_verification_status', headers: sis_headers
        end

        parsed_body = JSON.parse(response.body)
        expect(parsed_body['data']['attributes']['veteranStatus']).to eq('not confirmed')
        expect(parsed_body['data']['attributes']['notConfirmedReason']).to eq('PERSON_NOT_FOUND')
        expect(parsed_body['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE)
      end
    end
  end
end
