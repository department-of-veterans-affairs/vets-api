# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VBASubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'successful' do
      before do
        response = { status: 200 }
        allow_any_instance_of(DebtsApi::V0::FinancialStatusReportService)
          .to receive(:submit_vba_fsr).and_return(response)
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
        allow(UserProfileAttributes).to receive(:find).and_return(user_data)
      end

      it 'updates submission on success' do
        described_class.new.perform(form_submission.id, user.uuid)
        expect(form_submission.submitted?).to eq(true)
      end
    end

    context 'failure' do
      before do
        allow_any_instance_of(DebtsApi::V0::FinancialStatusReportService).to receive(:submit_vba_fsr).and_raise('uhoh')
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
        allow(UserProfileAttributes).to receive(:find).and_return(user_data)
      end

      it 'updates submission on error' do
        expect { described_class.new.perform(form_submission.id, user.uuid) }.to raise_exception('uhoh')
        expect(form_submission.failed?).to eq(true)
        expect(form_submission.error_message).to eq('uhoh')
      end
    end

    context 'with retries exhausted' do
      let(:config) { described_class }
      let(:missing_attributes_exception) do
        e = DebtsApi::V0::Form5655::VBASubmissionJob::MissingUserAttributesError.new('abc-123')
        allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
        e
      end

      let(:standard_exception) do
        e = StandardError.new('abc-123')
        allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
        e
      end

      let(:msg) do
        {
          'class' => 'YourJobClassName',
<<<<<<< HEAD
          'args' => %w[123 123-abc],
=======
          'args' => %w[submissionID uuid],
>>>>>>> 7d6de589aa (Update monitoring)
          'jid' => '12345abcde',
          'retry_count' => 5
        }
      end

      it 'handles MissingUserAttributesError' do
        expected_log_message = <<~LOG
          V0::Form5655::VBASubmissionJob retries exhausted:
<<<<<<< HEAD
          submission_id: 123 | user_id: 123-abc
          Exception: #{missing_attributes_exception.class} - #{missing_attributes_exception.message}
          Backtrace: #{missing_attributes_exception.backtrace.join("\n")}
=======
          Exception: #{exception.class} - #{exception.message}
          Backtrace: #{exception.backtrace.join("\n")}
          submission_id: submissionID | user_id: uuid
>>>>>>> 7d6de589aa (Update monitoring)
        LOG

        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::Form5655::VBASubmissionJob::STATS_KEY}.retries_exhausted"
        )

        expect(Rails.logger).to receive(:error).with(expected_log_message)
        config.sidekiq_retries_exhausted_block.call(msg, missing_attributes_exception)
      end

      it 'handles unexpected errors' do
        expected_log_message = <<~LOG
          V0::Form5655::VBASubmissionJob retries exhausted:
          submission_id: 123 | user_id: 123-abc
          Exception: #{standard_exception.class} - #{standard_exception.message}
          Backtrace: #{standard_exception.backtrace.join("\n")}
        LOG

        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::Form5655::VBASubmissionJob::STATS_KEY}.retries_exhausted"
        )

        expect(Rails.logger).to receive(:error).with(expected_log_message)
        config.sidekiq_retries_exhausted_block.call(msg, standard_exception)
      end
    end
  end
end
