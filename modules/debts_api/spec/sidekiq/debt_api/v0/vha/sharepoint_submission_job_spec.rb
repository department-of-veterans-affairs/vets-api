# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }

    before do
      allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
    end

    context 'when all retries are exhausted' do
      it 'sets submission to failure' do
        described_class.within_sidekiq_retries_exhausted_block({ 'jid' => 123 }) do
          expect(form_submission).to receive(:register_failure)
        end
      end
    end

    context 'with retries exhausted' do
      let(:config) { described_class }
      let(:msg) do
        {
          'class' => 'YourJobClassName',
          'args' => %w[123],
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
    end
  end
end
