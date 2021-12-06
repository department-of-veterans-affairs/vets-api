# frozen_string_literal: true

require 'rails_helper'
require './modules/vba_documents/spec/support/vba_document_fixtures'

describe VBADocuments::GitItems, type: :model do
  include VBADocuments::Fixtures

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:git_items_json) { get_fixture('git_items_benefits.json').read }
  let(:git_items_benefits_json) { get_fixture('git_items_benefits.json').read }
  let(:git_items_forms_json) { get_fixture('git_items_forms.json').read }

  before do
    Settings.vba_documents.slack = Config::Options.new
    Settings.vba_documents.slack.deployment_notification_benefits_url = nil # url post mocked out
    Settings.vba_documents.slack.deployment_notification_forms_url = nil # url post mocked out
    allow(faraday_response).to receive(:success?).and_return(true)
    allow(VBADocuments::GitItems).to receive(:query_git) {
      faraday_response
    }
    allow(VBADocuments::GitItems).to receive(:send_to_slack) {
      faraday_response # the body isn't used here, only the 'success' attribute via :success?
    }
    @record_counts = []
    allow(faraday_response).to receive(:body).and_return(git_items_benefits_json) # 3 records in this json file
    @record_counts << VBADocuments::GitItems.populate('BenefitsIntake')
    allow(faraday_response).to receive(:body).and_return(git_items_forms_json) # 4 records in this json file
    @record_counts << VBADocuments::GitItems.populate('Forms')
  end

  it 'populates itself from git' do
    expect(@record_counts.first).to be(3)
    expect(@record_counts.last).to be(4)
  end

  it 'notifies on slack' do
    @models = VBADocuments::GitItems.all.each do |model|
      expect(model.notified).to be(false)
    end
    response = []
    VBADocuments::GitItems::LABELS.each do |label|
      response << VBADocuments::GitItems.notify(label)
    end

    @models = VBADocuments::GitItems.all.each do |model|
      expect(model.notified).to be(true)
    end

    expect(response.first).to be(3)
    expect(response.last).to be(4)
  end

  it 'only notifies on new things' do
    VBADocuments::GitItems.notify('BenefitsIntake')
    response = VBADocuments::GitItems.notify('BenefitsIntake')
    expect(response).to be(0)
    model = VBADocuments::GitItems.find_or_create_by(url: 'http://dummy/url')
    model.git_item = VBADocuments::GitItems.first.git_item
    model.label = 'BenefitsIntake'
    model.save
    response = VBADocuments::GitItems.notify('BenefitsIntake')
    expect(response).to be(1)
  end

  it 'gracefully logs when the git query is not successful' do
    allow(faraday_response).to receive(:success?).and_return(false)
    VBADocuments::GitItems.destroy_all
    record_count = VBADocuments::GitItems.populate('BenefitsIntake')
    expect(record_count).to be(0) # we expect code coverage for the logging of the failure.
  end

  it 'does not over populate' do
    expect(@record_counts.first).to be(3)
    record_count_benefits = VBADocuments::GitItems.populate('BenefitsIntake') # second populate with the same data
    record_count_forms = VBADocuments::GitItems.populate('Forms') # second populate with the same data
    expect(record_count_benefits).to be(3)
    expect(record_count_forms).to be(4)
  end
end
