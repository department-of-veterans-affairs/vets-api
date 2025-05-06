# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { create(:debts_api_form5655_submission) }

    before do
      allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
      allow(Flipper).to receive(:enabled?).and_return(false)
    end

    context 'with retries exhausted' do
      let(:config) { described_class }
      let(:msg) do
        {
          'class' => 'YourJobClassName',
          'args' => [form_submission.id],
          'jid' => '12345abcde',
          'retry_count' => 5
        }
      end

      let(:standard_exception) do
        e = StandardError.new('abc-123')
        allow(e).to receive(:backtrace).and_return(%w[backtrace1 backtrace2])
        e
      end

      it 'increments the retries exhausted counter' do
        statsd_key = DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob::STATS_KEY

        ["#{statsd_key}.failure", "#{statsd_key}.retries_exhausted", 'api.fsr_submission.failure'].each do |key|
          expect(StatsD).to receive(:increment).with(key)
        end

        config.sidekiq_retries_exhausted_block.call(msg, standard_exception)
      end

      it 'logs error information' do
        expect(Rails.logger).to receive(:error).with(
          "Form5655Submission id: #{form_submission.id} failed", 'SharePoint Submission Failed: .'
        )
        expect(Rails.logger).to receive(:error).with(
          a_string_matching(
            /
              V0::Form5655::VHA::SharepointSubmissionJob\ retries\ exhausted:\n
              submission_id:\ #{form_submission.id}\n
              Exception:\ .*\n
              Backtrace:.*
            /x
          )
        )

        config.sidekiq_retries_exhausted_block.call(msg, standard_exception)
      end

      it 'puts the form status into error' do
        described_class.within_sidekiq_retries_exhausted_block(msg, standard_exception) do
          expect(form_submission).to receive(:register_failure)
        end
      end
    end
  end
end
