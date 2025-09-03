# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/pdf_mapper_base'

describe ClaimsApi::PdfMapperBase do
  subject { test_pdf_mapper_class.new }

  let(:test_pdf_mapper_class) do
    Class.new do
      include ClaimsApi::PdfMapperBase
    end
  end

  describe '#concatenate_address' do
    it 'concatenates all three address lines with spaces' do
      result = subject.concatenate_address('123 Main St', 'Apt 2', 'Floor 3')

      expect(result).to eq('123 Main St Apt 2 Floor 3')
    end

    it 'handles nil values gracefully' do
      result = subject.concatenate_address('123 Main St', nil, 'Floor 3')

      expect(result).to eq('123 Main St Floor 3')
    end

    it 'strips leading and trailing white space' do
      result = subject.concatenate_address('123 Main St', '', '')

      expect(result).to eq('123 Main St')
    end

    it 'returns empty string when all parameters are nil' do
      result = subject.concatenate_address(nil, nil, nil)

      expect(result).to eq('')
    end

    it 'handles empty strings' do
      result = subject.concatenate_address('', '456 Oak Ave', '')

      expect(result).to eq('456 Oak Ave')
    end
  end

  describe '#concatenate_zip_code' do
    it 'concatenates first five and last four' do
      address_object = { 'mailingAddress' => { 'zipFirstFive' => '12345', 'zipLastFour' => '6789' } }

      result = subject.concatenate_zip_code(address_object['mailingAddress'])

      expect(result).to eq('12345-6789')
    end

    it 'returns just first five when that is all that is present' do
      address_object = { 'mailingAddress' => { 'zipFirstFive' => nil, 'zipLastFour' => '',
                                               'internationalPostalCode' => '10431' } }

      result = subject.concatenate_zip_code(address_object['mailingAddress'])

      expect(result).to eq('10431')
    end

    it 'returns international postal code when present' do
      address_object = { 'mailingAddress' => { 'zipFirstFive' => '12345' } }

      result = subject.concatenate_zip_code(address_object['mailingAddress'])

      expect(result).to eq('12345')
    end
  end
end
