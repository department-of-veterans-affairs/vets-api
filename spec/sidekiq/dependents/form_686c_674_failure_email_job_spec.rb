# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dependents::Form686c674FailureEmailJob, type: :job do
  let(:job) { described_class.new }
  let(:claim_id) { 123 }
  let(:email) { 'test@example.com' }
  let(:template_id) { 'test-template-id' }
  let(:claim) do
    instance_double(
      'SavedClaim::DependencyClaim',
      form_id: described_class::FORM_ID,
      confirmation_number: 'ABCD1234',
      parsed_form: {
        'veteran_information' => {
          'full_name' => {
            'first' => 'John'
          }
        }
      }
    )
  end
  let(:va_notify_client) { instance_double('VaNotify::Service') }

  describe '#perform' do
    before do
      allow(SavedClaim::DependencyClaim).to receive(:find).with(claim_id).and_return(claim)
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_client)
      allow(va_notify_client).to receive(:send_email)
      allow(Rails.logger).to receive(:warn)
    end

    it 'sends an email with the correct parameters' do
      expect(va_notify_client).to receive(:send_email).with(
        email_address: email,
        template_id: template_id,
        personalisation: {
          'first_name' => 'JOHN',
          'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => 'ABCD1234'
        }
      )

      job.perform(claim_id, email, template_id)
    end

    context 'when an error occurs' do
      before do
        allow(va_notify_client).to receive(:send_email).and_raise(StandardError.new('Test error'))
      end

      it 'logs the error and allows retry' do
        expect(Rails.logger).to receive(:warn).with(
          'Form686c674FailureEmailJob failed, retrying send...',
          { claim_id: claim_id, error: instance_of(StandardError) }
        )

        # Should not raise error
        expect { job.perform(claim_id, email, template_id) }.not_to raise_error
      end
    end
  end

  describe 'sidekiq_retries_exhausted' do
    it 'logs an error when retries are exhausted' do
      msg = { 'args' => [claim_id] }
      ex = StandardError.new('Test exhausted error')

      expect(Rails.logger).to receive(:error).with(
        'Form686c674FailureEmailJob exhausted all retries',
        {
          saved_claim_id: claim_id,
          error_message: 'Test exhausted error'
        }
      )

      described_class.sidekiq_retries_exhausted_block.call(msg, ex)
    end
  end

  describe '#va_notify_client' do
    before do
      allow(SavedClaim::DependencyClaim).to receive(:find).with(claim_id).and_return(claim)
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_client)
      allow(Settings).to receive_message_chain(:vanotify, :services, :va_gov, :api_key).and_return('test-api-key')
    end

    it 'initializes VaNotify::Service with correct parameters' do
      expected_callback_options = {
        callback_metadata: {
          notification_type: 'error',
          form_id: described_class::FORM_ID,
          statsd_tags: { service: 'dependent-change', function: described_class::ZSF_DD_TAG_FUNCTION }
        }
      }

      expect(VaNotify::Service).to receive(:new).with('test-api-key', expected_callback_options)

      # Just allow the job to execute, which should create the client
      allow(va_notify_client).to receive(:send_email)
      job.perform(claim_id, email, template_id)
    end
  end

  describe '#personalisation' do
    before do
      allow(SavedClaim::DependencyClaim).to receive(:find).with(claim_id).and_return(claim)
      allow(Time.zone).to receive_message_chain(:today, :strftime).and_return('January 01, 2023')
      # Create the service but don't set expectations on send_email yet
      allow(VaNotify::Service).to receive(:new).and_return(va_notify_client)
    end

    it 'sends correct personalisation data in the email' do
      # Instead of directly calling the private method, test what gets sent to va_notify_client
      expect(va_notify_client).to receive(:send_email).with(
        email_address: email,
        template_id: template_id,
        personalisation: {
          'first_name' => 'JOHN',
          'date_submitted' => 'January 01, 2023',
          'confirmation_number' => 'ABCD1234'
        }
      )

      job.perform(claim_id, email, template_id)
    end

    context 'when first name is nil' do
      let(:claim) do
        instance_double(
          'SavedClaim::DependencyClaim',
          form_id: described_class::FORM_ID,
          confirmation_number: 'ABCD1234',
          parsed_form: {
            'veteran_information' => {
              'full_name' => {
                'first' => nil
              }
            }
          }
        )
      end

      it 'handles nil first_name gracefully' do
        expect(va_notify_client).to receive(:send_email).with(
          email_address: email,
          template_id: template_id,
          personalisation: hash_including('first_name' => nil)
        )

        job.perform(claim_id, email, template_id)
      end
    end
  end
end
