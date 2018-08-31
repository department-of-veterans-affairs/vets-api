# frozen_string_literal: true

require 'rails_helper'

describe PdfFill::Forms::FormHelper do
  let(:including_class) { Class.new { include PdfFill::Forms::FormHelper } }

  describe '#split_ssn' do
    it 'should return nil' do
      expect(including_class.new.split_ssn('')).to eq(nil)
    end

    it 'should split the ssn' do
      expect(including_class.new.split_ssn('111223333')).to eq('first' => '111', 'second' => '22', 'third' => '3333')
    end
  end

  describe '#extract_middle_i' do
    it 'veteran with no name should return nil' do
      expect(including_class.new.extract_middle_i({}, 'veteranFullName')).to eq(nil)
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

    it 'should extract middle initial when there is a middle name' do
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
    it 'should return the correct code for country' do
      address = {
        'country' => 'USA'
      }
      expect(including_class.new.extract_country(address)).to eq('US')
    end
  end

  describe '#split_postal_code' do
    it 'should return nil with blank address' do
      expect(including_class.new.split_postal_code({})).to eq(nil)
    end

    it 'should return nil with no postal code' do
      address = {
        'city' => 'Baltimore'
      }
      expect(including_class.new.split_postal_code(address)).to eq(nil)
    end

    it 'should return nil for blank postal code' do
      address = {
        'postalCode' => ''
      }
      expect(including_class.new.split_postal_code(address)).to eq(nil)
    end

    it 'should split the code correctly with extra characters' do
      address = {
        'postalCode' => '12345-0000'
      }
      expect(including_class.new.split_postal_code(address)).to eq('firstFive' => '12345', 'lastFour' => '0000')
    end

    it 'should split the code correctly with 9 digits' do
      address = {
        'postalCode' => '123450000'
      }
      expect(including_class.new.split_postal_code(address)).to eq('firstFive' => '12345', 'lastFour' => '0000')
    end

    it 'should split the code correctly with 5 digits' do
      address = {
        'postalCode' => '12345'
      }
      expect(including_class.new.split_postal_code(address)).to eq('firstFive' => '12345', 'lastFour' => '')
    end
  end

  describe '#split_date' do
    it 'should return nil with no date' do
      expect(including_class.new.split_date(nil)).to be_nil
    end

    it 'should return nil if date not correct format (expected yyyy-mm-dd)' do
      expect(including_class.new.split_date('11052018')).to be_nil
    end

    it 'should split date correctly' do
      expect(including_class.new.split_date('2018-11-05')).to eq('month' => '11', 'day' => '05', 'year' => '2018')
    end
  end

  describe '#validate_date' do
    it 'should return nil with bad data' do
      expect(including_class.new.validate_date('1234567')).to be_nil
    end

    it 'should return nil with nil date' do
      expect(including_class.new.validate_date(nil)).to be_nil
    end

    it 'should return nil with impossible date' do
      expect(including_class.new.validate_date('2018-01-32')).to be nil
    end

    it 'should return nil with blank date' do
      expect(including_class.new.validate_date('')).to be_nil
    end

    it 'should return date' do
      expect(including_class.new.validate_date('2018-01-01')).to be_truthy
    end
  end
end
