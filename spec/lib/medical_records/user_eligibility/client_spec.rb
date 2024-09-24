# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/user_eligibility/client'

describe UserEligibility::Client do
  describe 'User eligibility operations', :vcr do
    context 'when user ID and ICN are valid' do
      let(:icn) { '1000000000V000000' }
      let(:user_id) { '10000000' }
      let(:client) { UserEligibility::Client.new(user_id, icn) }
      let(:expected_response_message) { 'MHV Premium SM account with Logins in past 26 months' }

      it 'performs an eligibility check on the user', :vcr do
        VCR.use_cassette 'user_eligibility_client/perform_an_eligibility_check' do
          response = client.get_is_valid_sm_user
          expect(response['accountStatus']).to include(expected_response_message)
        end
      end
    end

    context 'when user ID is nil' do
      let(:user_id) { nil }
      let(:icn) { '1000000000V000000' }
      let(:client) { UserEligibility::Client.new(user_id, icn) }

      it 'raises an error', :vcr do
        expect { client.get_is_valid_sm_user }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when ICN is nil' do
      let(:user_id) { '10000000' }
      let(:icn) { nil }
      let(:client) { UserEligibility::Client.new(user_id, icn) }

      it 'raises an error', :vcr do
        expect { client.get_is_valid_sm_user }.to raise_error(Common::Exceptions::ParameterMissing)
      end
    end

    context 'when ICN is not properly formatted' do
      let(:user_id) { '10000000' }
      let(:icn) { '12345' }
      let(:client) { UserEligibility::Client.new(user_id, icn) }

      it 'raises an error', :vcr do
        VCR.use_cassette 'user_eligibility_client/perform_an_eligibility_check_with_bad_icn' do
          expect do
            client.get_is_valid_sm_user
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    # context 'when patient is not eligible' do
    #   let(:user_id) { '10000000' }
    #   let(:icn) { '1000000000V000000' }
    #   let(:client) { UserEligibility::Client.new(user_id, icn) }
    #   let(:expected_response_message) { 'MHV Premium SM account with Logins in past 26 months' }

    #   it 'performs an eligibility check on the user', :vcr do
    #     VCR.use_cassette 'user_eligibility_client/perform_an_eligibility_check_on_a_patient_who_is_not_eligible' do
    #       response = client.get_is_valid_sm_user
    #       expect(response['accountStatus']).to include(expected_response_message)
    #     end
    #   end
    # end
  end
end
