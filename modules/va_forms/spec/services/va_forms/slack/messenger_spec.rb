# frozen_string_literal: true

require 'rails_helper'

describe VAForms::Slack::Messenger do
  describe '.notify!' do
    let(:params) do
      {
        'class' => 'SomeClass',
        'args' => %w[1234 5678],
        'error_class' => 'RuntimeError',
        'error_message' => 'Here there be dragons'
      }
    end

    it 'sends a network request' do
      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.va_forms.slack, api_key: 'api token', channel_id: 'slack channel id') do
          body = {
            text: VAForms::Slack::HashNotification.new(params).message_text,
            channel: 'slack channel id'
          }.to_json

          headers = {
            'Content-type' => 'application/json; charset=utf-8',
            'Authorization' => 'Bearer api token'
          }

          allow(Faraday).to receive(:post).with(VAForms::Slack::Messenger::API_PATH, body, headers)

          VAForms::Slack::Messenger.new(params).notify!

          expect(Faraday).to have_received(:post).with(VAForms::Slack::Messenger::API_PATH, body, headers)
        end
      end
    end
  end
end
