# frozen_string_literal: true

require 'rails_helper'
require 'logstop'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'Logstop PII filtering' do
  let(:va_custom_scrubber) do
    lambda do |msg|
      # VA file numbers
      msg = msg.gsub(/\bVA\s*(?:file\s*)?(?:number|#|no\.?)?:?\s*(\d{8,9})\b/i,
                     'VA file number: [VA_FILE_NUMBER_FILTERED]')

      # Standalone 9-digit numbers (SSNs without dashes)
      msg = msg.gsub(/\b(?<!\d)(\d{9})(?!\d)\b/, '[SSN_FILTERED]')

      # ICN (17 digit veteran identifier)
      msg = msg.gsub(/\b(\d{17})\b/, '[ICN_FILTERED]')

      # EDIPI (10 digit DoD identifier)
      msg = msg.gsub(/\b(?<!\d)(\d{10})(?!\d)\b/, '[EDIPI_FILTERED]')

      msg
    end
  end

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

      it 'does not filter longer numbers that are not ICN/EDIPI' do
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
    end

    context 'ICN (Integration Control Number)' do
      it 'filters 17-digit ICN' do
        msg = 'Veteran ICN: 12345678901234567'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('Veteran ICN: [ICN_FILTERED]')
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
        msg = 'User 123456789 with EDIPI 1234567890 and ICN 12345678901234567'
        result = va_custom_scrubber.call(msg)
        expect(result).to eq('User [SSN_FILTERED] with EDIPI [EDIPI_FILTERED] and ICN [ICN_FILTERED]')
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

  describe 'Logstop built-in patterns' do
    # NOTE: These tests verify Logstop's built-in behavior
    # They require Logstop to be properly initialized

    it 'filters SSN with dashes' do
      # Logstop handles XXX-XX-XXXX format
      result = Logstop.scrub('SSN: 123-45-6789')
      expect(result).not_to include('123-45-6789')
      expect(result).to include('[FILTERED]')
    end

    it 'filters email addresses' do
      result = Logstop.scrub('Email: test@example.com')
      expect(result).not_to include('test@example.com')
      expect(result).to include('[FILTERED]')
    end

    it 'filters phone numbers' do
      result = Logstop.scrub('Phone: 555-123-4567')
      expect(result).not_to include('555-123-4567')
      expect(result).to include('[FILTERED]')
    end

    it 'filters credit card numbers' do
      result = Logstop.scrub('Card: 4111111111111111')
      expect(result).not_to include('4111111111111111')
      expect(result).to include('[FILTERED]')
    end

    it 'filters IP addresses' do
      result = Logstop.scrub('IP: 192.168.1.1')
      expect(result).not_to include('192.168.1.1')
      expect(result).to include('[FILTERED]')
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
