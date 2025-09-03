# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::SendConfirmationEmailJob, type: :worker do
  describe '#perform' do
    context 'when submissions are found' do
      let!(:form_submission) do
        create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
      end
      let(:user) { create(:user, :loa3) }
      let(:job_params) do
        {
          'email' => user.email,
          'first_name' => user.first_name,
          'user_uuid' => user.uuid,
          'template_id' => DebtsApi::V0::FinancialStatusReportService::IN_PROGRESS_TEMPLATE_ID
        }
      end

      it 'calls the email job with the correct parameters' do
        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
          job_params['email'],
          job_params['template_id'],
          {
            'first_name' => job_params['first_name'],
            'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
            'confirmation_number' => [form_submission.id]
          },
          { id_type: 'email' }
        )

        described_class.new.perform(job_params)
      end
    end

    context 'when no submissions are found' do
      let(:user) { create(:user, :loa3) }
      let(:job_params) do
        {
          'email' => user.email,
          'first_name' => user.first_name,
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
    end

    context 'when an error occurs' do
      let(:user) { create(:user, :loa3) }
      let!(:form_submission) do
        create(:debts_api_form5655_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
      end
      let(:job_params) do
        {
          'email' => user.email,
          'first_name' => user.first_name,
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
    end

    context 'with digital dispute submissions' do
      let(:user) { create(:user, :loa3) }

      context 'when digital dispute submission is found' do
        let!(:digital_dispute_submission) do
          create(:debts_api_digital_dispute_submission, user_uuid: user.uuid, user_account: user.user_account, state: 1)
        end
        let(:job_params) do
          {
            'submission_type' => 'digital_dispute',
            'email' => user.email,
            'first_name' => user.first_name,
            'user_uuid' => user.uuid,
            'template_id' => DebtsApi::V0::DigitalDisputeSubmissionService::CONFIRMATION_TEMPLATE
          }
        end

        it 'calls the email job with correct parameters for digital dispute' do
          expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
            job_params['email'],
            job_params['template_id'],
            {
              'first_name' => job_params['first_name'],
              'date_submitted' => Time.zone.now.strftime('%m/%d/%Y'),
              'confirmation_number' => digital_dispute_submission.id
            },
            { id_type: 'email' }
          )

          described_class.new.perform(job_params)
        end
      end

      context 'when no digital dispute submissions are found' do
        let(:job_params) do
          {
            'submission_type' => 'digital_dispute',
            'email' => user.email,
            'first_name' => user.first_name,
            'user_uuid' => user.uuid,
            'template_id' => DebtsApi::V0::DigitalDisputeSubmissionService::CONFIRMATION_TEMPLATE
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
    end
  end
end
