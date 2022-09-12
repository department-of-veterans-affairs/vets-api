# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/app/workers/vba_documents/deployments_notifier'
require './modules/vba_documents/spec/support/vba_document_fixtures'

RSpec.describe 'VBADocuments::DeploymentsNotifier', type: :job do
  include VBADocuments::Fixtures

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:git_items_forms_json) { get_fixture('git_items_forms.json').read }

  before do
    Settings.vba_documents.slack = Config::Options.new
    Settings.vba_documents.slack.enabled = true

    allow(faraday_response).to receive(:success?).and_return(true)
    allow(faraday_response).to receive(:body) do
      git_items_forms_json
    end

    allow(VBADocuments::GitItems).to receive(:query_git) {
      faraday_response
    }
    allow(VBADocuments::GitItems).to receive(:send_to_slack) {
      faraday_response # the body isn't used here, only the 'success' attribute via :success?
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
    results = @job.perform('Forms')
    expect(results.first).to be(4) # fixture git_items_forms.json has four records
  end

  it 'logs and returns the exception if something goes wrong' do
    allow(VBADocuments::GitItems).to receive(:populate) {
      raise RuntimeError
    }
    results = @job.perform('Forms')
    expect(results.first.class).to be(RuntimeError)
  end

  it 'spawns a job for every label' do
    results = @job.perform
    expect(results.length).to be(VBADocuments::GitItems::LABELS.length)
  end

  it 'rejects invalid labels' do
    expect { @job.perform('bad_label') }.to raise_error(ArgumentError)
  end
end
