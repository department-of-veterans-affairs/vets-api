# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BipClaims::Service do
  let(:service) { described_class.new }
  let(:claim) { build(:burial_claim) }

  describe '#veteran_attributes' do
    it 'creates valid Veteran object from form data' do
      veteran = service.veteran_attributes(claim)
      expected_result = BipClaims::Veteran.new(
        ssn: '796043735',
        first_name: 'WESLEY',
        last_name: 'FORD',
        birth_date: '1986-05-06'
      )

      expect(veteran.attributes).to eq(expected_result.attributes)
    end

    it 'raises error when passed an unsupported form ID' do
      expect { service.veteran_attributes(OpenStruct.new(form_id: 'INVALID')) }
        .to raise_error(ArgumentError)
    end
  end
end
