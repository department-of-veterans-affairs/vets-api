# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::UpdateCypressViewportsJob do
  describe '#perform' do
    let!(:job) { described_class.new }
    let!(:analytics) do
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(true)

      instance_double(CypressViewportUpdater::GoogleAnalyticsReports,
                      request_reports: true,
                      user_report: true,
                      viewport_report: true)
    end
    let!(:viewports) { instance_double(CypressViewportUpdater::Viewports, create: true) }
    let!(:github) do
      instance_double(CypressViewportUpdater::GithubService,
                      get_content: true,
                      create_branch: true,
                      update_content: true,
                      submit_pr: true)
    end

    it 'returns self' do
      allow(job).to receive(:perform) { job }
      expect(job.perform).to be_an_instance_of(described_class)
    end

    it 'submits the PR' do
      allow_any_instance_of(CypressViewportUpdater::GoogleAnalyticsReports)
        .to receive(:request_reports) { analytics }
      allow_any_instance_of(CypressViewportUpdater::GoogleAnalyticsReports)
        .to receive(:user_report).and_return(true)
      allow_any_instance_of(CypressViewportUpdater::GoogleAnalyticsReports)
        .to receive(:viewport_report).and_return(true)
      allow(CypressViewportUpdater::Viewports)
        .to receive(:new).with(user_report: true) { viewports }
      allow_any_instance_of(CypressViewportUpdater::Viewports)
        .to receive(:create).with(viewport_report: 1).and_return(true)
      allow(CypressViewportUpdater::GithubService)
        .to receive(:new) { github }
      allow_any_instance_of(CypressViewportUpdater::CypressConfigJsFile)
        .to receive(:update).and_return(true)
      allow_any_instance_of(CypressViewportUpdater::ViewportPresetJsFile)
        .to receive(:update).and_return(true)

      expect(github).to receive(:create_branch)
      expect(github).to receive(:submit_pr)
      job.perform
    end
  end
end
