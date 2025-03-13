# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::VBSSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'when all retries are exhausted' do
      let(:form_submission) { create(:debts_api_form5655_submission) }

      let(:config) { described_class }
      let(:standard_exception) do
        e = StandardError.new('abc-123')
        allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
        e
      end
      let(:msg) do
        {
          'class' => 'YourJobClassName',
          'args' => [form_submission.id, '123-abc'],
          'jid' => '12345abcde',
          'retry_count' => 5
        }
      end

      before do
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
        allow(Flipper).to receive(:enabled?).and_return(false)
      end

      it 'increments the retries exhausted counter and logs error information' do
        expected_log_message = <<~LOG
          V0::Form5655::VHA::VBSSubmissionJob retries exhausted:
          submission_id: #{form_submission.id} | user_id: 123-abc
          Exception: #{standard_exception.class} - #{standard_exception.message}
          Backtrace: #{standard_exception.backtrace.join("\n")}
        LOG

        statsd_key = DebtsApi::V0::Form5655::VHA::VBSSubmissionJob::STATS_KEY

        ["#{statsd_key}.failure", "#{statsd_key}.retries_exhausted", 'api.fsr_submission.failure'].each do |key|
          expect(StatsD).to receive(:increment).with(key)
        end

        expect(Rails.logger).to receive(:error).with(
          "Form5655Submission id: #{form_submission.id} failed", 'VBS Submission Failed: abc-123'
        )

        expect(Rails.logger).to receive(:error).with(expected_log_message)
        config.sidekiq_retries_exhausted_block.call(msg, standard_exception)
        expect(form_submission.reload.error_message).to eq('VBS Submission Failed: abc-123')
      end
    end
  end
end
