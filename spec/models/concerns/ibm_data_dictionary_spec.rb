# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IbmDataDictionary do
  subject { dummy_class.new }

  let(:dummy_class) do
    Class.new do
      include IbmDataDictionary
    end
  end

  describe '#build_veteran_basic_fields' do
    let(:vet_info) do
      {
        'fullName' => {
          'first' => 'John',
          'middle' => 'Michael',
          'last' => 'Doe'
        },
        'ssn' => '123456789',
        'vaFileNumber' => '987654321',
        'dateOfBirth' => '1950-01-15'
      }
    end

    it 'returns veteran fields with default full name field' do
      result = subject.build_veteran_basic_fields(vet_info)

      expect(result).to include(
        'VETERAN_FIRST_NAME' => 'John',
        'VETERAN_MIDDLE_INITIAL' => 'M',
        'VETERAN_LAST_NAME' => 'Doe',
        'VETERAN_NAME' => 'John M Doe',
        'VETERAN_SSN' => '123456789',
        'VA_FILE_NUMBER' => '987654321',
        'VETERAN_DOB' => '01/15/1950'
      )
    end

    it 'accepts custom full name field option' do
      result = subject.build_veteran_basic_fields(vet_info, full_name_field: 'CUSTOM_NAME')

      expect(result).to include('CUSTOM_NAME' => 'John M Doe')
      expect(result).not_to include('VETERAN_NAME')
    end

    it 'returns empty hash when vet_info is nil' do
      expect(subject.build_veteran_basic_fields(nil)).to eq({})
    end

    it 'handles missing middle name' do
      vet_info['fullName'].delete('middle')
      result = subject.build_veteran_basic_fields(vet_info)

      expect(result['VETERAN_MIDDLE_INITIAL']).to be_nil
      expect(result['VETERAN_NAME']).to eq('John Doe')
    end
  end

  describe '#build_claimant_fields' do
    let(:claimant_info) do
      {
        'fullName' => {
          'first' => 'Jane',
          'middle' => 'Elizabeth',
          'last' => 'Smith'
        },
        'ssn' => '987654321',
        'dateOfBirth' => '1955-03-20'
      }
    end

    it 'returns claimant fields' do
      result = subject.build_claimant_fields(claimant_info)

      expect(result).to include(
        'CLAIMANT_FIRST_NAME' => 'Jane',
        'CLAIMANT_MIDDLE_INITIAL' => 'E',
        'CLAIMANT_LAST_NAME' => 'Smith',
        'CLAIMANT_SSN' => '987654321',
        'CLAIMANT_DOB' => '03/20/1955'
      )
    end

    it 'returns empty hash when claimant_info is nil' do
      expect(subject.build_claimant_fields(nil)).to eq({})
    end
  end

  describe '#build_full_name' do
    it 'builds full name with first, middle initial, and last' do
      name_hash = { 'first' => 'John', 'middle' => 'Michael', 'last' => 'Doe' }
      expect(subject.build_full_name(name_hash)).to eq('John M Doe')
    end

    it 'builds full name without middle name' do
      name_hash = { 'first' => 'John', 'last' => 'Doe' }
      expect(subject.build_full_name(name_hash)).to eq('John Doe')
    end

    it 'returns nil for nil name_hash' do
      expect(subject.build_full_name(nil)).to be_nil
    end

    it 'handles empty middle name' do
      name_hash = { 'first' => 'John', 'middle' => '', 'last' => 'Doe' }
      expect(subject.build_full_name(name_hash)).to eq('John Doe')
    end
  end

  describe '#extract_middle_initial' do
    it 'extracts first character from middle name' do
      expect(subject.extract_middle_initial('Michael')).to eq('M')
    end

    it 'returns nil for nil middle name' do
      expect(subject.extract_middle_initial(nil)).to be_nil
    end

    it 'returns single character for single-character middle name' do
      expect(subject.extract_middle_initial('M')).to eq('M')
    end
  end

  describe '#build_full_address' do
    let(:address) do
      {
        'street' => '123 Main St',
        'street2' => 'Apt 4',
        'city' => 'Springfield',
        'state' => 'IL',
        'postalCode' => '62701'
      }
    end

    it 'builds complete address string' do
      result = subject.build_full_address(address)
      expect(result).to eq('123 Main St Apt 4 Springfield, IL 62701')
    end

    it 'handles missing street2' do
      address.delete('street2')
      result = subject.build_full_address(address)
      expect(result).to eq('123 Main St Springfield, IL 62701')
    end

    it 'returns nil for nil address' do
      expect(subject.build_full_address(nil)).to be_nil
    end
  end

  describe '#build_address_fields' do
    let(:address) do
      {
        'street' => '123 Main St',
        'street2' => 'Apt 4',
        'city' => 'Springfield',
        'state' => 'IL',
        'postalCode' => '62701'
      }
    end

    it 'builds address fields with prefix' do
      result = subject.build_address_fields(address, 'CLAIMANT_ADDRESS')

      expect(result).to include(
        'CLAIMANT_ADDRESS_LINE1' => '123 Main St',
        'CLAIMANT_ADDRESS_LINE2' => 'Apt 4',
        'CLAIMANT_ADDRESS_CITY' => 'Springfield',
        'CLAIMANT_ADDRESS_STATE' => 'IL',
        'CLAIMANT_ADDRESS_ZIP5' => '62701',
        'CLAIMANT_ADDRESS' => '123 Main St Apt 4 Springfield, IL 62701'
      )
    end

    it 'returns empty hash for nil address' do
      expect(subject.build_address_fields(nil, 'PREFIX')).to eq({})
    end
  end

  describe '#format_date_for_ibm' do
    context 'with default format (with slashes)' do
      it 'converts YYYY-MM-DD to MM/DD/YYYY' do
        expect(subject.format_date_for_ibm('1950-01-15')).to eq('01/15/1950')
      end

      it 'explicitly uses :with_slashes format' do
        expect(subject.format_date_for_ibm('1950-01-15', format: :with_slashes)).to eq('01/15/1950')
      end
    end

    context 'with :without_slashes format' do
      it 'converts YYYY-MM-DD to MMDDYYYY' do
        expect(subject.format_date_for_ibm('1950-01-15', format: :without_slashes)).to eq('01151950')
      end
    end

    it 'returns nil for nil date' do
      expect(subject.format_date_for_ibm(nil)).to be_nil
    end

    it 'returns nil for invalid date format' do
      expect(subject.format_date_for_ibm('invalid')).to be_nil
    end
  end

  describe '#format_phone_for_ibm' do
    it 'preserves phone number formatting' do
      expect(subject.format_phone_for_ibm('555-123-4567')).to eq('555-123-4567')
    end

    it 'strips whitespace' do
      expect(subject.format_phone_for_ibm('  555-123-4567  ')).to eq('555-123-4567')
    end

    it 'returns nil for nil phone' do
      expect(subject.format_phone_for_ibm(nil)).to be_nil
    end
  end

  describe '#build_checkbox_value' do
    it 'returns X for true' do
      expect(subject.build_checkbox_value(true)).to eq('X')
    end

    it 'returns nil for false' do
      expect(subject.build_checkbox_value(false)).to be_nil
    end

    it 'returns nil for nil' do
      expect(subject.build_checkbox_value(nil)).to be_nil
    end
  end

  describe '#build_form_metadata' do
    it 'builds form metadata with type' do
      result = subject.build_form_metadata('21P-530a')
      expect(result).to eq('FORM_TYPE' => '21P-530a')
    end

    it 'merges additional fields' do
      result = subject.build_form_metadata('21P-530a', 'VETERAN_SSN' => '123456789')
      expect(result).to include(
        'FORM_TYPE' => '21P-530a',
        'VETERAN_SSN' => '123456789'
      )
    end
  end
end
