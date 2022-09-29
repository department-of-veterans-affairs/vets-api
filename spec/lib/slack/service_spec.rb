# frozen_string_literal: true

require 'rails_helper'
require 'slack/service'

describe Slack::Service do
  let(:slack_hash) { { channel: '#vsp_test_channel', webhook: 'https://hooks.slack.com/services/asdf1234' } }
  let(:subject) { described_class.new(slack_hash) }
  let(:header) { 'Slack Notification Header String Exmple' }
  let(:blocks) do
    [{ block_type: 'section', text: "**Bold text**\n_Italics text_", text_type: 'mrkdwn' },
     { block_type: 'divider' },
     { block_type: 'section', text: '`Code formatted text`', text_type: 'mrkdwn' }]
  end
  let(:formatted_blocks) do
    [{ type: 'section', text: { type: 'mrkdwn', text: "**Bold text**\n_Italics text_" } },
     { type: 'divider' },
     { type: 'section', text: { type: 'mrkdwn', text: '`Code formatted text`' } }]
  end

  describe '.initialize' do
    context 'attr_writers' do
      it 'assigns slack_hash channel to itself' do
        expect(subject.instance_values['channel']).to eq(slack_hash[:channel])
      end

      it 'assigns slack_hash webhook to itself' do
        expect(subject.instance_values['webhook']).to eq(slack_hash[:webhook])
      end
    end
  end

  describe '.notify' do
    it 'transforms blocks argument into Slack blocks' do
      VCR.use_cassette('slack/slack_bot_notify') do
        expect_any_instance_of(Slack::Service).to receive(:build_blocks).with(blocks).and_return(formatted_blocks)
        subject.notify(header, blocks)
      end
    end

    it 'makes a POST request to the Slack webhook' do
      VCR.use_cassette('slack/slack_bot_notify') do
        response = subject.notify(header, blocks)
        expect(response.body).to eq('ok')
      end
    end
  end
end
