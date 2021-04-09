# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

describe VBADocuments::UploadFile, type: :model do
  include VBADocuments::Fixtures

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:git_items_json) { get_fixture('git_items.json').read }

  before do
    allow(faraday_response).to receive(:success?).and_return(true)
    allow(faraday_response).to receive(:body).and_return(git_items_json) # 3 records in this json file
    allow(VBADocuments::GitItems).to receive(:query_git) {
      faraday_response
    }
    allow(VBADocuments::GitItems).to receive(:send_to_slack) {
      faraday_response # the body isn't used here, only the 'success' attribute via :success?
    }
    @record_count = VBADocuments::GitItems.populate
  end

  it 'populates itself from git' do
    expect(@record_count).to be(3)
  end

  it 'notifies on slack' do
    @models = VBADocuments::GitItems.all.each do |model|
      expect(model.notified).to be(false)
    end
    response = VBADocuments::GitItems.notify
    @models = VBADocuments::GitItems.all.each do |model|
      expect(model.notified).to be(true)
    end
    expect(response).to be(3)
  end

  it 'only notifies on new things' do
    VBADocuments::GitItems.notify
    response = VBADocuments::GitItems.notify
    expect(response).to be(0)
    model = VBADocuments::GitItems.find_or_create_by(url: 'http://dummy/url')
    model.git_item = VBADocuments::GitItems.first.git_item
    model.save
    response = VBADocuments::GitItems.notify
    expect(response).to be(1)
  end

  it 'gracefully logs when the git query is not successful' do
    allow(faraday_response).to receive(:success?).and_return(false)
    VBADocuments::GitItems.destroy_all
    record_count = VBADocuments::GitItems.populate
    expect(record_count).to be(0) # we expect code coverage for the logging of the failure.
  end

  it 'does not over populate' do
    expect(@record_count).to be(3)
    record_count = VBADocuments::GitItems.populate #second populate with the same data
    expect(record_count).to be(3)
  end

end
