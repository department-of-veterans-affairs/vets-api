# frozen_string_literal: true

require 'rails_helper'

describe VBADocuments::Slack::Messenger do
  describe '.notify!' do
    let(:params) do
      {
        'class' => 'SomeClass',
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
        with_settings(Settings.vba_documents.slack, default_alert_url: 'default alert url') do
          body = { text: VBADocuments::Slack::HashNotification.new(params).message_text }.to_json
          headers = { 'Content-type' => 'application/json; charset=utf-8' }

          allow(Faraday).to receive(:post).with(VBADocuments::Slack::Messenger::ALERT_URL, body, headers)

          VBADocuments::Slack::Messenger.new(params).notify!

          expect(Faraday).to have_received(:post).with(VBADocuments::Slack::Messenger::ALERT_URL, body, headers)
        end
      end
    end
  end
end
