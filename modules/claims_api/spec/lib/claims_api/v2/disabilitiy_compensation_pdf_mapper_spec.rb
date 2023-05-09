# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v2/disability_compensation_pdf_mapper'

describe ClaimsApi::V2::DisabilitiyCompensationPdfMapper do
  describe '526 claim maps to the pdf generator' do
    let(:pdf_data) do
      {
        data: {
          attributes:
            {
              claimProcessType: '',
              claimCertificationAndSignature: {
                dateSigned: ''
              }
            }
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
          'v2',
          'veterans',
          'disability_compensation',
          'form_526_json_api.json'
        ).read
      )
    end

    context '526 section 0, happy path' do
      let(:form_attributes) { auto_claim.dig('data', 'attributes') || {} }
      let(:mapper) { ClaimsApi::V2::DisabilitiyCompensationPdfMapper.new(form_attributes, pdf_data) }

      it 'maps the claim date' do
        mapper.map_claim
        attribute = pdf_data[:data][:attributes][:claimCertificationAndSignature][:dateSigned]
        expect(attribute).to eq('2023-02-18')
      end

      it 'maps the claim process type' do
        mapper.map_claim
        attribute = pdf_data[:data][:attributes][:claimProcessType]
        expect(attribute).to eq('STANDARD_CLAIM_PROCESS')
      end
    end
  end
end
