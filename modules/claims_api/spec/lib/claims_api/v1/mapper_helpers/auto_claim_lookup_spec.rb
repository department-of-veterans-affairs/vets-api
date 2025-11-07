# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/v1/mapper_helpers/auto_claim_lookup'

describe ClaimsApi::V1::AutoClaimLookup do
  let(:mock_pdf_mapper) do
    Class.new do
      include ClaimsApi::V1::AutoClaimLookup

      def initialize(auto_claim = {})
        @auto_claim = auto_claim
      end
    end
  end

  let(:auto_claim) do
    {
      'veteran' => {
        'currentMailingAddress' => {
          'city' => 'Portland',
          'state' => 'OR'
        },
        'currentlyVAEmployee' => false
      },
      'serviceInformation' => {
        'reservesNationalGuardService' => {
          'unitName' => 'Test Unit'
        }
      }
    }
  end

  let(:instance) { mock_pdf_mapper.new(auto_claim) }

  describe '#lookup_in_auto_claim' do
    it 'looks up boolean values correctly' do
      result = instance.lookup_in_auto_claim(:veteran_current_va_employee)

      expect(result).to be(false)
    end

    it 'looks up nested information correctly' do
      result = instance.lookup_in_auto_claim(:veteran_current_mailing_address)

      expect(result).to eq({ 'city' => 'Portland', 'state' => 'OR' })
    end
  end
end
