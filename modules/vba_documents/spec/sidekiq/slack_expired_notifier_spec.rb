require 'rails_helper'
require './modules/vba_documents/app/sidekiq/vba_documents/slack_notifier'

RSpec.describe 'VBADocuments::SlackNotifier', type: :job do
  let(:slack_messenger) { instance_double('VBADocuments::Slack::Messenger') }
  let(:slack_enabled) { true }

  before do
    allow(VBADocuments::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    @job = VBADocuments::SlackExpiredNotifier.new
    @results = nil
  end

  context 'when flag is disabled' do
    let(:slack_enabled) { false }

    it 'does nothing' do
      with_settings(Settings.vba_documents.slack, enabled: false) do
        @results = @job.perform
        expect(slack_messenger).not_to have_received(:notify!)
        expect(@results).to be(5)
      end
    end
  end

  context 'when no expired uploads are found' do
  
  end
end