# frozen_string_literal: true

require 'rails_helper'
require_relative '../has_structured_data'

RSpec.describe HasStructuredData do
  subject { dummy_class.new }

  let(:dummy_class) do
    Class.new do
      include HasStructuredData
    end
  end

  describe '#build_name' do
    it 'returns a hash with first, middle, last, middle_initial, and full keys' do
      name_hash = { 'first' => 'John', 'middle' => 'Quincy', 'last' => 'Doe' }
      result = subject.build_name(name_hash)

      expect(result).to eq(
        first: 'John',
        middle: 'Quincy',
        last: 'Doe',
        middle_initial: 'Q',
        full: 'John Quincy Doe'
      )
    end

    it 'handles missing middle name gracefully' do
      name_hash = { 'first' => 'Jane', 'last' => 'Smith' }
      result = subject.build_name(name_hash)

      expect(result).to eq(
        first: 'Jane',
        middle: nil,
        last: 'Smith',
        middle_initial: nil,
        full: 'Jane Smith'
      )
    end

    it 'returns nil for all fields if name_hash is nil' do
      result = subject.build_name(nil)

      expect(result).to eq(
        first: nil,
        middle: nil,
        last: nil,
        middle_initial: nil,
        full: nil
      )
    end
  end

  describe '#build_address_block' do
    it 'returns a single-line address string from a valid address hash' do
      address = {
        'street' => '123 Main St',
        'street2' => 'Apt 4B',
        'city' => 'Anytown',
        'state' => 'NY',
        'postalCode' => '12345',
        'country' => 'USA'
      }
      result = subject.build_address_block(address)

      expect(result).to eq('123 Main St Apt 4B Anytown NY 12345 USA')
    end

    it 'handles missing optional fields gracefully' do
      address = {
        'street' => '456 Elm St',
        'city' => 'Othertown',
        'state' => 'CA'
      }
      result = subject.build_address_block(address)

      expect(result).to eq('456 Elm St Othertown CA')
    end

    it 'returns nil if address is nil' do
      result = subject.build_address_block(nil)

      expect(result).to be_nil
    end
  end

  describe '#claimant_address_block' do
    it 'returns the claimant address block when claimantAddress is present' do
      form = {
        'claimantAddress' => {
          'street' => '789 Oak St',
          'city' => 'Sometown',
          'state' => 'TX'
        },
        'veteranAddress' => {
          'street' => '123 Main St',
          'city' => 'Anytown',
          'state' => 'NY'
        }
      }
      result = subject.claimant_address_block(form)

      expect(result).to eq('789 Oak St Sometown TX')
    end

    it 'falls back to veteran address when claimantAddress is missing' do
      form = {
        'veteranAddress' => {
          'street' => '123 Main St',
          'city' => 'Anytown',
          'state' => 'NY'
        }
      }
      result = subject.claimant_address_block(form)

      expect(result).to eq('123 Main St Anytown NY')
    end

    it 'returns nil if both claimant and veteran addresses are missing' do
      form = {}
      result = subject.claimant_address_block(form)

      expect(result).to be_nil
    end
  end

  describe '#claimant_phone_number' do
    it 'returns the claimant phone number when country is US' do
      form = {
        'primaryPhone' => {
          'contact' => '555-123-4567',
          'countryCode' => 'US'
        }
      }
      result = subject.claimant_phone_number(form)

      expect(result).to eq('5551234567')
    end

    it 'returns nil when country is not US' do
      form = {
        'primaryPhone' => {
          'contact' => '555-123-4567',
          'countryCode' => 'CA'
        }
      }
      result = subject.claimant_phone_number(form)

      expect(result).to be_nil
    end

    it 'returns nil when contact is missing' do
      form = {
        'primaryPhone' => {
          'countryCode' => 'US'
        }
      }
      result = subject.claimant_phone_number(form)

      expect(result).to be_nil
    end

    it 'returns nil when primaryPhone is missing' do
      form = {}
      result = subject.claimant_phone_number(form)

      expect(result).to be_nil
    end
  end

  describe '#international_phone_number' do
    it 'returns the international phone number when internationalPhone is present' do
      form = {
        'internationalPhone' => '555-987-6543'
      }
      result = subject.international_phone_number(form, {})

      expect(result).to eq('5559876543')
    end

    it 'returns the primary phone number when country is not US and internationalPhone is missing' do
      form = {
        'primaryPhone' => {
          'contact' => '555-123-4567',
          'countryCode' => 'CA'
        }
      }
      result = subject.international_phone_number(form, form['primaryPhone'])

      expect(result).to eq('5551234567')
    end

    it 'returns nil when country is US and internationalPhone is missing' do
      form = {
        'primaryPhone' => {
          'contact' => '555-123-4567',
          'countryCode' => 'US'
        }
      }
      result = subject.international_phone_number(form, form['primaryPhone'])

      expect(result).to be_nil
    end

    it 'returns nil when primaryPhone is missing and internationalPhone is missing' do
      form = {}
      result = subject.international_phone_number(form, {})

      expect(result).to be_nil
    end
  end

  describe '#format_phone' do
    it 'strips non-digit characters from a phone number' do
      result = subject.format_phone('(555) 123-4567')
      expect(result).to eq('5551234567')
    end

    it 'returns nil when given nil' do
      result = subject.format_phone(nil)
      expect(result).to be_nil
    end

    it 'returns an empty string when given an empty string' do
      result = subject.format_phone('')
      expect(result).to eq('')
    end
  end

  describe '#format_date' do
    it 'formats a date string to MM/DD/YYYY format' do
      result = subject.format_date('2023-01-01')
      expect(result).to eq('01/01/2023')
    end

    it 'returns nil when given nil' do
      result = subject.format_date(nil)
      expect(result).to be_nil
    end

    it 'returns nil when given an invalid date string' do
      result = subject.format_date('invalid-date')
      expect(result).to be_nil
    end
  end

  describe '#claim_date_signed' do
    it 'formats the dateSigned field when present' do
      form = { 'dateSigned' => '2023-01-01' }
      result = subject.claim_date_signed(form)
      expect(result).to eq('01/01/2023')
    end

    it 'falls back to signatureDate if dateSigned is missing' do
      form = { 'signatureDate' => '2023-02-02' }
      result = subject.claim_date_signed(form)
      expect(result).to eq('02/02/2023')
    end

    it 'returns nil if both dateSigned and signatureDate are missing' do
      form = {}
      result = subject.claim_date_signed(form)
      expect(result).to be_nil
    end
  end

  describe '#build_witness_fields' do
    it 'returns a hash with witness fields set to nil' do
      result = subject.build_witness_fields
      # use the keys from the method to ensure we are testing the correct fields
      expect(result).to eq(
        'WITNESS_1_NAME' => nil,
        'WITNESS_1_SIGNATURE' => nil,
        'WITNESS_1_ADDRESS' => nil,
        'WITNESS_2_NAME' => nil,
        'WITNESS_2_SIGNATURE' => nil,
        'WITNESS_2_ADDRESS' => nil
      )
    end
  end

  describe '#use_va_rcvd_date?' do
    it 'returns true when firstTimeReporting is true' do
      form = { 'firstTimeReporting' => true }
      result = subject.use_va_rcvd_date?(form)
      expect(result).to be true
    end

    it 'returns false when firstTimeReporting is false' do
      form = { 'firstTimeReporting' => false }
      result = subject.use_va_rcvd_date?(form)
      expect(result).to be false
    end

    it 'returns false when firstTimeReporting is missing' do
      form = {}
      result = subject.use_va_rcvd_date?(form)
      expect(result).to be false
    end
  end

  describe '#format_currency' do
    it 'formats a number as currency with two decimal places' do
      result = subject.format_currency(123456.789)
      expect(result).to eq('123,456.79')
    end

    it 'formats a number as currency with no decimal places when zero' do
      result = subject.format_currency(1000)
      expect(result).to eq('1,000.00')
    end

    it 'returns nil when given nil' do
      result = subject.format_currency(nil)
      expect(result).to be_nil
    end

    it 'returns nil when given a non-numeric value' do
      result = subject.format_currency('not-a-number')
      expect(result).to be_nil
    end
  end

  describe '#sanitize_phone' do
    it 'strips non-digit characters from a phone number' do
      result = subject.sanitize_phone('(555) 123-4567')
      expect(result).to eq('5551234567')
    end

    it 'returns nil when given nil' do
      result = subject.sanitize_phone(nil)
      expect(result).to be_nil
    end

    it 'returns an empty string when given an empty string' do
      result = subject.sanitize_phone('')
      expect(result).to eq('')
    end
  end
end
