# frozen_string_literal: true

require 'rails_helper'
require 'logging/helper/data_scrubber'

RSpec.describe Logging::Helper::DataScrubber do
  let(:redaction) { '[REDACTED]' }

  describe '.scrub' do
    context 'when logging_data_scrubber flipper is enabled' do
      before { allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(true) }

      context 'with string data' do
        # Test cases: [input, expected_output]
        pii_test_cases = [
          # SSNs
          ['My SSN is 123-45-6789', 'My SSN is [REDACTED]'],
          ['SSN: 123456789', 'SSN: [REDACTED]'],
          ['Call about 123 45 6789', 'Call about [REDACTED]'],
          # Emails
          ['Contact: john@example.com', 'Contact: [REDACTED]'],
          ['test.email+tag@domain.co.uk', '[REDACTED]'],
          ['EMAIL: USER@COMPANY.COM', 'EMAIL: [REDACTED]'],
          # Phones
          ['Call me at (555) 123-4567', 'Call me at [REDACTED]'],
          ['Phone: 555-123-4567', 'Phone: [REDACTED]'],
          ['Number: +1-555-123-4567', 'Number: [REDACTED]'],
          ['Contact: 5551234567', 'Contact: [REDACTED]'],
          # Credit cards
          ['Card: 4444-4444-4444-4444', 'Card: [REDACTED]'],
          ['CC: 4444 4444 4444 4444', 'CC: [REDACTED]'],
          ['4444444444444444', '[REDACTED]'],
          # ZIP codes, file numbers, birth dates
          ['ZIP: 12345', 'ZIP: [REDACTED]'],
          ['Postal: 12345-6789', 'Postal: [REDACTED]'],
          ['File: C12345678', 'File: [REDACTED]'],
          ['VA File: C-12345678', 'VA File: [REDACTED]'],
          ['Number: 123456789', 'Number: [REDACTED]'],
          ['Routing: 123456789', 'Routing: [REDACTED]'],
          ['Born: 01/15/1985', 'Born: [REDACTED]'],
          ['DOB: 1-15-1985', 'DOB: [REDACTED]'],
          ['Birthday: 01.15.1985', 'Birthday: [REDACTED]'],
          ['Date: 12/31/2000', 'Date: [REDACTED]'],
          ['EDIPI: 1234567890', 'EDIPI: [REDACTED]'],
          ['Participant: 12345678', 'Participant: [REDACTED]'],
          ['ID: 1234567890', 'ID: [REDACTED]'],
          ['ICN: 1234567890V123456', 'ICN: [REDACTED]'],
          # Multiple PII
          ['Contact John at john@email.com or 555-123-4567, SSN: 123-45-6789',
           'Contact John at [REDACTED] or [REDACTED], SSN: [REDACTED]']
        ]

        safe_content_cases = ['Hello world', 'Order #12345', '', '   ']

        it 'scrubs PII in strings' do
          pii_test_cases.each do |input, expected|
            expect(described_class.scrub(input)).to eq(expected)
          end
        end

        it 'preserves safe content and handles edge cases' do
          safe_content_cases.each do |safe_input|
            expect(described_class.scrub(safe_input)).to eq(safe_input)
          end
          expect(described_class.scrub(nil)).to be_nil
        end
      end

      context 'with hash data' do
        let(:input_hash) do
          {
            name: 'John Doe', ssn: '123-45-6789', email: 'john@example.com', safe_data: 'This is safe',
            user: { contact: { email: 'test@example.com', phone: '555-123-4567' }, personal: { ssn: '123-45-6789' } }
          }
        end

        let(:expected_hash) do
          {
            name: 'John Doe', ssn: redaction, email: redaction, safe_data: 'This is safe',
            user: { contact: { email: redaction, phone: redaction }, personal: { ssn: redaction } }
          }
        end

        it 'scrubs PII in nested hash structures' do
          expect(described_class.scrub(input_hash)).to eq(expected_hash)
        end

        it 'handles mixed data types in hash values' do
          mixed_input = { string_with_pii: 'SSN: 123-45-6789', number: '42', boolean: true, nil_value: nil }
          expected = { string_with_pii: "SSN: #{redaction}", number: '42', boolean: true, nil_value: nil }
          expect(described_class.scrub(mixed_input)).to eq(expected)
        end
      end

      context 'with array data' do
        it 'scrubs PII in array elements and nested structures' do
          input = ['Contact: john@example.com', 'Safe data', '42', [['email@test.com'], [123, 'ssn: 123-45-6789']]]
          expected = ["Contact: #{redaction}", 'Safe data', '42', [[redaction], [123, "ssn: #{redaction}"]]]
          expect(described_class.scrub(input)).to eq(expected)
        end

        it 'handles arrays with hashes' do
          input = [{ email: 'test@example.com' }, { contact: { phone: '555-123-4567' } }]
          expected = [{ email: redaction }, { contact: { phone: redaction } }]
          expect(described_class.scrub(input)).to eq(expected)
        end
      end

      context 'with complex nested structures' do
        it 'handles deeply nested hash and array combinations' do
          input = {
            users: [
              { name: 'John Doe', contacts: ['john@email.com', '555-123-4567'],
                metadata: { ssn: '123-45-6789', notes: 'Regular user' } },
              { name: 'Jane Smith', contacts: ['jane@email.com'],
                metadata: { participant_id: '1234567890', notes: 'VIP user' } }
            ],
            system_info: { version: '1.0.0', logs: ['User logged in', 'Credit card: 4444-4444-4444-4444'] }
          }

          expected = {
            users: [
              { name: 'John Doe', contacts: [redaction, redaction],
                metadata: { ssn: redaction, notes: 'Regular user' } },
              { name: 'Jane Smith', contacts: [redaction], metadata: { participant_id: redaction, notes: 'VIP user' } }
            ],
            system_info: { version: '1.0.0', logs: ['User logged in', "Credit card: #{redaction}"] }
          }

          expect(described_class.scrub(input)).to eq(expected)
        end
      end

      context 'with non-string, non-collection types' do
        it 'preserves nil, true, false unchanged' do
          expect(described_class.scrub(nil)).to be_nil
          expect(described_class.scrub(true)).to be(true)
          expect(described_class.scrub(false)).to be(false)
        end

        it 'converts other types to strings and scrubs for PII' do
          # Numbers that look like PII should be scrubbed
          expect(described_class.scrub(123_456_789)).to eq('[REDACTED]') # SSN without dashes
          expect(described_class.scrub(5_551_234_567)).to eq('[REDACTED]') # Phone number
          expect(described_class.scrub(4_444_444_444_444_444)).to eq('[REDACTED]') # Credit card
          expect(described_class.scrub(12_345)).to eq('[REDACTED]') # ZIP code

          # Numbers that don't look like PII should remain as numbers
          expect(described_class.scrub(42)).to eq(42)
          expect(described_class.scrub(3.14)).to eq(3.14)

          # Symbols should be converted to strings and scrubbed only if they contain PII
          expect(described_class.scrub(:symbol)).to eq(:symbol)
          expect(described_class.scrub(:'123-45-6789')).to eq('[REDACTED]')
        end
      end
    end

    context 'when logging_data_scrubber flipper is disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(false) }

      let(:test_inputs) do
        [
          'SSN: 123-45-6789, Email: test@example.com',
          { ssn: '123-45-6789', email: 'test@example.com' },
          ['SSN: 123-45-6789', 'Email: test@example.com'],
          { user: { contacts: ['test@example.com', '555-123-4567'] } }
        ]
      end

      it 'returns all data unchanged when flipper is disabled' do
        test_inputs.each do |input|
          expect(described_class.scrub(input)).to eq(input)
        end
      end
    end

    context 'with UUID preservation' do
      let(:test_uuid) { '65ad9cdf-4a1a-45a5-8526-4e36b2fb92a1' }
      let(:all_digit_uuid) { '12345678-1234-1234-1234-123456789012' }

      it 'preserves UUIDs even when segments match PII patterns' do
        uuid_test_cases = [
          # UUIDs with segments that could match PII patterns
          ["User ID: #{test_uuid}", "User ID: #{test_uuid}"],
          ["Processing #{all_digit_uuid} for claim", "Processing #{all_digit_uuid} for claim"],
          ["UUID: #{test_uuid} - SSN: 123-45-6789", "UUID: #{test_uuid} - SSN: [REDACTED]"],
          # Multiple UUIDs with other PII
          ["UUIDs #{test_uuid} and #{all_digit_uuid}, email: john@test.com",
           "UUIDs #{test_uuid} and #{all_digit_uuid}, email: [REDACTED]"],
          # UUID in data structures
          [{ user_uuid: test_uuid, ssn: '123-45-6789' },
           { user_uuid: test_uuid, ssn: '[REDACTED]' }]
        ]

        uuid_test_cases.each do |input, expected|
          expect(described_class.scrub(input)).to eq(expected)
        end
      end

      it 'still scrubs standalone numeric patterns that are not part of UUIDs' do
        standalone_cases = [
          ['Standalone SSN: 123-45-6789', 'Standalone SSN: [REDACTED]'],
          ['Phone: 555-123-4567', 'Phone: [REDACTED]'],
          ['EDIPI: 1234567890', 'EDIPI: [REDACTED]'],
          ['ZIP: 12345', 'ZIP: [REDACTED]']
        ]

        standalone_cases.each do |input, expected|
          expect(described_class.scrub(input)).to eq(expected)
        end
      end
    end
  end

  describe 'regex patterns' do
    before { allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(true) }

    # Test cases: { pattern_name => { valid: [], invalid: [] } }
    regex_test_cases = {
      'SSN' => {
        valid: ['123-45-6789', '123456789', '123 45 6789'],
        invalid: %w[12-34-5678 1234-56-789 abc-de-fghi]
      },
      'EMAIL' => {
        valid: ['user@example.com', 'test.email+tag@domain.co.uk', 'USER@COMPANY.COM'],
        invalid: ['invalid.email', '@domain.com', 'user@']
      },
      'PHONE' => {
        valid: ['(555) 123-4567', '555-123-4567', '+1-555-123-4567', '5551234567'],
        invalid: %w[555-123 1234567890123 abc-def-ghij]
      },
      'CREDIT_CARD' => {
        valid: ['4444-4444-4444-4444', '4444 4444 4444 4444', '4444444444444444'],
        invalid: %w[4444-4444-4444 4444-4444-4444-44444 444-444-444-444]
      },
      'VA_FILE_NUMBER' => {
        valid: %w[C12345678 C-12345678 123456789 12345678],
        invalid: %w[C1234567 C1234567890 1234567 D12345678]
      },
      'ROUTING_NUMBER' => {
        valid: %w[123456789 987654321 111000025],
        invalid: %w[1234567 12345678900 abcdefghi]
      },
      'BIRTH_DATE' => {
        valid: ['01/15/1985', '1/15/1985', '12/31/2000', '01.15.1985'],
        invalid: ['13/15/1985', '01/32/1985', '01/15/1899', '2023-01-15']
      },
      'EDIPI' => {
        valid: %w[1234567890 9876543210 1111111111],
        invalid: %w[1234567 12345678901 abcdefghij]
      },
      'PARTICIPANT_ID' => {
        valid: %w[12345678 123456789 1234567890],
        invalid: %w[1234567 12345678901 abcdefgh]
      },
      'ICN' => {
        valid: %w[1234567890V123456 9876543210V654321 1111111111V111111],
        invalid: %w[123456789V123456 1234567890V12345 1234567890X123456]
      },
      'ZIP_CODE' => {
        valid: %w[12345 12345-6789],
        invalid: %w[1234 123456 12345-678]
      }
    }

    regex_test_cases.each do |pattern_name, test_data|
      describe "#{pattern_name}_REGEX" do
        it 'matches valid formats and rejects invalid ones' do
          test_data[:valid].each { |valid_input| expect(described_class.scrub(valid_input)).to eq(redaction) }
          test_data[:invalid].each { |invalid_input| expect(described_class.scrub(invalid_input)).to eq(invalid_input) }
        end
      end
    end
  end
end
