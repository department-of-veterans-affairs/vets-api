# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/disability_compensation_fes_mapper'

describe ClaimsApi::V1::DisabilityCompensationFesMapper do
  describe '526 claim maps to FES format' do
    context 'with v1 form data' do
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
               auth_headers: { 'va_eauth_pid' => '600061742',
                               'va_eauth_service_transaction_id' => '00000000-0000-0000-0000-000000000000' })
      end
      let(:fes_data) do
        ClaimsApi::V1::DisabilityCompensationFesMapper.new(auto_claim).map_claim
      end

      context 'request structure' do
        it 'wraps data in proper FES request structure' do
          expect(fes_data).to have_key(:data)
          expect(fes_data[:data]).to have_key(:serviceTransactionId)
          expect(fes_data[:data]).to have_key(:claimantParticipantId)
          expect(fes_data[:data]).to have_key(:form526)
        end
      end
    end
  end
end
