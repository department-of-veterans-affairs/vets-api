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
      address_object = { 'mailingAddress' => { 'country' => 'USA', 'zipFirstFive' => '12345',
                                               'zipLastFour' => '6789' } }

      result = subject.concatenate_zip_code(address_object['mailingAddress'])

      expect(result).to eq('12345-6789')
    end

    it 'returns just first five when that is all that is present' do
      address_object = { 'mailingAddress' => { 'country' => 'USA', 'zipFirstFive' => '12345' } }

      result = subject.concatenate_zip_code(address_object['mailingAddress'])

      expect(result).to eq('12345')
    end

    it 'returns international postal code when present' do
      address_object = { 'mailingAddress' => { 'zipFirstFive' => nil, 'zipLastFour' => '',
                                               'internationalPostalCode' => '10431', 'country' => 'Australia' } }

      result = subject.concatenate_zip_code(address_object['mailingAddress'])

      expect(result).to eq('10431')
    end
  end

  describe '#format_ssn' do
    it 'formats an SSN string' do
      ssn = '123456789'
      result = subject.format_ssn(ssn)

      expect(result).to eq('123-45-6789')
    end
  end

  describe '#format_birth_date' do
    it 'extracts month, day, and year correctly' do
      result = subject.format_birth_date('1948-10-30T00:00:00+00:00') # birth date format from auth_header

      expected = { month: '10', day: '30', year: '1948' }

      expect(result).to eq(expected)
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

  describe '#make_date_object' do
    context 'when date_length is 4 (year only)' do
      it 'returns a hash with only year' do
        result = subject.make_date_object('2023', 4)

        expect(result).to eq({ year: '2023' })
      end
    end

    context 'when date_length is 7 (year and month)' do
      it 'returns a hash with year and month' do
        result = subject.make_date_object('2023-12', 7)

        expect(result).to eq({ month: '12', year: '2023' })
      end
    end

    context 'when date_length is neither 4 nor 7 (full date)' do
      it 'returns a hash with year, month, and day' do
        result = subject.make_date_object('2023-12-25', 10)

        expect(result).to eq({ year: '2023', month: '12', day: '25' })
      end
    end

    context 'when year is nil (invalid date)' do
      it 'returns nil' do
        result = subject.make_date_object('invalid-date', 10)

        expect(result).to be_nil
      end
    end
  end

  describe '#convert_phone' do
    it 'formats a plain 10-digit number' do
      number = String.new('1234567890')

      res = subject.convert_phone(number)

      expect(res).to eq('123-456-7890')
    end

    it 'formats an 11-digit number (with country code)' do
      number = String.new('11234567890')

      res = subject.convert_phone(number)

      expect(res).to eq('11-23-4567-890')
    end

    it 'returns nil for strings with something other than digits in them' do
      number = String.new('555defghij')

      res = subject.convert_phone(number)

      expect(res).to be_nil
    end
  end

  describe '#build_disability_item' do
    it 'returns hash with all keys when exposure is provided' do
      result = subject.build_disability_item(
        'PTSD',
        '2020-01-01',
        'Combat related',
        'Agent Orange'
      )

      expect(result).to eq({
                             disability: 'PTSD',
                             approximateDate: '2020-01-01',
                             exposureOrEventOrInjury: 'Agent Orange',
                             serviceRelevance: 'Combat related'
                           })
    end

    it 'handles no exposure key' do
      result = subject.build_disability_item(
        'Hearing Loss',
        '2019-06-15',
        'Artillery exposure'
      )

      expect(result).to eq({
                             disability: 'Hearing Loss',
                             approximateDate: '2019-06-15',
                             serviceRelevance: 'Artillery exposure'
                           })
      expect(result).not_to have_key(:exposureOrEventOrInjury)
    end
  end

  describe '#handle_yes_no' do
    it "return 'NO' when sent false" do
      res = subject.handle_yes_no(false)

      expect(res).to eq('NO')
    end

    it "return 'YES' when sent true" do
      res = subject.handle_yes_no(true)

      expect(res).to eq('YES')
    end
  end
end
