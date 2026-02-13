# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Spouse do
  let(:veteran_spouse_v2) { build(:spouse_v2) }
  let(:spouse_v2) { described_class.new(veteran_spouse_v2['dependents_application']) }
  let(:format_info_output) do
    {
      'ssn' => '323454323',
      'birth_date' => '1981-04-04',
      'ever_married_ind' => 'Y',
      'martl_status_type_cd' => 'Married',
      'vet_ind' => 'Y',
      'first' => 'Jenny',
      'middle' => 'Lauren',
      'last' => 'McCarthy',
      'suffix' => 'Sr.',
      'va_file_number' => '00000000'
    }
  end
  let(:address_output_v2) do
    {
      'country' => 'USA',
      'street' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state' => 'CA',
      'postal_code' => '21122'
    }
  end

  describe '#format_info' do
    it 'formats relationship params for submission' do
      formatted_info = spouse_v2.format_info

      expect(formatted_info).to include(format_info_output)
    end
  end

  describe '#address' do
    it 'returns an address for vet or spouse if separated' do
      address = spouse_v2.address

      expect(address).to eq(address_output_v2)
    end
  end
end
