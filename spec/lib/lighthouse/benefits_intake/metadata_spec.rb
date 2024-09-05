# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_intake/metadata'

RSpec.describe BenefitsIntake::Metadata do
  let(:meta) { described_class }

  context 'with valid parameters' do
    let(:valid) do
      {
        'veteranFirstName' => 'firstname',
        'veteranLastName' => 'lastname',
        'fileNumber' => '123456789',
        'zipCode' => '12345-5555',
        'source' => 'source',
        'docType' => 'doc_type',
        'businessLine' => 'BVA'
      }
    end

    it 'returns unmodified metadata' do
      data = meta.generate('firstname', 'lastname', '123456789', '12345-5555', 'source', 'doc_type', 'BVA')
      expect(data).to eq(valid)
    end

    it 'returns corrected metadata' do
      data = meta.generate('first_name', 'last_name', '123456789', '123455555', 'source', 'doc_type', :bva)
      expect(data).to eq(valid)
    end
  end

  context 'malformed data' do
    it 'truncates names' do
      charset = Array('a'..'z') + Array('A'..'Z') + ['-', ' ', '/']
      firstname = Array.new(rand(50..100)) { charset.sample }.join
      lastname = Array.new(rand(50..100)) { charset.sample }.join

      first50 = meta.validate_first_name({ 'veteranFirstName' => firstname })
      expect(first50).to eq({ 'veteranFirstName' => firstname.strip[0..49] })

      last50 = meta.validate_last_name({ 'veteranLastName' => lastname })
      expect(last50).to eq({ 'veteranLastName' => lastname.strip[0..49] })
    end

    it 'errors on substituted blank names' do
      expect do
        meta.validate_first_name({ 'veteranFirstName' => '23&_$!42' })
      end.to raise_error(ArgumentError, 'veteran first name is blank')

      expect do
        meta.validate_last_name({ 'veteranLastName' => '23&_$!42' })
      end.to raise_error(ArgumentError, 'veteran last name is blank')
    end

    it 'corrects malformed zipcode' do
      zip = meta.validate_zip_code({ 'zipCode' => '12345TEST' })
      expect(zip).to eq({ 'zipCode' => '12345' })

      zip = meta.validate_zip_code({ 'zipCode' => '12345TEST6789' })
      expect(zip).to eq({ 'zipCode' => '12345-6789' })

      zip = meta.validate_zip_code({ 'zipCode' => '123456789123456789' })
      expect(zip).to eq({ 'zipCode' => '00000' })
    end

    it 'corrects malformed business_line' do
      zip = meta.validate_business_line({ 'businessLine' => :BVA })
      expect(zip).to eq({ 'businessLine' => 'BVA' })

      zip = meta.validate_business_line({ 'businessLine' => :pmc })
      expect(zip).to eq({ 'businessLine' => 'PMC' })

      zip = meta.validate_business_line({ 'businessLine' => 'pmc' })
      expect(zip).to eq({ 'businessLine' => 'PMC' })

      zip = meta.validate_business_line({ 'businessLine' => :TEST })
      expect(zip).to eq({ 'businessLine' => 'OTH' })

      zip = meta.validate_business_line({ 'businessLine' => 'TEST' })
      expect(zip).to eq({ 'businessLine' => 'OTH' })

      zip = meta.validate_business_line({ 'businessLine' => nil })
      expect(zip).to eq({})
    end

    it 'errors on invalid file number' do
      expect do
        meta.validate_file_number({ 'fileNumber' => '123TEST89' })
      end.to raise_error(ArgumentError, 'file number is invalid. It must be 8 or 9 digits')

      expect do
        meta.validate_file_number({ 'fileNumber' => '123456789123456789' })
      end.to raise_error(ArgumentError, 'file number is invalid. It must be 8 or 9 digits')

      expect do
        meta.validate_file_number({ 'fileNumber' => '12345' })
      end.to raise_error(ArgumentError, 'file number is invalid. It must be 8 or 9 digits')
    end
  end

  describe '#validate_presence_and_stringiness' do
    it 'raises a missing exception' do
      expect do
        meta.validate_presence_and_stringiness(nil, 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is missing')

      expect do
        meta.validate_presence_and_stringiness(false, 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is missing')
    end

    it 'raises a non-string exception' do
      expect do
        meta.validate_presence_and_stringiness(12, 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is not a string')

      expect do
        meta.validate_presence_and_stringiness(true, 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is not a string')

      expect do
        meta.validate_presence_and_stringiness({}, 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is not a string')
    end

    it 'raises a blank exception' do
      expect do
        meta.validate_nonblank('', 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is blank')

      expect do
        meta.validate_nonblank('       ', 'TEST FIELD')
      end.to raise_error(ArgumentError, 'TEST FIELD is blank')
    end
  end

  # end Rspec.describe
end
