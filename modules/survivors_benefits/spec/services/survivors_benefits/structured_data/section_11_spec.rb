# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/structured_data/section_11'

RSpec.describe SurvivorsBenefits::StructuredData::Section11 do
  describe '#build_section11' do
    it 'merges the correct banking info fields' do
      account = {
        'bankName' => 'Bank of America',
        'routingNumber' => '123456789',
        'accountType' => 'CHECKING',
        'accountNumber' => '987654321'
      }
      service = SurvivorsBenefits::StructuredData::StructuredDataService.new({})
      service.build_section11(account)
      expect(service.fields).to include(
        'NAME_FINANCIAL_INSTITUTE' => 'Bank of America',
        'ROUTING_TRANSIT_NUMBER' => '123456789',
        'CHECKING_ACCOUNT_CB' => true,
        'SAVINGS_ACCOUNT_CB' => false,
        'NO_ACCOUNT_CB' => false,
        'AccountNumber' => '987654321'
      )
    end
  end
end
