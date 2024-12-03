# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'

describe ClaimsApi::EbenefitsBnftClaimStatusWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }

  # Testing potential ways the current check could be tricked
  describe '#all' do
    let(:subject_instance) { subject }
    let(:id) { 12_343 }
    let(:error_message) { { error: 'Did not work', code: 'XXX' } }
    let(:bgs_unknown_error_message) { { error: 'Unexpected error' } }
    let(:empty_array) { [] }

    context 'when an error message gets returned it still does not pass the count check' do
      it 'returns an empty array' do
        expect(error_message.count).to eq(2) # trick the claims count check
        # error message should trigger return
        allow(subject_instance).to receive(:find_benefit_claims_status_by_ptcpnt_id).with(id).and_return(error_message)
        expect(subject.all(id)).to eq([]) # verify correct return
      end
    end

    context 'when claims come back as a hash instead of an array' do
      it 'casts the hash as an array' do
        VCR.use_cassette('claims_api/bgs/claims/claims_trimmed_down') do
          claims = subject_instance.find_benefit_claims_status_by_ptcpnt_id('600061742')
          claims[:benefit_claims_dto][:benefit_claim] = claims[:benefit_claims_dto][:benefit_claim][0]
          allow(subject_instance).to receive(:find_benefit_claims_status_by_ptcpnt_id).with(id).and_return(claims)

          begin
            ret = subject_instance.send(:transform_bgs_claims_to_evss, claims)
            expect(ret.class).to_be Array
            expect(ret.size).to eq 1
          rescue => e
            expect(e.message).not_to include 'no implicit conversion of Array into Hash'
          end
        end
      end
    end

    # Already being checked but based on an error seen just want to lock this in to ensure nothing gets missed
    context 'when an empty array gets returned it still does not pass the count check' do
      it 'returns an empty array' do
        # error message should trigger return
        allow(subject_instance).to receive(:find_benefit_claims_status_by_ptcpnt_id).with(id).and_return(empty_array)
        expect(subject.all(id)).to eq([]) # verify correct return
      end
    end
  end
end
