# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::VetVerificationStatusesController, type: :controller do
  let(:user) { create(:user, :loa3, icn: '1012667145V762142') }

  before do
    sign_in_as(user)
    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('blahblech')
    Flipper.disable(:vet_status_stage_1) # rubocop:disable Naming/VariableNumber
    Flipper.disable(:vet_status_stage_1, user) # rubocop:disable Naming/VariableNumber
  end

  describe '#show' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'returns veteran confirmation status' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
          get(:show)
        end

        parsed_body = JSON.parse(response.body)
        expect(parsed_body['data']['attributes']['veteran_status']).to eq('confirmed')
      end

      it 'removes the Veterans ICN from the response before sending' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_show_response') do
          get(:show)
        end

        parsed_body = JSON.parse(response.body)
        expect(parsed_body['data']['id']).to eq('')
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/veteran_verification/status/401_response') do
          get(:show)
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when ICN not found' do
      let(:user) { create(:user, :loa3, icn: '1012667145V762141') }

      before do
        sign_in_as(user)
        allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return('blahblech')
      end

      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)
      end

      context 'when vet_status_stage_1 is enabled' do
        before do
          Flipper.enable(:vet_status_stage_1, user) # rubocop:disable Naming/VariableNumber
        end

        it 'returns a person_not_found reason' do
          VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response') do
            get(:show)
          end

          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data']['attributes']['veteran_status']).to eq('not confirmed')
          expect(parsed_body['data']['attributes']['not_confirmed_reason']).to eq('PERSON_NOT_FOUND')
          expect(parsed_body['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_UPDATED)
          expect(parsed_body['data']['title']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE)
          expect(parsed_body['data']['status']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS)
        end
      end

      context 'when vet_status_stage_1 is disabled' do
        before do
          Flipper.disable(:vet_status_stage_1, user) # rubocop:disable Naming/VariableNumber
        end

        it 'returns a person_not_found reason' do
          VCR.use_cassette('lighthouse/veteran_verification/status/200_person_not_found_response') do
            get(:show)
          end

          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data']['attributes']['veteran_status']).to eq('not confirmed')
          expect(parsed_body['data']['attributes']['not_confirmed_reason']).to eq('PERSON_NOT_FOUND')
          expect(parsed_body['data']['message']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE)
          expect(parsed_body['data']['title']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_TITLE)
          expect(parsed_body['data']['status']).to eq(VeteranVerification::Constants::NOT_FOUND_MESSAGE_STATUS)
        end
      end
    end
  end
end
