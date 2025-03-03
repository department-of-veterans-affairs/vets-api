# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Spouse do
  let(:veteran_spouse) { build(:spouse) }
  let(:spouse) { described_class.new(veteran_spouse['dependents_application']) }
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
  let(:format_info_output_v2) do
    {
      'ssn' => '987654321',
      'birth_date' => '1990-01-01',
      'ever_married_ind' => 'Y',
      'martl_status_type_cd' => 'Married',
      'vet_ind' => 'Y',
      'first' => 'spouse',
      'middle' => 'middle',
      'last' => 'spousename',
      'va_file_number' => '987654321'
    }
  end
  let(:spouse_info) do
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
  let(:address_output_v2) do
    {
      'country' => 'USA',
      'street' => '8200 Doby LN',
      'city' => 'Pasadena',
      'state' => 'CA',
      'postal_code' => '21122'
    }
  end

  context 'with va_dependents_v2 off' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(false)
    end

    describe '#format_info' do
      it 'formats relationship params for submission' do
        formatted_info = spouse.format_info

        expect(formatted_info).to include(format_info_output)
      end
    end

    describe '#address' do
      it 'returns an address for vet or spouse if separated' do
        address = spouse.address

        expect(address).to eq(address_output)
      end
    end
  end

  context 'with va_dependents_v2 on' do
    before do
      allow(Flipper).to receive(:enabled?).with(:va_dependents_v2).and_return(true)
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
end
