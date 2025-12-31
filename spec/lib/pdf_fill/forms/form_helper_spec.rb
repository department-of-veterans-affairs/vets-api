# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/form_helper'

describe PdfFill::Forms::FormHelper do
  let(:including_class) { Class.new { include PdfFill::Forms::FormHelper } }

  describe '#split_ssn' do
    it 'returns nil' do
      expect(including_class.new.split_ssn('')).to be_nil
    end

    it 'splits the ssn' do
      expect(including_class.new.split_ssn('111223333')).to eq('first' => '111', 'second' => '22', 'third' => '3333')
    end
  end

  describe '#split_currency_string' do
    it 'returns nil' do
      expect(including_class.new.split_currency_string('')).to be_nil
    end

    it 'returns ones without cents' do
      expect(including_class.new.split_currency_string('123')).to eq({ thousands: nil, ones: '123', cents: '00' })
    end

    it 'returns cents' do
      expect(including_class.new.split_currency_string('.00')).to eq({ thousands: nil, ones: nil, cents: '00' })
    end

    it 'returns ones' do
      expect(including_class.new.split_currency_string('1.23')).to eq({ thousands: nil, ones: '  1', cents: '23' })
    end

    it 'returns thousands' do
      expect(including_class.new.split_currency_string('123456.78')).to eq({ thousands: '123', ones: '456',
                                                                             cents: '78' })
    end

    it 'returns thousand' do
      expect(including_class.new.split_currency_string('3456.78')).to eq({ thousands: '  3', ones: '456',
                                                                           cents: '78' })
    end
  end

  describe '#extract_middle_i' do
    it 'veteran with no name should return nil' do
      expect(including_class.new.extract_middle_i({}, 'veteranFullName')).to be_nil
    end

    it 'veteran name with no middle name should return nil' do
      veteran_full_name = {
        'veteranFullName' => {
          'first' => 'testy',
          'last' => 'testerson'
        }
      }
      expect(including_class.new.extract_middle_i(veteran_full_name, 'veteranFullName')).to eq(
        'first' => 'testy',
        'last' => 'testerson'
      )
    end

    it 'extracts middle initial when there is a middle name' do
      veteran_full_name = {
        'veteranFullName' => {
          'middle' => 'middle'
        }
      }
      expect(including_class.new.extract_middle_i(veteran_full_name, 'veteranFullName')).to eq(
        'middle' => 'middle',
        'middleInitial' => 'm'
      )
    end
  end

  describe '#extract_country' do
    it 'returns the correct code for country' do
      address = {
        'country' => 'USA'
      }
      expect(including_class.new.extract_country(address)).to eq('US')
    end
  end

  describe '#extract_country_if_not_usa' do
    it 'returns the correct code for country' do
      address = {
        'country' => 'Ghana'
      }
      expect(including_class.new.extract_country(address)).to eq('GH')
    end
  end

  describe '#extract_country_if_not_valid_code' do
    it 'returns the passed value as country' do
      address = {
        'country' => 'InvalidCountry'
      }
      expect(including_class.new.extract_country(address)).to eq('InvalidCountry')
    end
  end

  describe '#split_postal_code' do
    it 'returns nil with blank address' do
      expect(including_class.new.split_postal_code({})).to be_nil
    end

    it 'returns nil with no postal code' do
      address = {
        'city' => 'Baltimore'
      }
      expect(including_class.new.split_postal_code(address)).to be_nil
    end

    it 'returns nil for blank postal code' do
      address = {
        'postalCode' => ''
      }
      expect(including_class.new.split_postal_code(address)).to be_nil
    end

    it 'splits the code correctly with extra characters' do
      address = {
        'postalCode' => '12345-0000'
      }
      expect(including_class.new.split_postal_code(address)).to eq('firstFive' => '12345', 'lastFour' => '0000')
    end

    it 'splits the code correctly with 9 digits' do
      address = {
        'postalCode' => '123450000'
      }
      expect(including_class.new.split_postal_code(address)).to eq('firstFive' => '12345', 'lastFour' => '0000')
    end

    it 'splits the code correctly with 5 digits' do
      address = {
        'postalCode' => '12345'
      }
      expect(including_class.new.split_postal_code(address)).to eq('firstFive' => '12345', 'lastFour' => '')
    end
  end

  describe '#split_date' do
    it 'returns nil with no date' do
      expect(including_class.new.split_date(nil)).to be_nil
    end

    it 'returns nil if date not correct format (expected yyyy-mm-dd)' do
      expect(including_class.new.split_date('11052018')).to be_nil
    end

    it 'splits date correctly' do
      expect(including_class.new.split_date('2018-11-05')).to eq('month' => '11', 'day' => '05', 'year' => '2018')
    end
  end

  describe '#validate_date' do
    it 'returns nil with bad data' do
      expect(including_class.new.validate_date('1234567')).to be_nil
    end

    it 'returns nil with nil date' do
      expect(including_class.new.validate_date(nil)).to be_nil
    end

    it 'returns nil with impossible date' do
      expect(including_class.new.validate_date('2018-01-32')).to be_nil
    end

    it 'returns nil with blank date' do
      expect(including_class.new.validate_date('')).to be_nil
    end

    it 'returns date' do
      expect(including_class.new.validate_date('2018-01-01')).to be_truthy
    end
  end

  describe '#address_block' do
    it 'returns nil with nil address' do
      expect(including_class.new.address_block(nil)).to be_nil
    end

    it 'returns full address block with full address' do
      address = {
        'street' => '123 Test St.',
        'street2' => '4B',
        'city' => 'Testville',
        'state' => 'SC',
        'postalCode' => '12345-6789',
        'country' => 'US'
      }
      expect(including_class.new.address_block(address)).to eq("123 Test St. 4B\nTestville SC 12345-6789\nUS")
    end

    it 'returns partial address block with partial address' do
      address = {
        'street' => '123 Test St.',
        'state' => 'SC'
      }
      expect(including_class.new.address_block(address)).to eq("123 Test St.\nSC")
    end
  end

  describe '#format_radio_yes_no' do
    it 'returns empty string with nil value' do
      expect(including_class.new.format_radio_yes_no(nil)).to eq('')
    end

    it 'returns empty string with blank value' do
      expect(including_class.new.format_radio_yes_no('')).to eq('')
    end

    it 'returns Yes for Y' do
      expect(including_class.new.format_radio_yes_no('Y')).to eq('Yes')
    end

    it 'returns No for N' do
      expect(including_class.new.format_radio_yes_no('N')).to eq('No')
    end

    it 'return NA for NA' do
      expect(including_class.new.format_radio_yes_no('NA')).to eq('NA')
    end
  end

  describe '#normalize_mailing_address' do
    it 'normalizes address if domestic' do
      address = { 'country' => 'US', 'state' => 'MT' }
      including_class.new.normalize_mailing_address(address)
      expect(address['country']).to be_nil
    end

    it 'normalizes address if Mexican' do
      address = { 'country' => 'MEX', 'state' => 'baja-california-norte' }
      including_class.new.normalize_mailing_address(address)
      expect(address['state']).to eq('Baja California Norte')
    end
  end
end
