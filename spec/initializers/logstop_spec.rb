# frozen_string_literal: true

require 'rails_helper'
require 'logstop'
require_relative '../../config/initializers/logstop'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Logstop PII filtering' do
  # Use the actual scrubber from the initializer
  let(:va_custom_scrubber) { VAPiiScrubber.custom_scrubber }

  describe 'VA custom scrubber' do
    context 'SSN formats' do
      it 'filters 9-digit SSNs without dashes' do
        msg = 'User SSN is 123456789'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('User SSN is [SSN_FILTERED]')
      end

      it 'does not filter shorter numbers' do
        msg = 'Code is 12345678'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('Code is 12345678')
      end

      it 'does not filter longer numbers that are not EDIPI' do
        msg = 'Number is 12345678901'
        result = va_custom_scrubber.call(msg)
        # 11 digits - not filtered by our patterns
        expect(result).to eq('Number is 12345678901')
      end
    end

    context 'VA file numbers' do
      it 'filters VA file number with label' do
        msg = 'VA file number: 12345678'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end

      it 'filters VA file # format' do
        msg = 'VA file #123456789'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end

      it 'filters VA number format' do
        msg = 'VA number 123456789'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end

      it 'filters VA file no. format (covers no\. part of regex)' do
        msg = 'VA file no. 12345678'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end

      it 'filters VA file no.: format with colon' do
        msg = 'VA file no.: 123456789'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end

      it 'filters case insensitive VA Number without file keyword' do
        msg = 'va Number: 12345678'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end

      it 'filters VA with tabs and no file/number keywords' do
        msg = "Va\t\t:\t01234567"
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end
    end

    context 'EDIPI (DoD identifier)' do
      it 'filters 10-digit EDIPI' do
        msg = 'EDIPI is 1234567890'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('EDIPI is [EDIPI_FILTERED]')
      end
    end

    context 'multiple PII in same message' do
      it 'filters multiple PII patterns' do
        msg = 'User 123456789 with EDIPI 1234567890'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('User [SSN_FILTERED] with EDIPI [EDIPI_FILTERED]')
      end
    end

    context 'preserves non-PII content' do
      it 'does not filter regular text' do
        msg = 'This is a normal log message with no PII'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('This is a normal log message with no PII')
      end

      it 'preserves IDs and codes that are not PII' do
        msg = 'Request ID: abc-123-def, Status: 200'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('Request ID: abc-123-def, Status: 200')
      end
    end
  end

  describe 'integrated scrubber with VA custom patterns' do
    # These tests verify our complete integrated scrubber catches all patterns
    # (both Logstop built-in and VA custom patterns)
    # The VAPiiScrubber.custom_scrubber now chains both internally

    let(:integrated_scrubber) { VAPiiScrubber.custom_scrubber }

    context 'Logstop built-in patterns' do
      it 'filters SSN with dashes' do
        result = integrated_scrubber.call('SSN: 123-45-6789')
        expect(result).not_to include('123-45-6789')
        expect(result).to include('[FILTERED]')
      end

      it 'filters email addresses' do
        result = integrated_scrubber.call('Email: test@example.com')
        expect(result).not_to include('test@example.com')
        expect(result).to include('[FILTERED]')
      end

      it 'filters phone numbers' do
        result = integrated_scrubber.call('Phone: 555-123-4567')
        expect(result).not_to include('555-123-4567')
        expect(result).to include('[FILTERED]')
      end

      it 'filters credit card numbers' do
        result = integrated_scrubber.call('Card: 4111111111111111')
        expect(result).not_to include('4111111111111111')
        expect(result).to include('[FILTERED]')
      end
    end

    context 'VA custom patterns' do
      it 'filters SSN without dashes' do
        result = integrated_scrubber.call('SSN: 123456789')
        expect(result).to eq('SSN: [SSN_FILTERED]')
      end

      it 'filters EDIPI' do
        result = integrated_scrubber.call('EDIPI: 1234567890')
        expect(result).to eq('EDIPI: [EDIPI_FILTERED]')
      end

      it 'filters VA file numbers' do
        result = integrated_scrubber.call('VA file #12345678')
        expect(result).to eq('VA file number: [VA_FILE_NUMBER_FILTERED]')
      end
    end

    context 'combined patterns' do
      it 'filters multiple PII types in one message' do
        msg = 'User SSN 123-45-6789, email test@example.com, EDIPI 1234567890'
        result = integrated_scrubber.call(msg)
        expect(result).not_to include('123-45-6789')
        expect(result).not_to include('test@example.com')
        expect(result).not_to include('1234567890')
      end
    end
  end

  describe 'integration with existing filter_parameters' do
    it 'works alongside ParameterFilterHelper' do
      # Verify that both filtering mechanisms can coexist
      # ParameterFilterHelper handles parameter names
      # Logstop handles content patterns

      params = { body: 'My SSN is 123-45-6789' }
      filtered_params = ParameterFilterHelper.filter_params(params)

      # ParameterFilterHelper filters the entire value because 'body' is not in ALLOWLIST
      expect(filtered_params[:body]).to eq('[FILTERED]')
    end
  end
end
# rubocop:enable RSpec/DescribeClass
