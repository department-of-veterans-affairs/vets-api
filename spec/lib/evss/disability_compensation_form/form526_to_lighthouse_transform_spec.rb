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

    it 'calls evss_claims_process_type with the provided EVSS data' do
      data = JSON.parse(evss_data.to_json)
      expect(transformer).to receive(:evss_claims_process_type)
        .with(data['form526'])
        .and_return('STANDARD_CLAIM_PROCESS')
      transformer.transform(data)
    end
  end

  describe '#evss_claims_process_type' do
    let(:evss_data) { { form526: {} } }

    it 'returns "STANDARD_CLAIM_PROCESS"' do
      data = JSON.parse(evss_data.to_json)
      result = transformer.evss_claims_process_type(data)
      expect(result).to eq('STANDARD_CLAIM_PROCESS')
    end
  end
end
