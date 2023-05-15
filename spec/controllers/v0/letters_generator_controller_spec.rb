# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/letters_generator/service_error'

RSpec.describe V0::LettersGeneratorController, type: :controller do
  # These users are from Lighthouse API sandbox
  # https://github.com/department-of-veterans-affairs/vets-api-clients/blob/master/test_accounts/letter_generator_test_accounts.md
  let(:user) { build(:user, :loa3, icn: '1012666073V986297') }
  let(:user_error) { build(:user, :loa3, icn: '1012667145V762142') }

  before do
    token = 'abcdefghijklmnop'

    allow_any_instance_of(Lighthouse::LettersGenerator::Configuration).to receive(:get_access_token).and_return(token)
  end

  describe '#index' do
    before { sign_in_as(user) }

    it 'lists letters available to the user' do
      VCR.use_cassette('lighthouse/letters_generator/index') do
        get(:index)

        letters_response = JSON.parse(response.body)
        expected_important_key = 'letters'
        expect(letters_response).to include(expected_important_key)
      end
    end
  end

  describe '#download' do
    context 'without options' do
      before { sign_in_as(user) }

      it 'returns a pdf' do
        VCR.use_cassette('lighthouse/letters_generator/download') do
          get :download, params: { id: 'BENEFIT_SUMMARY' }

          expect(response.header['Content-Type']).to eq('application/pdf')
        end
      end
    end

    context 'with options' do
      before { sign_in_as(user) }

      it 'returns a pdf' do
        VCR.use_cassette('lighthouse/letters_generator/download_with_options') do
          get :download, params: {
            id: 'BENEFIT_SUMMARY',
            militaryService: 'true',
            serviceConnectedDisabilities: 'true'
          }
          expect(response.header['Content-Type']).to eq('application/pdf')
        end
      end
    end

    context 'when an error occurs' do
      before { sign_in_as(user_error) }

      it 'raises Lighthouse::LettersGenerator::ServiceError' do
        VCR.use_cassette('lighthouse/letters_generator/download_error') do
          get :download, params: { id: 'BENEFIT_SUMMARY' }
          response_body = JSON.parse(response.body)
          expect(response_body['errors'].first).to include('status' => '422')
        end
      end
    end
  end

  describe '#beneficiary' do
    context 'without error' do
      before { sign_in_as(user) }

      it 'returns beneficiary data' do
        VCR.use_cassette('lighthouse/letters_generator/beneficiary') do
          get(:beneficiary)

          beneficiary_response = JSON.parse(response.body)
          expected_important_key = 'benefitInformation'
          expect(beneficiary_response).to include(expected_important_key)
        end
      end
    end
  end
end
