# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form526_to_lighthouse_transform'

RSpec.describe EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform do
  let(:transformer) { EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new }

  describe '#transform' do
    let(:evss_data) { { form526: {} } }

    it 'sets claimant_certification to true in the Lighthouse request body' do
      data = JSON.parse(evss_data.to_json)
      lh_request_body = transformer.transform(data)
      expect(lh_request_body.claimant_certification).to be(true)
    end

    context 'when claim_date is provided' do
      let(:claim_date) { Date.new(2023, 7, 19) }

      it 'sets claim_date in the Lighthouse request body' do
        evss_data[:form526][:claim_date] = claim_date
        data = JSON.parse(evss_data.to_json)
        lh_request_body = transformer.transform(data)
        expect(lh_request_body.claim_date).to eq(claim_date)
      end
    end

    it 'verify the LH request body is being populated correctly by default' do
      data = JSON.parse(evss_data.to_json)
      expect(transformer).to receive(:evss_claims_process_type)
        .with(data['form526'])
        .and_return('STANDARD_CLAIM_PROCESS')
      result = transformer.transform(data)

      expect(result.claim_date).to eq(nil)
      expect(result.claimant_certification).to eq(true)
      expect(result.claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
    end
  end

  describe '#evss_claims_process_type' do
    let(:evss_data) { { form526: {} } }

    it 'returns "FDC_PROGRAM" by default' do
      data = JSON.parse(evss_data.to_json)
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('FDC_PROGRAM')
    end

    it 'sets claimsProcessType to STANDARD_CLAIM_PROCESS in the Lighthouse request body' do
      evss_data[:form526][:standardClaim] = true
      data = JSON.parse(evss_data.to_json)
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('STANDARD_CLAIM_PROCESS')
    end

    it 'sets claimsProcessType to BDD_PROGRAM in the Lighthouse request body' do
      evss_data[:form526][:bddQualified] = true
      data = JSON.parse(evss_data.to_json)
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('BDD_PROGRAM')
    end

    it 'sets claimsProcessType to BDD_PROGRAM in the Lighthouse request body, even if standardClaim is also true' do
      evss_data[:form526][:bddQualified] = true
      evss_data[:form526][:standardClaim] = true
      data = JSON.parse(evss_data.to_json)
      result = transformer.evss_claims_process_type(data['form526'])
      expect(result).to eq('BDD_PROGRAM')
    end
  end
end
