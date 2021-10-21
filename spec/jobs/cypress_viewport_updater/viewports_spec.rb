# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::Viewports do
  VCR.configure do |c|
    # the following filter is used on requests to
    # https://analyticsreporting.googleapis.com/v4/reports:batchGet
    c.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization'] &&
         (match = interaction.request.headers['Authorization'].first.match(/^Bearer.+/))
        match[0]
      end
    end

    c.filter_sensitive_data('{"access_token":"removed","expires_in":3599,"token_type":"Bearer"}') do |interaction|
      if (match = interaction.response.body.match(/^{\"access_token.+/))
        match[0]
      end
    end
  end

  before do
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(true)

    VCR.use_cassette('cypress_viewport_updater/google_analytics_after_request_report') do
      @ga = CypressViewportUpdater::GoogleAnalyticsReports
            .new
            .request_reports
      @viewports = described_class.new(user_report: @ga.user_report)
    end
  end

  describe '#new' do
    it 'returns a new instance' do
      expect(@viewports).to be_an_instance_of(described_class)
    end
  end

  describe '#create' do
    it 'returns self' do
      object_id_before = @viewports.object_id
      object_id_after = @viewports.create(viewport_report: @ga.viewport_report).object_id
      expect(object_id_before).to eq(object_id_after)
    end
  end

  context 'before #create is called' do
    describe '#mobile' do
      it 'returns an empty array' do
        viewports = @viewports.mobile
        expect(viewports).to be_empty
      end
    end

    describe '#tablet' do
      it 'returns an empty array' do
        viewports = @viewports.tablet
        expect(viewports).to be_empty
      end
    end

    describe '#desktop' do
      it 'returns an empty array' do
        viewports = @viewports.desktop
        expect(viewports).to be_empty
      end
    end
  end

  context 'after #create is called' do
    let!(:viewports) { @viewports.create(viewport_report: @ga.viewport_report) }
    let!(:num_top_viewports) { described_class::NUM_TOP_VIEWPORTS }

    describe '#mobile' do
      it 'returns the correct number of viewport objects' do
        expect(viewports.mobile.count).to eq(num_top_viewports[:mobile])
      end
    end

    describe '#tablet' do
      it 'returns the correct number of viewport objects' do
        expect(viewports.tablet.count).to eq(num_top_viewports[:tablet])
      end
    end

    describe '#desktop' do
      it 'returns the correct number of viewport objects' do
        expect(viewports.desktop.count).to eq(num_top_viewports[:desktop])
      end
    end
  end
end
