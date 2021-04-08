# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/app/workers/vba_documents/deployments_notifier'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe 'VBADocuments::DeploymentsNotifer', type: :job do
  include VBADocuments::Fixtures

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:git_items_json) { get_fixture('git_items.json').read }

  before do
    Settings.vba_documents.slack = Config::Options.new
    Settings.vba_documents.slack.enabled = true

    allow(faraday_response).to receive(:success?).and_return(true)
    allow(faraday_response).to receive(:body).and_return(git_items_json) #15 records in this json file
    allow(VBADocuments::GitItems).to receive(:query_git) {
      faraday_response
    }
    allow(VBADocuments::GitItems).to receive(:send_to_slack) {
      faraday_response #the body isn't used here, only the 'success' attribute via :success?
    }
    @job = VBADocuments::DeploymentsNotifier.new
  end

  after do
    Settings.vba_documents.slack = nil
  end

  it 'does nothing if the flag is disabled' do
    with_settings(Settings.vba_documents.slack, enabled: false) do
      results = @job.perform
      expect(results).to be(nil)
    end
  end

  it 'populates and notifies on deployments' do
    results = @job.perform
    expect(results).to be(15)
  end

  it 'logs and returns the exception if something goes wrong' do
    allow(VBADocuments::GitItems).to receive(:populate) {
      raise RuntimeError.new
    }
    results = @job.perform
    expect(results.class).to be(RuntimeError)
  end

end
