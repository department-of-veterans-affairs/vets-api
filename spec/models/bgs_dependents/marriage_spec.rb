# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGSDependents::Marriage do
  let(:fixtures_path) { Rails.root.join('spec', 'fixtures', '686c', 'dependents') }
  let(:veteran_spouse) do
    payload = File.read("#{fixtures_path}/spouse/spouse_is_veteran.json")
    JSON.parse(payload)
  end
  let(:marriage) { described_class.new(veteran_spouse['dependents_application']) }
  let(:format_info_output) do
    {
      'ssn' => '323454323',
      'birth_date' => '1981-04-04',
      'ever_married_ind' => 'Y',
      'martl_status_type_cd' => 'Married',
      'vet_ind' => 'Y',
      'lives_with_vet' => true,
      'alt_address' => nil,
      'first' => 'Jenny',
      'middle' => 'Lauren',
      'last' => 'McCarthy',
      'suffix' => 'Sr.',
      'va_file_number' => '00000000'
    }
  end
  let(:marriage_info) do
    {
      'ssn' => '323454323',
      'birth_date' => '1981-04-04',
      'ever_married_ind' => 'Y',
      'martl_status_type_cd' => 'Married',
      'vet_ind' => 'Y',
      'lives_with_vet' => true,
      'alt_address' => nil,
      'first' => 'Jenny',
      'middle' => 'Lauren',
      'last' => 'McCarthy',
      'suffix' => 'Sr.'
    }
  end
  let(:address_output) do
    {
      'country_name' => 'USA',
      'address_line1' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state_code' => 'CA',
      'zip_code' => '21122'
    }
  end

  describe '#format_info' do
    it 'formats relationship params for submission' do
      formatted_info = marriage.format_info

      expect(formatted_info).to eq(format_info_output)
    end
  end

  describe '#address' do
    it 'returns an address for vet or spouse if separated' do
      address = marriage.address(marriage_info)

      expect(address).to eq(address_output)
    end
  end
end
