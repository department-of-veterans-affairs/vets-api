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

  describe '#combine_official_name' do
    it 'returns early when certifyingOfficial is nil' do
      form_data = {}
      including_class.new.combine_official_name(form_data)
      expect(form_data).to eq({})
    end

    it 'returns early when certifyingOfficial is empty' do
      form_data = { 'certifyingOfficial' => {} }
      including_class.new.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to be_nil
    end

    it 'combines first and last name when both are present' do
      form_data = {
        'certifyingOfficial' => {
          'first' => 'John',
          'last' => 'Doe'
        }
      }
      including_class.new.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to eq('John Doe')
    end

    it 'does not combine when first name is missing' do
      form_data = {
        'certifyingOfficial' => {
          'last' => 'Doe'
        }
      }
      including_class.new.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to be_nil
    end

    it 'does not combine when last name is missing' do
      form_data = {
        'certifyingOfficial' => {
          'first' => 'John'
        }
      }
      including_class.new.combine_official_name(form_data)
      expect(form_data['certifyingOfficial']['fullName']).to be_nil
    end
  end

  describe '#process_programs' do
    it 'returns early when programs is nil' do
      form_data = {}
      including_class.new.process_programs(form_data)
      expect(form_data).to eq({})
    end

    it 'processes programs without calculation date' do
      form_data = {
        'programs' => [
          { 'name' => 'Program 1' },
          { 'name' => 'Program 2' }
        ]
      }
      including_class.new.process_programs(form_data)
      expect(form_data['programs'][0]['programDateOfCalculation']).to be_nil
      expect(form_data['programs'][1]['programDateOfCalculation']).to be_nil
    end

    it 'assigns calculation date to all programs when present' do
      form_data = {
        'institutionDetails' => {
          'dateOfCalculations' => '2023-12-01'
        },
        'programs' => [
          { 'name' => 'Program 1' },
          { 'name' => 'Program 2' }
        ]
      }
      including_class.new.process_programs(form_data)
      expect(form_data['programs'][0]['programDateOfCalculation']).to eq('2023-12-01')
      expect(form_data['programs'][1]['programDateOfCalculation']).to eq('2023-12-01')
    end

    it 'processes fte data when present' do
      form_data = {
        'programs' => [
          {
            'name' => 'Program 1',
            'fte' => {
              'supported' => '5.5',
              'nonSupported' => '0',
              'totalFTE' => '10.25',
              'supportedPercentageFTE' => '55.5'
            }
          }
        ]
      }
      including_class.new.process_programs(form_data)
      expect(form_data['programs'][0]['fte']['supported']).to eq('5.50')
      expect(form_data['programs'][0]['fte']['nonSupported']).to eq('--')
      expect(form_data['programs'][0]['fte']['totalFTE']).to eq('10.25')
      expect(form_data['programs'][0]['fte']['supportedPercentageFTE']).to eq('55.50%')
    end
  end

  describe '#format_numeric_fte_value' do
    let(:helper) { including_class.new }

    it 'formats numeric value correctly when non-zero' do
      result = helper.send(:format_numeric_fte_value, '5.5')
      expect(result).to eq('5.50')
    end

    it 'formats numeric value as -- when zero' do
      result = helper.send(:format_numeric_fte_value, '0')
      expect(result).to eq('--')
    end

    it 'formats numeric value as -- when zero as float' do
      result = helper.send(:format_numeric_fte_value, '0.0')
      expect(result).to eq('--')
    end

    it 'formats decimal values with proper precision' do
      result = helper.send(:format_numeric_fte_value, '3.456789')
      expect(result).to eq('3.46')
    end
  end

  describe '#format_percentage_fte_value' do
    let(:helper) { including_class.new }

    it 'formats percentage value correctly when non-zero' do
      result = helper.send(:format_percentage_fte_value, '75.5')
      expect(result).to eq('75.50%')
    end

    it 'formats percentage value as N/A when zero' do
      result = helper.send(:format_percentage_fte_value, '0')
      expect(result).to eq('N/A')
    end

    it 'formats percentage value as N/A when zero as float' do
      result = helper.send(:format_percentage_fte_value, '0.0')
      expect(result).to eq('N/A')
    end

    it 'formats percentage decimal values with proper precision' do
      result = helper.send(:format_percentage_fte_value, '33.333')
      expect(result).to eq('33.33%')
    end
  end

  describe '#process_fte' do
    it 'formats supported field correctly' do
      fte = { 'supported' => '5.5' }
      including_class.new.process_fte(fte)
      expect(fte['supported']).to eq('5.50')
    end

    it 'formats supported field as -- when zero' do
      fte = { 'supported' => '0' }
      including_class.new.process_fte(fte)
      expect(fte['supported']).to eq('--')
    end

    it 'does not modify supported field when not present' do
      fte = {}
      including_class.new.process_fte(fte)
      expect(fte['supported']).to be_nil
    end

    it 'formats nonSupported field correctly' do
      fte = { 'nonSupported' => '3.25' }
      including_class.new.process_fte(fte)
      expect(fte['nonSupported']).to eq('3.25')
    end

    it 'formats nonSupported field as -- when zero' do
      fte = { 'nonSupported' => '0' }
      including_class.new.process_fte(fte)
      expect(fte['nonSupported']).to eq('--')
    end

    it 'formats totalFTE field correctly' do
      fte = { 'totalFTE' => '15.75' }
      including_class.new.process_fte(fte)
      expect(fte['totalFTE']).to eq('15.75')
    end

    it 'formats totalFTE field as -- when zero' do
      fte = { 'totalFTE' => '0' }
      including_class.new.process_fte(fte)
      expect(fte['totalFTE']).to eq('--')
    end

    it 'formats supportedPercentageFTE field correctly' do
      fte = { 'supportedPercentageFTE' => '75.5' }
      including_class.new.process_fte(fte)
      expect(fte['supportedPercentageFTE']).to eq('75.50%')
    end

    it 'formats supportedPercentageFTE field as N/A when zero' do
      fte = { 'supportedPercentageFTE' => '0' }
      including_class.new.process_fte(fte)
      expect(fte['supportedPercentageFTE']).to eq('N/A')
    end

    it 'processes all fields simultaneously' do
      fte = {
        'supported' => '5.5',
        'nonSupported' => '0',
        'totalFTE' => '10.25',
        'supportedPercentageFTE' => '55.0'
      }
      including_class.new.process_fte(fte)
      expect(fte['supported']).to eq('5.50')
      expect(fte['nonSupported']).to eq('--')
      expect(fte['totalFTE']).to eq('10.25')
      expect(fte['supportedPercentageFTE']).to eq('55.00%')
    end
  end
end
