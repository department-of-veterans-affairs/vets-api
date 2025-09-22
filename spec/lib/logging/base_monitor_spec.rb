# frozen_string_literal: true

require 'rails_helper'
require 'logging/base_monitor'

class TestMonitor < Logging::BaseMonitor
  def service_name
    'TestService'
  end

  def claim_stats_key
    'test.claim.stats'
  end

  def submission_stats_key
    'test.submission.stats'
  end

  def name
    'TestName'
  end

  def form_id
    '12345'
  end
end

RSpec.describe Logging::BaseMonitor do
  let(:base_monitor) { TestMonitor.new('test-application') }

  describe 'included modules' do
    it 'includes Logging::Controller::Monitor' do
      expect(described_class.included_modules).to include(Logging::Controller::Monitor)
    end

    it 'includes Logging::BenefitsIntake::Monitor' do
      expect(described_class.included_modules).to include(Logging::BenefitsIntake::Monitor)
    end
  end

  describe '#message_prefix' do
    it 'returns the correct message prefix' do
      expect(base_monitor.send(:message_prefix)).to eq('TestName 12345')
    end
  end

  describe '#submit_event' do
    before do
      allow(Flipper).to receive(:enabled?).with(:logging_data_scrubber).and_return(true)
    end

    it 'calls track_request with the correct arguments' do
      allow(base_monitor).to receive(:track_request)
      base_monitor.send(:submit_event, 'info', 'Test message', 'test.stats.key',
                        claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                        user_account_uuid: 'uuid-123')

      expect(base_monitor).to have_received(:track_request).with(
        'info',
        'Test message',
        'test.stats.key',
        call_location: anything,
        confirmation_number: 'ABC123',
        user_account_uuid: 'uuid-123',
        claim_id: 1,
        form_id: '12345',
        tags: anything
      )
    end

    context 'data scrubbing behavior' do
      let(:claim_with_pii) { double(id: 1, confirmation_number: 'SSN-123-45-6789', form_id: 'email@test.com') }
      let(:user_uuid_with_pii) { 'uuid-with-phone-555-123-4567' }

      it 'does NOT scrub protected fields: confirmation_number, user_account_uuid, claim_id, form_id' do
        allow(base_monitor).to receive(:track_request)

        base_monitor.send(:submit_event, 'info', 'Test message', 'test.stats.key',
                          claim: claim_with_pii, user_account_uuid: user_uuid_with_pii)

        expect(base_monitor).to have_received(:track_request).with(
          'info',
          'Test message',
          'test.stats.key',
          call_location: anything,
          confirmation_number: 'SSN-123-45-6789', # NOT scrubbed
          user_account_uuid: 'uuid-with-phone-555-123-4567', # NOT scrubbed
          claim_id: 1, # NOT scrubbed
          form_id: 'email@test.com', # NOT scrubbed
          tags: [] # Empty when no @tags set
        )
      end

      it 'does not scrub tags field when passed in options' do
        allow(base_monitor).to receive(:track_request)

        base_monitor.send(:submit_event, 'info', 'Test message', 'test.stats.key',
                          claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                          user_account_uuid: 'clean-uuid',
                          tags: ['service:dependents'])

        expect(base_monitor).to have_received(:track_request).with(
          'info',
          'Test message',
          'test.stats.key',
          call_location: anything,
          confirmation_number: 'ABC123',
          user_account_uuid: 'clean-uuid',
          claim_id: 1,
          form_id: '12345',
          tags: ['service:dependents']
        )
      end

      it 'does NOT scrub instance variable @tags' do
        allow(base_monitor).to receive(:track_request)
        base_monitor.instance_variable_set(:@tags, ['tag-with-ssn-123-45-6789'])

        base_monitor.send(:submit_event, 'info', 'Test message', 'test.stats.key',
                          claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                          user_account_uuid: 'clean-uuid')

        expect(base_monitor).to have_received(:track_request).with(
          'info',
          'Test message',
          'test.stats.key',
          call_location: anything,
          confirmation_number: 'ABC123',
          user_account_uuid: 'clean-uuid',
          claim_id: 1,
          form_id: '12345',
          tags: ['tag-with-ssn-123-45-6789'] # NOT scrubbed when from @tags
        )
      end

      it 'DOES scrub additional_context fields containing PII' do
        allow(base_monitor).to receive(:track_request)

        base_monitor.send(:submit_event, 'error', 'Test error', 'test.stats.key',
                          claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                          user_account_uuid: 'clean-uuid',
                          error: 'Error with SSN: 123-45-6789',
                          errors: ['Phone: 555-123-4567', 'Email: user@example.com'],
                          icn: '1234567890V123456',
                          debug_info: 'Credit card: 4444-4444-4444-4444')

        expect(base_monitor).to have_received(:track_request).with(
          'error',
          'Test error',
          'test.stats.key',
          call_location: anything,
          confirmation_number: 'ABC123',
          user_account_uuid: 'clean-uuid',
          claim_id: 1,
          form_id: '12345',
          tags: anything,
          error: 'Error with SSN: [REDACTED]', # Scrubbed
          errors: ['Phone: [REDACTED]', 'Email: [REDACTED]'], # Scrubbed
          icn: '[REDACTED]', # Scrubbed
          debug_info: 'Credit card: [REDACTED]' # Scrubbed
        )
      end

      it 'handles nested data structures in additional_context' do
        allow(base_monitor).to receive(:track_request)

        base_monitor.send(:submit_event, 'warn', 'Test warning', 'test.stats.key',
                          claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                          user_account_uuid: 'clean-uuid',
                          response_data: {
                            user_info: { email: 'test@example.com', phone: '555-123-4567' },
                            validation_errors: ['Invalid SSN: 123-45-6789']
                          })

        expect(base_monitor).to have_received(:track_request).with(
          'warn',
          'Test warning',
          'test.stats.key',
          call_location: anything,
          confirmation_number: 'ABC123',
          user_account_uuid: 'clean-uuid',
          claim_id: 1,
          form_id: '12345',
          tags: anything,
          response_data: {
            user_info: { email: '[REDACTED]', phone: '[REDACTED]' },
            validation_errors: ['Invalid SSN: [REDACTED]']
          }
        )
      end

      it 'preserves non-PII data in additional_context' do
        allow(base_monitor).to receive(:track_request)

        base_monitor.send(:submit_event, 'info', 'Test info', 'test.stats.key',
                          claim: double(id: 1, confirmation_number: 'ABC123', form_id: '12345'),
                          user_account_uuid: 'clean-uuid',
                          status: 'completed',
                          response_code: 200,
                          message: 'Operation successful',
                          metadata: { version: '1.0.0', timestamp: '2025-01-01' })

        expect(base_monitor).to have_received(:track_request).with(
          'info',
          'Test info',
          'test.stats.key',
          call_location: anything,
          confirmation_number: 'ABC123',
          user_account_uuid: 'clean-uuid',
          claim_id: 1,
          form_id: '12345',
          tags: anything,
          status: 'completed',                         # NOT scrubbed
          response_code: 200,                          # NOT scrubbed
          message: 'Operation successful',             # NOT scrubbed
          metadata: { version: '1.0.0', timestamp: '2025-01-01' } # NOT scrubbed
        )
      end
    end
  end
end
