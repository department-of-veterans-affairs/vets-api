# frozen_string_literal: true

require 'rails_helper'
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
        with_settings(Settings.modules_appeals_api.slack, api_key: 'api token',
                                                          appeals_channel_id: 'slack channel id') do
          body = {
            text: SidekiqRetryNotifier.message_text(params),
            channel: 'slack channel id'
          }.to_json

          headers = {
            'Content-type' => 'application/json; charset=utf-8',
            'Authorization' => 'Bearer api token'
          }

          allow(Faraday).to receive(:post).with(SidekiqRetryNotifier::API_PATH, body, headers)

          SidekiqRetryNotifier.notify!(params)

          expect(Faraday).to have_received(:post).with(SidekiqRetryNotifier::API_PATH, body, headers)
        end
      end
    end
  end
end
