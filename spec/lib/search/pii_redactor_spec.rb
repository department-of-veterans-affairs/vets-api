# frozen_string_literal: true

require 'rails_helper'

describe Search::PiiRedactor do
  describe '.redact' do
    it 'redacts common PII patterns in strings' do
      input = 'Email test@example.com SSN 123-45-6789 phone 555-123-4567 zip 12345 address 123 Main St'

      redacted = described_class.redact(input)

      expect(redacted).to include('[REDACTED - email]')
      expect(redacted).to include('[REDACTED - ssn]')
      expect(redacted).to include('[REDACTED - phone]')
      expect(redacted).to include('[REDACTED - zip]')
      expect(redacted).to include('[REDACTED - address]')
      expect(redacted).not_to include('test@example.com')
      expect(redacted).not_to include('123-45-6789')
      expect(redacted).not_to include('555-123-4567')
      expect(redacted).not_to include('12345')
      expect(redacted).not_to include('123 Main St')
    end

    it 'redacts values inside arrays and hashes' do
      input = {
        query: 'test@example.com',
        meta: ['555-123-4567', { zip: '12345' }]
      }

      redacted = described_class.redact(input)

      expect(redacted[:query]).to eq('[REDACTED - email]')
      expect(redacted[:meta][0]).to eq('[REDACTED - phone]')
      expect(redacted[:meta][1][:zip]).to eq('[REDACTED - zip]')
    end
  end
end
