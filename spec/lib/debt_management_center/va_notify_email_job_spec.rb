# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'debt_management_center/sidekiq/va_notify_email_job'

RSpec.describe DebtManagementCenter::VANotifyEmailJob, type: :worker do
  let(:template_id) { 'template-123' }
  let(:va_notify_client) { instance_double(VaNotify::Service) }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(va_notify_client)
    allow(va_notify_client).to receive(:send_email)
    allow(Sidekiq::AttrPackage).to receive(:delete)
  end

  describe '#perform' do
    describe 'cache_key and plain_pii' do
      context 'when options have no cache_key (not using cache)' do
        it 'decrypts identifier and personalisation first_name before sending to VaNotify' do
          encrypted_email = DebtsApi::EncryptionService.encrypt('veteran@va.gov')
          encrypted_first_name = DebtsApi::EncryptionService.encrypt('Jane')

          expect(va_notify_client).to receive(:send_email).with(
            hash_including(
              email_address: 'veteran@va.gov',
              template_id:,
              personalisation: hash_including('first_name' => 'Jane')
            )
          )

          described_class.new.perform(
            encrypted_email,
            template_id,
            { 'first_name' => encrypted_first_name, 'date_submitted' => '01/15/2025' },
            { 'id_type' => 'email' }
          )
        end

        it 'uses identifier and first_name as-is when already plain (rescue InvalidMessage)' do
          expect(va_notify_client).to receive(:send_email).with(
            hash_including(
              email_address: 'plain@example.com',
              personalisation: hash_including('first_name' => 'PlainName')
            )
          )

          described_class.new.perform(
            'plain@example.com',
            template_id,
            { 'first_name' => 'PlainName' },
            { 'id_type' => 'email' }
          )
        end

        it 'does not call AttrPackage.find' do
          expect(Sidekiq::AttrPackage).not_to receive(:find)

          described_class.new.perform(
            'user@example.com',
            template_id,
            { 'first_name' => 'Test' },
            { 'id_type' => 'email' }
          )
        end
      end

      context 'when options have cache_key (using cache)' do
        let(:cache_key) { 'cache_key_abc' }

        it 'fetches identifier and personalisation from AttrPackage and sends them to VaNotify' do
          allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(
            email: 'cached@example.com',
            personalisation: { 'first_name' => 'CachedFirst', 'date_submitted' => '01/01/2025' }
          )

          expect(va_notify_client).to receive(:send_email).with(
            hash_including(
              email_address: 'cached@example.com',
              template_id:,
              personalisation: hash_including('first_name' => 'CachedFirst')
            )
          )

          described_class.new.perform(
            nil,
            template_id,
            nil,
            { 'cache_key' => cache_key, 'id_type' => 'email' }
          )
        end

        it 'calls AttrPackage.find with the cache_key' do
          allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(
            email: 'cached@example.com',
            personalisation: { 'first_name' => 'Cached' }
          )

          expect(Sidekiq::AttrPackage).to receive(:find).with(cache_key)

          described_class.new.perform(nil, template_id, nil, { 'cache_key' => cache_key, 'id_type' => 'email' })
        end

        it 'raises AttrPackageError when cache_key is present but find returns nil' do
          allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(nil)

          expect { described_class.new.perform(nil, template_id, nil, { 'cache_key' => cache_key, 'id_type' => 'email' }) }
            .to raise_error(ArgumentError, /AttrPackage.*error/)
        end
      end
    end

    it 'deletes the cache key after sending email' do
      cache_key = 'test_cache_key'
      allow(Sidekiq::AttrPackage).to receive(:find).with(cache_key).and_return(
        email: 'test@example.com',
        personalisation: {}
      )

      expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)

      described_class.new.perform(nil, template_id, nil, { 'cache_key' => cache_key })
    end
  end

  describe 'sidekiq_retries_exhausted' do
    subject(:config) { described_class }

    let(:exception) do
      e = StandardError.new('oh shoot')
      allow(e).to receive(:backtrace).and_return(['line 1', 'line 2', 'line 3'])
      e
    end

    it 'logs the error' do
      # Exception message is omitted to avoid logging PII (email, personalisation)
      expected_log_message = <<~LOG
        VANotifyEmailJob retries exhausted:
        Exception: #{exception.class}
        Backtrace: #{exception.backtrace.join("\n")}
      LOG
      job = { 'args' => [nil, nil, nil, {}] }

      expect(StatsD).to receive(:increment).with(
        "#{DebtManagementCenter::VANotifyEmailJob::STATS_KEY}.retries_exhausted"
      )
      expect(StatsD).not_to receive(:increment).with(
        "#{DebtsApi::V0::Form5655Submission::STATS_KEY}.send_failed_form_email.failure"
      )
      expect(Rails.logger).to receive(:error).with(expected_log_message)
      config.sidekiq_retries_exhausted_block.call(job, exception)
    end

    it 'deletes redis cache_key when retries expire' do
      cache_key = 'test_cache_key_123'
      job = { 'args' => [nil, nil, nil, { 'cache_key' => cache_key }] }

      expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)

      config.sidekiq_retries_exhausted_block.call(job, exception)
    end

    context 'when firing a silent error email' do
      let(:email) { 'test@tester.com' }
      let(:template_id) { DebtsApi::V0::Form5655Submission::SUBMISSION_FAILURE_EMAIL_TEMPLATE_ID }
      let(:job_args) { [email, template_id, nil, { 'failure_mailer' => true }] }
      let(:callback_options) { DebtManagementCenter::VANotifyEmailJob::VA_NOTIFY_CALLBACK_OPTIONS }
      let(:personalisation) do
        {
          'first_name' => 'Homer',
          'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
          'updated_at' => Time.zone.now.strftime('%m/%d/%Y'),
          'confirmation_number' => 'e7b5d0e3-2a6f-4b5b-91a5-0cc3d801f1e1'
        }
      end

      it 'increments the failure counter' do
        expect(StatsD).to receive(:increment).with(
          'silent_failure', tags: %w[service:debt-resolution function:sidekiq_retries_exhausted]
        )
        expect(StatsD).to receive(:increment).with('api.dmc.va_notify_email.retries_exhausted')
        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::Form5655Submission::STATS_KEY}.send_failed_form_email.failure"
        )

        described_class.sidekiq_retries_exhausted_block.call({ 'args' => job_args }, exception)
      end

      it 'uses the callback options when failure_mailer is true' do
        allow(va_notify_client).to receive(:send_email)
        expect(VaNotify::Service).to receive(:new).with(
          Settings.vanotify.services.dmc.api_key,
          callback_options
        ).and_return(va_notify_client)

        config.new.perform(
          email,
          template_id,
          personalisation,
          { 'id_type' => 'email', 'failure_mailer' => true }
        )
      end

      it 'does not use the callback options when failure_mailer is not set' do
        allow(va_notify_client).to receive(:send_email)
        expect(VaNotify::Service).to receive(:new).with(
          Settings.vanotify.services.dmc.api_key
        ).and_return(va_notify_client)

        config.new.perform(email, template_id, personalisation)
      end
    end
  end
end
