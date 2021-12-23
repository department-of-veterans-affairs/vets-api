# frozen_string_literal: true

require 'rails_helper'
require 'slack/service'

describe Slack::Service do
  let(:slack_hash) do
    {
      header: 'Slack Notification Header String Exmple',
      text: [
        { block_type: 'section', text: "**Bold text**\n_Italics text_", text_type: 'mrkdwn' },
        { block_type: 'divider' },
        { block_type: 'section', text: '`Code formatted text`', text_type: 'mrkdwn' }
      ],
      channel: '#vsp_test_channel',
      webhook: 'https://hooks.slack.com/services/asdf1234'
    }
  end
  let(:subject) { described_class.new(slack_hash) }
  let(:blocks) do
    [
      { type: 'section', text: { type: 'mrkdwn', text: "**Bold text**\n_Italics text_" } },
      { type: 'divider' },
      { type: 'section', text: { type: 'mrkdwn', text: '`Code formatted text`' } }
    ]
  end

  describe '.initialize' do
    context 'attr_writers' do
      it 'assigns slack_hash header to itself' do
        expect(subject.instance_values['header']).to eq(slack_hash[:header])
      end

      it 'assigns slack_hash text to itself' do
        expect(subject.instance_values['text']).to eq(slack_hash[:text])
      end

      it 'assigns slack_hash channel to itself' do
        expect(subject.instance_values['channel']).to eq(slack_hash[:channel])
      end

      it 'assigns slack_hash webhook to itself' do
        expect(subject.instance_values['webhook']).to eq(slack_hash[:webhook])
      end
    end
  end

  describe '.notify' do
    it 'transforms the text attribute into Slack blocks' do
      expect(subject.send(:build_blocks)).to eq(blocks)
    end

    it 'makes a POST request to the Slack webhook' do
      VCR.use_cassette('slack/slack_bot_notify') do
        response = subject.notify
        expect(response.body).to eq('ok')
      end
    end
  end
end
