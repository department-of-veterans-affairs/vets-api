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

  describe '#make_date_string_month_first' do
    before do
      allow_any_instance_of(test_pdf_mapper_class)
        .to receive(:regex_date_conversion).with('2024-12-01').and_return(%w[
                                                                            2024 12 01
                                                                          ])
      allow_any_instance_of(test_pdf_mapper_class)
        .to receive(:regex_date_conversion).with('invalid-date').and_return([
                                                                              nil, nil, nil
                                                                            ])
    end

    context 'when date_length is 4 (year only)' do
      it 'returns only the year as a string' do
        result = subject.make_date_string_month_first('2024-12-01', 4)

        expect(result).to eq('2024')
      end
    end

    context 'when date_length is 7 (month/year)' do
      it 'returns month/year format' do
        result = subject.make_date_string_month_first('2024-12-01', 7)

        expect(result).to eq('12/2024')
      end
    end

    context 'when date_length is full date (month/day/year)' do
      it 'returns month/day/year format' do
        result = subject.make_date_string_month_first('2024-12-01', 10)

        expect(result).to eq('12/01/2024')
      end
    end
  end

  describe '#regex_date_conversion' do
    context 'when date is present and valid' do
      it 'parses full ISO date format (YYYY-MM-DD)' do
        result = subject.regex_date_conversion('2024-12-01')

        expect(result).to eq(%w[2024 12 01])
      end

      it 'parses year-month format (YYYY-MM)' do
        result = subject.regex_date_conversion('2024-12')

        expect(result).to eq(['2024', '12', nil])
      end

      it 'parses month-year format (MM-YYYY)' do
        result = subject.regex_date_conversion('12-2024')

        expect(result).to eq(['2024', '12', nil])
      end

      it 'parses year only format (YYYY)' do
        result = subject.regex_date_conversion('2024')

        expect(result).to eq(['2024', nil, nil])
      end

      it 'parses month-day-year format (MM-DD-YYYY)' do
        result = subject.regex_date_conversion('12-01-2024')

        expect(result).to eq(%w[2024 12 01])
      end
    end

    context 'when date is invalid or does not match pattern' do
      it 'returns nil for partial invalid format' do
        result = subject.regex_date_conversion('24-12-01') # 2-digit year

        expect(result).to be_nil
      end
    end
  end
end
