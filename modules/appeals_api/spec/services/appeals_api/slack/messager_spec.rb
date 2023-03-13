# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::Slack::Messager do
  describe '.notify!' do
    let(:params) do
      {
        'class' => 'PdfSubmitJob',
        'args' => %w[1234 5678],
        'retry_count' => 2,
        'error_class' => 'RuntimeError',
        'error_message' => 'Here there be dragons',
        'failed_at' => 1_613_670_737.966083,
        'retried_at' => 1_613_680_062.5507782
      }
    end

    it 'sends a network request' do
      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.modules_appeals_api.slack, api_key: 'api token',
                                                          appeals_channel_id: 'slack channel id') do
          body = {
            text: AppealsApi::Slack::ErrorRetryNotification.new(params).message_text,
            channel: 'slack channel id'
          }.to_json

          headers = {
            'Content-type' => 'application/json; charset=utf-8',
            'Authorization' => 'Bearer api token'
          }

          allow(Faraday).to receive(:post).with(AppealsApi::Slack::Messager::API_PATH, body, headers)

          AppealsApi::Slack::Messager.new(params, notification_type: :error_retry).notify!

          expect(Faraday).to have_received(:post).with(AppealsApi::Slack::Messager::API_PATH, body, headers)
        end
      end
    end

    it 'raises if an unknown message type is provided' do
      expect { AppealsApi::Slack::Messager.new(params, notification_type: :unknown).notify! }
        .to(raise_error(AppealsApi::Slack::UnregisteredNotificationType,
                        'registered notifications: [:error_retry, :stuck_record]'))
    end
  end
end
