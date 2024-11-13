# frozen_string_literal: true

require 'rails_helper'

require 'sidekiq/testing'

RSpec.describe DebtsApi::V0::Form5655::VHA::VBSSubmissionJob, type: :worker do
  describe '#perform' do
    let(:form_submission) { build(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }
    let(:msg) do
      {
        'class' => 'YourJobClassName',
        'args' => %w[123 123-abc],
        'jid' => '12345abcde',
        'retry_count' => 5
      }
    end

    context 'when all retries are exhausted' do
      before do
        allow(DebtsApi::V0::Form5655Submission).to receive(:find).and_return(form_submission)
      end

      it 'sets submission to failure' do
        described_class.within_sidekiq_retries_exhausted_block({ 'jid' => 123 }) do
          expect(form_submission).to receive(:register_failure)
        end
      end

      it 'increments the retries exhausted counter' do
        statsd_key = DebtsApi::V0::Form5655::VHA::VBSSubmissionJob::STATS_KEY

        ["#{statsd_key}.failure", "#{statsd_key}.retries_exhausted", 'api.fsr_submission.failure'].each do |key|
          expect(StatsD).to receive(:increment).with(key)
        end

        expect(StatsD).to receive(:increment).with(
          'silent_failure', { tags: %w[service:debt-resolution function:register_failure] }
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, StandardError.new('abc-123'))
      end
    end
  end
end
