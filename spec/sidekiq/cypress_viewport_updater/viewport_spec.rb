# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::Viewport do
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
      if (match = interaction.response.body.match(/^{"access_token.+/))
        match[0]
      end
    end
  end

  before do
    allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(true)

    VCR.use_cassette('cypress_viewport_updater/google_analytics_after_request_report') do
      ga = CypressViewportUpdater::GoogleAnalyticsReports
           .new
           .request_reports
      total_users = ga.user_report.data.totals.first.values.first.to_f
      row = ga.viewport_report.data.rows.first
      @viewport = described_class.new(row:, rank: 1, total_users:)
    end
  end

  describe '#new' do
    it 'returns a new instance' do
      expect(@viewport).to be_an_instance_of(described_class)
    end
  end

  describe '#list' do
    it 'returns the correct value' do
      expect(@viewport.list).to eq('VA Top Desktop Viewports')
    end
  end

  describe '#rank' do
    it 'returns the correct value' do
      expect(@viewport.rank).to eq(1)
    end
  end

  describe '#devicesWithViewport' do
    it 'returns the correct value' do
      expect(@viewport.devicesWithViewport).to eq('This property is not set for desktops.')
    end
  end

  describe '#percentTraffic' do
    it 'returns the correct value' do
      expect(@viewport.percentTraffic).to eq('10.3%')
    end
  end

  describe '#percentTrafficPeriod' do
    let(:prev_month) { Time.zone.today.prev_month }

    before do
      Timecop.freeze(prev_month)
    end

    after { Timecop.return }

    it 'returns the correct value' do
      beginning_of_month = prev_month.beginning_of_month.strftime('%m/%d/%Y')
      end_of_month = prev_month.end_of_month.strftime('%m/%d/%Y')
      expect(@viewport.percentTrafficPeriod).to eq("From: #{beginning_of_month}, To: #{end_of_month}")
      expect(@viewport.percentTrafficPeriod).to include(beginning_of_month)
    end
  end

  describe '#viewportPreset' do
    it 'returns the correct value' do
      expect(@viewport.viewportPreset).to eq('va-top-desktop-1')
    end
  end

  describe '#width' do
    it 'returns the correct value' do
      expect(@viewport.width).to eq(1920)
    end
  end

  describe '#height' do
    it 'returns the correct value' do
      expect(@viewport.height).to eq(1080)
    end
  end
end
