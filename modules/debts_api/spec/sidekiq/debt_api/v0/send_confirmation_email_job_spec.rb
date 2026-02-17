# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::SendConfirmationEmailJob, type: :worker do
  describe '#perform' do
    let(:user) { create(:user, :loa3) }
    let(:input_cache_key) { 'input_cache_key_123' }

    before do
      allow(Sidekiq::AttrPackage).to receive(:find).with(input_cache_key).and_return(
        email: user.email,
        first_name: user.first_name
      )
      allow(Sidekiq::AttrPackage).to receive(:delete)
      allow(Sidekiq::AttrPackage).to receive(:create).and_return('vanotify_cache_key')
    end

    context 'when incoming user_pii is present' do
      let!(:form_submission) do
        create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
      end
      let(:job_params) do
        {
          'user_uuid' => user.uuid,
          'user_pii' => { email: user.email, first_name: user.first_name },
          'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
        }
      end

      it 'uses args["user_pii"] and does not call fetch_pii_from_cache' do
        expect(Sidekiq::AttrPackage).not_to receive(:find)

        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
          nil,
          job_params['template_id'],
          hash_including('first_name' => user.first_name),
          {}
        )

        described_class.new.perform(job_params)
      end
    end

    context 'when incoming user_pii is not present' do
      let!(:form_submission) do
        create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
      end
      let(:job_params) do
        {
          'cache_key' => input_cache_key,
          'user_uuid' => user.uuid,
          'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
        }
      end

      it 'calls fetch_pii_from_cache and uses cached PII' do
        expect(Sidekiq::AttrPackage).to receive(:find).with(input_cache_key).and_return(
          email: user.email,
          first_name: user.first_name
        )
        expect(Sidekiq::AttrPackage).not_to receive(:create)

        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
          user.email,
          job_params['template_id'],
          hash_including('first_name' => user.first_name),
          { id_type: 'email', cache_key: nil }
        )

        described_class.new.perform(job_params)
      end

      context 'when the cache does not exist (no cache_key in args)' do
        let(:job_params) do
          {
            'user_uuid' => user.uuid,
            'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
          }
        end

        it 'creates a cache key on line 69 and passes it to VANotifyEmailJob' do
          expect(job_params).not_to have_key('user_pii')
          expect(Sidekiq::AttrPackage).not_to receive(:find)
          expect(Sidekiq::AttrPackage).to receive(:create).and_return('vanotify_cache_key')

          expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
            nil,
            job_params['template_id'],
            anything,
            { id_type: 'email', cache_key: 'vanotify_cache_key' }
          )

          described_class.new.perform(job_params)
        end
      end
    end

    context 'when submissions are found' do
      let!(:form_submission) do
        create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
      end
      let(:job_params) do
        {
          'cache_key' => input_cache_key,
          'user_uuid' => user.uuid,
          'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
        }
      end

      it 'calls the email job with cache_key instead of user info' do
        expect(Sidekiq::AttrPackage).to receive(:find).with(input_cache_key).and_return(
          email: user.email,
          first_name: user.first_name
        )
        expect(Sidekiq::AttrPackage).not_to receive(:create)

        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
          user.email,
          job_params['template_id'],
          hash_including('first_name' => user.first_name),
          { id_type: 'email', cache_key: nil }
        )

        described_class.new.perform(job_params)
      end
    end

    context 'when no submissions are found' do
      let(:job_params) do
        {
          'cache_key' => input_cache_key,
          'user_uuid' => user.uuid,
          'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
        }
      end

      it 'logs a warning message' do
        expect(Rails.logger).to receive(:warn).with(
          'DebtsApi::SendConfirmationEmailJob (fsr) - ' \
          "No submissions found for user_uuid: #{job_params['user_uuid']}"
        )

        described_class.new.perform(job_params)
      end

      it 'deletes the cache_key if no submissions are found' do
        allow(Rails.logger).to receive(:warn)
        expect(Sidekiq::AttrPackage).to receive(:delete).with(input_cache_key)

        described_class.new.perform(job_params)
      end
    end

    context 'when an error occurs' do
      let!(:form_submission) do
        create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
      end
      let(:job_params) do
        {
          'cache_key' => input_cache_key,
          'user_uuid' => user.uuid,
          'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
        }
      end

      it 'raises an error and logs the message' do
        allow(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).and_raise(StandardError, 'Test error')

        expect(Rails.logger).to receive(:error).with(
          'DebtsApi::SendConfirmationEmailJob (fsr) - Error sending email: Test error'
        )

        expect { described_class.new.perform(job_params) }.to raise_error(StandardError, 'Test error')
      end

      it 'converts AttrPackageError to ArgumentError to prevent retries' do
        allow(Sidekiq::AttrPackage).to receive(:find).and_raise(
          Sidekiq::AttrPackageError.new('find', 'Redis connection failed')
        )

        expect { described_class.new.perform(job_params) }.to raise_error(ArgumentError, /AttrPackage.*error/)
      end
    end

    context 'with digital dispute submissions' do
      context 'when digital dispute submission is found' do
        let!(:digital_dispute_submission) do
          create(:debts_api_digital_dispute_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
        end
        let(:job_params) do
          {
            'submission_type' => 'digital_dispute',
            'cache_key' => input_cache_key,
            'user_uuid' => user.uuid,
            'template_id' => DebtsApi::V0::DigitalDisputeSubmission::CONFIRMATION_TEMPLATE
          }
        end

        it 'calls the email job with cache_key instead of user info' do
          expect(Sidekiq::AttrPackage).to receive(:find).with(input_cache_key).and_return(
            email: user.email,
            first_name: user.first_name
          )
          expect(Sidekiq::AttrPackage).not_to receive(:create)

          expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
            user.email,
            job_params['template_id'],
            hash_including('first_name' => user.first_name),
            { id_type: 'email', cache_key: nil }
          )

          described_class.new.perform(job_params)
        end
      end

      context 'when no digital dispute submissions are found' do
        let(:job_params) do
          {
            'submission_type' => 'digital_dispute',
            'cache_key' => input_cache_key,
            'user_uuid' => user.uuid,
            'template_id' => DebtsApi::V0::DigitalDisputeSubmission::CONFIRMATION_TEMPLATE
          }
        end

        it 'logs a warning message for digital dispute' do
          expect(Rails.logger).to receive(:warn).with(
            'DebtsApi::SendConfirmationEmailJob (digital_dispute) - ' \
            "No submissions found for user_uuid: #{job_params['user_uuid']}"
          )

          described_class.new.perform(job_params)
        end
      end

      context 'with PII protection via AttrPackage' do
        let!(:digital_dispute_submission) do
          create(:debts_api_digital_dispute_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
        end
        let(:job_params) do
          {
            'submission_type' => 'digital_dispute',
            'cache_key' => input_cache_key,
            'user_uuid' => user.uuid,
            'template_id' => DebtsApi::V0::DigitalDisputeSubmission::CONFIRMATION_TEMPLATE
          }
        end

        it 'retrieves PII from cache' do
          allow(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async)

          expect(Sidekiq::AttrPackage).to receive(:find).with(input_cache_key)

          described_class.new.perform(job_params)
        end
      end
    end
  end

  describe 'sidekiq_retries_exhausted' do
    let(:exception) do
      e = StandardError.new('Test error')
      allow(e).to receive(:backtrace).and_return(['line 1', 'line 2'])
      e
    end

    it 'deletes redis cache_key when retries expire' do
      cache_key = 'test_cache_key_456'
      job = { 'args' => [{ 'cache_key' => cache_key, 'submission_type' => 'fsr', 'user_uuid' => 'test-uuid' }] }

      expect(Sidekiq::AttrPackage).to receive(:delete).with(cache_key)
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:error)

      described_class.sidekiq_retries_exhausted_block.call(job, exception)
    end
  end
end
