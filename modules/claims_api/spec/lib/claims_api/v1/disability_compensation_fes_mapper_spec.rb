# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/disability_compensation_fes_mapper'

describe ClaimsApi::V1::DisabilityCompensationFesMapper do
  let(:veteran_participant_id) { '600049324' }
  let(:transaction_id) { 'vagov-8a1be4b0' }
  let(:auth_headers) do
    {
      'va_eauth_csid' => 'DSLogon', 'va_eauth_authenticationmethod' => 'DSLogon',
      'va_eauth_pnidtype' => 'SSN', 'va_eauth_assurancelevel' => '3', 'va_eauth_firstName' => 'Janet',
      'va_eauth_lastName' => 'Moore', 'va_eauth_issueinstant' => '2025-08-26T21:43:33Z',
      'va_eauth_dodedipnid' => '1005396162', 'va_eauth_birlsfilenumber' => '123456',
      'va_eauth_pid' => veteran_participant_id.to_s, 'va_eauth_pnid' => '796127677',
      'va_eauth_birthdate' => '1949-05-06T00:00:00+00:00',
      'va_eauth_authorization' => '{Does not matter here}', 'va_eauth_authenticationauthority' => 'eauth',
      'va_eauth_service_transaction_id' => transaction_id.to_s
    }
  end
  let(:form_data) do
    JSON.parse(
      Rails.root.join(
        'modules',
        'claims_api',
        'spec',
        'fixtures',
        'form_526_json_api.json'
      ).read
    )
  end
  let(:auto_claim) do
    create(:auto_established_claim,
           form_data: form_data['data']['attributes'],
           auth_headers:)
  end

  let(:fes_data) do
    ClaimsApi::V1::DisabilityCompensationFesMapper.new(auto_claim).map_claim
  end

  context 'request structure' do
    it 'wraps data in proper FES request structure' do
      expect(fes_data).to have_key(:data)
      expect(fes_data[:data][:serviceTransactionId]).to eq(transaction_id)
      expect(fes_data[:data][:claimantParticipantId]).to eq(veteran_participant_id)
      expect(fes_data[:data][:veteranParticipantId]).to eq(veteran_participant_id)
      expect(fes_data[:data]).to have_key(:form526)
    end

    context 'with errors' do
      it 'returns an error if the veteranParticipantId is not present' do
        headers = auto_claim.auth_headers
        headers['va_eauth_pid'] = nil

        expect do
          ClaimsApi::V1::DisabilityCompensationFesMapper.new(auto_claim).map_claim
        end.to raise_error(ArgumentError, 'Missing veteranParticipantId - ' \
                                          'auth_headers do not contain valid participant ID')
      end

      it 'returns an error if the serviceTransactionId is not present' do
        headers = auto_claim.auth_headers
        headers['va_eauth_service_transaction_id'] = nil

        expect do
          ClaimsApi::V1::DisabilityCompensationFesMapper.new(auto_claim).map_claim
        end.to raise_error(ArgumentError, 'Missing serviceTransactionId - ' \
                                          'auth_headers do not contain valid service transaction ID')
      end
    end
  end
end
