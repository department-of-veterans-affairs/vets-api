# frozen_string_literal: true

require 'rails_helper'
require 'logging/data_scrubber'

RSpec.describe Logging::DataScrubber do
  let(:redaction) { '[REDACTED]' }

  describe '.scrub' do
    context 'when logging_data_scrubber flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(true)
      end

      context 'with string data' do
        it 'scrubs SSNs in various formats' do
          expect(described_class.scrub('My SSN is 123-45-6789')).to eq("My SSN is #{redaction}")
          expect(described_class.scrub('SSN: 123456789')).to eq("SSN: #{redaction}")
          expect(described_class.scrub('Call about 123 45 6789')).to eq("Call about #{redaction}")
        end

        it 'scrubs email addresses' do
          expect(described_class.scrub('Contact: john@example.com')).to eq("Contact: #{redaction}")
          expect(described_class.scrub('test.email+tag@domain.co.uk')).to eq(redaction)
          expect(described_class.scrub('EMAIL: USER@COMPANY.COM')).to eq("EMAIL: #{redaction}")
        end

        it 'scrubs phone numbers in various formats' do
          expect(described_class.scrub('Call me at (555) 123-4567')).to eq("Call me at #{redaction}")
          expect(described_class.scrub('Phone: 555-123-4567')).to eq("Phone: #{redaction}")
          expect(described_class.scrub('Number: +1-555-123-4567')).to eq("Number: #{redaction}")
          expect(described_class.scrub('Contact: 5551234567')).to eq("Contact: #{redaction}")
        end

        it 'scrubs credit card numbers' do
          expect(described_class.scrub('Card: 4444-4444-4444-4444')).to eq("Card: #{redaction}")
          expect(described_class.scrub('CC: 4444 4444 4444 4444')).to eq("CC: #{redaction}")
          expect(described_class.scrub('4444444444444444')).to eq(redaction)
        end

        it 'scrubs ZIP codes' do
          expect(described_class.scrub('ZIP: 12345')).to eq("ZIP: #{redaction}")
          expect(described_class.scrub('Postal: 12345-6789')).to eq("Postal: #{redaction}")
        end

        it 'scrubs VA file numbers' do
          expect(described_class.scrub('File: C12345678')).to eq("File: #{redaction}")
          expect(described_class.scrub('VA File: C-12345678')).to eq("VA File: #{redaction}")
          expect(described_class.scrub('Number: 123456789')).to eq("Number: #{redaction}")
        end

        it 'scrubs bank routing numbers' do
          expect(described_class.scrub('Routing: 123456789')).to eq("Routing: #{redaction}")
        end

        it 'scrubs birth dates' do
          expect(described_class.scrub('Born: 01/15/1985')).to eq("Born: #{redaction}")
          expect(described_class.scrub('DOB: 1-15-1985')).to eq("DOB: #{redaction}")
          expect(described_class.scrub('Birthday: 01.15.1985')).to eq("Birthday: #{redaction}")
          expect(described_class.scrub('Date: 12/31/2000')).to eq("Date: #{redaction}")
        end

        it 'scrubs EDIPI numbers' do
          expect(described_class.scrub('EDIPI: 1234567890')).to eq("EDIPI: #{redaction}")
        end

        it 'scrubs participant IDs' do
          expect(described_class.scrub('Participant: 12345678')).to eq("Participant: #{redaction}")
          expect(described_class.scrub('ID: 1234567890')).to eq("ID: #{redaction}")
        end

        it 'scrubs ICN numbers' do
          expect(described_class.scrub('ICN: 1234567890V123456')).to eq("ICN: #{redaction}")
        end

        it 'scrubs multiple PII types in one string' do
          input = 'Contact John at john@email.com or 555-123-4567, SSN: 123-45-6789'
          expected = "Contact John at #{redaction} or #{redaction}, SSN: #{redaction}"
          expect(described_class.scrub(input)).to eq(expected)
        end

        it 'returns blank strings unchanged' do
          expect(described_class.scrub('')).to eq('')
          expect(described_class.scrub('   ')).to eq('   ')
          expect(described_class.scrub(nil)).to be_nil
        end

        it 'preserves non-PII content' do
          expect(described_class.scrub('Hello world')).to eq('Hello world')
          expect(described_class.scrub('Order #12345')).to eq('Order #12345')
        end
      end

      context 'with hash data' do
        it 'scrubs PII in hash values while preserving keys' do
          input = {
            name: 'John Doe',
            ssn: '123-45-6789',
            email: 'john@example.com',
            safe_data: 'This is safe'
          }

          expected = {
            name: 'John Doe',
            ssn: redaction,
            email: redaction,
            safe_data: 'This is safe'
          }

          expect(described_class.scrub(input)).to eq(expected)
        end

        it 'handles nested hashes' do
          input = {
            user: {
              contact: {
                email: 'test@example.com',
                phone: '555-123-4567'
              },
              personal: {
                ssn: '123-45-6789'
              }
            }
          }

          expected = {
            user: {
              contact: {
                email: redaction,
                phone: redaction
              },
              personal: {
                ssn: redaction
              }
            }
          }

          expect(described_class.scrub(input)).to eq(expected)
        end

        it 'handles mixed data types in hash values' do
          input = {
            string_with_pii: 'SSN: 123-45-6789',
            number: 42,
            boolean: true,
            nil_value: nil,
            safe_string: 'Hello world'
          }

          expected = {
            string_with_pii: "SSN: #{redaction}",
            number: 42,
            boolean: true,
            nil_value: nil,
            safe_string: 'Hello world'
          }

          expect(described_class.scrub(input)).to eq(expected)
        end
      end

      context 'with array data' do
        it 'scrubs PII in array elements' do
          input = [
            'Contact: john@example.com',
            'SSN: 123-45-6789',
            'Safe data',
            42
          ]

          expected = [
            "Contact: #{redaction}",
            "SSN: #{redaction}",
            'Safe data',
            42
          ]

          expect(described_class.scrub(input)).to eq(expected)
        end

        it 'handles nested arrays' do
          input = [
            ['email@test.com', 'phone: 555-1234'],
            [123, 'ssn: 123-45-6789']
          ]

          expected = [
            [redaction, "phone: #{redaction}"],
            [123, "ssn: #{redaction}"]
          ]

          expect(described_class.scrub(input)).to eq(expected)
        end

        it 'handles arrays with hashes' do
          input = [
            { email: 'test@example.com' },
            { contact: { phone: '555-123-4567' } }
          ]

          expected = [
            { email: redaction },
            { contact: { phone: redaction } }
          ]

          expect(described_class.scrub(input)).to eq(expected)
        end
      end

      context 'with complex nested structures' do
        it 'handles deeply nested hash and array combinations' do
          input = {
            users: [
              {
                name: 'John Doe',
                contacts: ['john@email.com', '555-123-4567'],
                metadata: {
                  ssn: '123-45-6789',
                  notes: 'Regular user'
                }
              },
              {
                name: 'Jane Smith',
                contacts: ['jane@email.com'],
                metadata: {
                  participant_id: '1234567890',
                  notes: 'VIP user'
                }
              }
            ],
            system_info: {
              version: '1.0.0',
              logs: ['User logged in', 'Credit card: 4444-4444-4444-4444']
            }
          }

          expected = {
            users: [
              {
                name: 'John Doe',
                contacts: [redaction, redaction],
                metadata: {
                  ssn: redaction,
                  notes: 'Regular user'
                }
              },
              {
                name: 'Jane Smith',
                contacts: [redaction],
                metadata: {
                  participant_id: redaction,
                  notes: 'VIP user'
                }
              }
            ],
            system_info: {
              version: '1.0.0',
              logs: ['User logged in', "Credit card: #{redaction}"]
            }
          }

          expect(described_class.scrub(input)).to eq(expected)
        end
      end

      context 'with non-string, non-collection types' do
        it 'returns numbers unchanged' do
          expect(described_class.scrub(42)).to eq(42)
          expect(described_class.scrub(3.14)).to eq(3.14)
        end

        it 'returns booleans unchanged' do
          expect(described_class.scrub(true)).to be(true)
          expect(described_class.scrub(false)).to be(false)
        end

        it 'returns nil unchanged' do
          expect(described_class.scrub(nil)).to be_nil
        end

        it 'returns symbols unchanged' do
          expect(described_class.scrub(:symbol)).to eq(:symbol)
        end
      end
    end

    context 'when logging_data_scrubber flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(false)
      end

      it 'returns data unchanged for strings with PII' do
        input = 'SSN: 123-45-6789, Email: test@example.com'
        expect(described_class.scrub(input)).to eq(input)
      end

      it 'returns data unchanged for hashes with PII' do
        input = { ssn: '123-45-6789', email: 'test@example.com' }
        expect(described_class.scrub(input)).to eq(input)
      end

      it 'returns data unchanged for arrays with PII' do
        input = ['SSN: 123-45-6789', 'Email: test@example.com']
        expect(described_class.scrub(input)).to eq(input)
      end

      it 'returns data unchanged for complex nested structures' do
        input = {
          user: {
            contacts: ['test@example.com', '555-123-4567']
          }
        }
        expect(described_class.scrub(input)).to eq(input)
      end
    end
  end

  describe 'regex patterns' do
    before do
      allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(true)
    end

    describe 'SSN_REGEX' do
      it 'matches valid SSN formats' do
        ['123-45-6789', '123456789', '123 45 6789'].each do |ssn|
          expect(described_class.scrub(ssn)).to eq(redaction)
        end
      end

      it 'does not match invalid SSN formats' do
        %w[12-34-5678 1234-56-789 abc-de-fghi].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'EMAIL_REGEX' do
      it 'matches valid email formats' do
        [
          'user@example.com',
          'test.email+tag@domain.co.uk',
          'USER@COMPANY.COM',
          'user123@test-domain.com'
        ].each do |email|
          expect(described_class.scrub(email)).to eq(redaction)
        end
      end

      it 'does not match invalid email formats' do
        ['invalid.email', '@domain.com', 'user@'].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'PHONE_REGEX' do
      it 'matches valid phone formats' do
        [
          '(555) 123-4567',
          '555-123-4567',
          '+1-555-123-4567',
          '5551234567',
          '1 555 123 4567'
        ].each do |phone|
          expect(described_class.scrub(phone)).to eq(redaction)
        end
      end

      it 'does not match invalid phone formats' do
        %w[555-123 1234567890123 abc-def-ghij].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'CREDIT_CARD_REGEX' do
      it 'matches valid credit card formats' do
        [
          '4444-4444-4444-4444',
          '4444 4444 4444 4444',
          '4444444444444444',
          '1234-5678-9012-3456',
          '1234 5678 9012 3456'
        ].each do |cc|
          expect(described_class.scrub(cc)).to eq(redaction)
        end
      end

      it 'does not match invalid credit card formats' do
        %w[4444-4444-4444 4444-4444-4444-44444 444-444-444-444].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'VA_FILE_NUMBER_REGEX' do
      it 'matches valid VA file number formats' do
        %w[
          C12345678
          C-12345678
          123456789
          12345678
          C123456789
        ].each do |file_num|
          expect(described_class.scrub(file_num)).to eq(redaction)
        end
      end

      it 'does not match invalid VA file number formats' do
        %w[C1234567 C1234567890 1234567 D12345678].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'ROUTING_NUMBER_REGEX' do
      it 'matches valid routing number formats' do
        %w[123456789 987654321 111000025].each do |routing|
          expect(described_class.scrub(routing)).to eq(redaction)
        end
      end

      it 'does not match invalid routing number formats' do
        %w[1234567 12345678900 abcdefghi].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'BIRTH_DATE_REGEX' do
      it 'matches valid birth date formats' do
        [
          '01/15/1985',
          '1/15/1985',
          '12/31/2000',
          '1-15-1985',
          '01-15-1985',
          '12-31-2000',
          '01.15.1985',
          '1.15.1985',
          '12.31.2000',
          '2/29/2000',
          '02/29/2000'
        ].each do |date|
          expect(described_class.scrub(date)).to eq(redaction)
        end
      end

      it 'does not match invalid birth date formats' do
        [
          '13/15/1985',   # Invalid month
          '01/32/1985',   # Invalid day
          '01/15/1899',   # Year too old
          '01/15/2100',   # Year too new
          '1/1/85',       # 2-digit year
          '2023-01-15',   # Wrong format
          '15/01/1985'    # Day/month reversed
        ].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'EDIPI_REGEX' do
      it 'matches valid EDIPI formats' do
        %w[1234567890 9876543210 1111111111].each do |edipi|
          expect(described_class.scrub(edipi)).to eq(redaction)
        end
      end

      it 'does not match invalid EDIPI formats' do
        %w[1234567 12345678901 abcdefghij].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'PARTICIPANT_ID_REGEX' do
      it 'matches valid participant ID formats' do
        [
          '12345678',    # 8 digits
          '123456789',   # 9 digits
          '1234567890'   # 10 digits
        ].each do |participant_id|
          expect(described_class.scrub(participant_id)).to eq(redaction)
        end
      end

      it 'does not match invalid participant ID formats' do
        %w[1234567 12345678901 abcdefgh].each do |invalid|
          expect(described_class.scrub(invalid)).to eq(invalid)
        end
      end
    end

    describe 'ICN_REGEX' do
      it 'matches valid ICN formats' do
        %w[
          1234567890V123456
          9876543210V654321
          1111111111V111111
        ].each do |icn|
          expect(described_class.scrub(icn)).to eq(redaction)
        end
      end

      it 'does not match invalid ICN formats' do
        [
          '123456789V123456',   # Too few digits before V
          '12345678901V123456', # Too many digits before V
          '1234567890V12345',   # Too few digits after V
          '1234567890V1234567', # Too many digits after V
          '1234567890X123456',  # Wrong separator
          '1234567890v123456'   # Lowercase v
        ].each do |invalid|
          expect(described_class.scrub(invalid)).to be(invalid)
        end
      end
    end

    describe 'ZIP_CODE_REGEX' do
      it 'matches valid ZIP code formats' do
        %w[12345 12345-6789].each do |zip|
          expect(described_class.scrub(zip)).to eq(redaction)
        end
      end

      it 'does not match invalid ZIP formats' do
        %w[1234 123456 12345-678].each do |invalid|
          expect(described_class.scrub(invalid)).to be(invalid)
        end
      end
    end
  end
end
