# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/benefit_claim_service'

describe ClaimsApi::BenefitClaimService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe '#update_benefit_claim' do
    let(:options) do
      {
        file_number: '796163671',
        payee_code: '10',
        date_of_claim: '03/01/2013',
        claimant_ssn: '796163672',
        power_of_attorney: '002',
        benefit_claim_type: '2',
        old_end_product_code: '691',
        new_end_product_label: '690AUTRWPMC',
        old_date_of_claim: '03/01/2013'
      }
    end

    it 'updates a benefit claim' do
      VCR.use_cassette('claims_api/bgs/benefit_claim_service/update_benefit_claim') do
        result = subject.update_benefit_claim(options)

        expect(result).to be_a Hash
        expect(result[:return][:return_message]).to eq 'Update to Corporate was successful'
      end
    end
  end
end
