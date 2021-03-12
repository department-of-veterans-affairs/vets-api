# frozen_string_literal: true

require 'appeals_api/sidekiq_retry_notifier'

module AppealsApi
  RSpec.describe SidekiqRetryNotifier do
    describe '.notify!' do
      let(:params) do
        {
          'class' => 'HigherLevelReviewPdfSubmitJob',
          'retry_count' => 2,
          'error_class' => 'RuntimeError',
          'error_message' => '',
          'failed_at' => 1_613_670_737.966083,
          'retried_at' => 1_613_680_062.5507782
        }
      end

      it 'sends a network request' do
        text = SidekiqRetryNotifier.message_text(params)

        allow(Faraday).to receive(:post).with(SidekiqRetryNotifier.slack_api_path)

        SidekiqRetryNotifier.notify!(params)

        expect(Faraday).to have_received(:post).with(SidekiqRetryNotifier.slack_api_path)
      end
    end
  end
end
