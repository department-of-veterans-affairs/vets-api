# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_12'

RSpec.describe SurvivorsBenefits::StructuredData::Section12 do
  describe '#build_section12' do
    it 'merges the correct fields for claim certification with a signed date' do
      form = {
        'claimantSignature' => 'John Doe',
        'dateSigned' => '2024-01-01'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section12
      expect(service.fields).to include(
        'CB_FURTHER_EVD_CLAIM_SUPPORT' => false,
        'CLAIM_TYPE_FULLY_DEVELOPED_CHK' => true,
        'CLAIMANT_SIGNATURE_X' => nil,
        'CLAIMANT_SIGNATURE' => 'John Doe',
        'DATE_OF_CLAIMANT_SIGNATURE' => '01/01/2024'
      )
    end

    it 'merges the correct fields for claim certification without a signed date' do
      form = {
        'claimantSignature' => 'John Doe'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new(form)
      service.build_section12
      expect(service.fields).to include(
        'CB_FURTHER_EVD_CLAIM_SUPPORT' => false,
        'CLAIM_TYPE_FULLY_DEVELOPED_CHK' => true,
        'CLAIMANT_SIGNATURE_X' => nil,
        'CLAIMANT_SIGNATURE' => 'John Doe',
        'DATE_OF_CLAIMANT_SIGNATURE' => Date.current.strftime('%m/%d/%Y')
      )
    end
  end
end
