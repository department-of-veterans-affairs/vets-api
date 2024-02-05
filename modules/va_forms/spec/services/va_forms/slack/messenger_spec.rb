# frozen_string_literal: true

require 'rails_helper'

describe VAForms::Slack::Messenger do
  describe '.notify!' do
    let(:args) do
      {
        'class' => 'SomeClass',
        'args' => %w[1234 5678],
        'error_class' => 'RuntimeError',
        'error_message' => 'Here there be dragons'
      }
    end
    let(:api_key) { 'slack api key' }
    let(:channel_id) { 'slack channel id' }

    before { allow(Faraday).to receive(:post) }

    it 'makes a POST request to Slack with the message as the body' do
      with_settings(Settings.va_forms.slack, enabled: true, api_key:, channel_id:) do
        body = {
          text: VAForms::Slack::HashNotification.new(args).message_text,
          channel: channel_id
        }.to_json

        headers = {
          'Content-type' => 'application/json; charset=utf-8',
          'Authorization' => "Bearer #{api_key}"
        }

        expect(Faraday).to receive(:post).with(VAForms::Slack::Messenger::API_PATH, body, headers)

        VAForms::Slack::Messenger.new(args).notify!
      end
    end

    context 'when the Slack enabled setting is set to false' do
      it 'does not make a POST request to Slack' do
        with_settings(Settings.va_forms.slack, enabled: false) do
          expect(Faraday).not_to receive(:post)

          VAForms::Slack::Messenger.new(args).notify!
        end
      end
    end
  end
end
