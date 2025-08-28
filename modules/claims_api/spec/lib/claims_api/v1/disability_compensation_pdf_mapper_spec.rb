# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/disability_compensation_pdf_mapper'

describe ClaimsApi::V1::DisabilityCompensationPdfMapper do
  let(:pdf_data) do
    {
      data: {
        attributes:
          {}
      }
    }
  end
  let(:auto_claim) do
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
  let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
  let(:mapper) do
    ClaimsApi::V1::DisabilityCompensationPdfMapper.new(form_attributes, pdf_data)
  end

  context '526 section 0, claim attributes' do
    it 'set claimProcessType as STANDARD_CLAIM_PROCESS when standardClaim is true' do
      form_attributes['standardClaim'] = true
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('STANDARD_CLAIM_PROCESS')
    end

    it 'set claimProcessType as FDC_PROGRAM when standardClaim is false' do
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('FDC_PROGRAM')
    end

    it 'set claimProcessType as BDD_PROGRAM when activeDutyEndDate is between 90 -180 days in the future' do
      form_attributes['serviceInformation']['servicePeriods'][1]['activeDutyEndDate'] = 91.days.from_now
      mapper.map_claim

      claim_process_type = pdf_data[:data][:attributes][:claimProcessType]

      expect(claim_process_type).to eq('BDD_PROGRAM')
    end
  end
end
