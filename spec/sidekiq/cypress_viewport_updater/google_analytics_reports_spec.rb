# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::GoogleAnalyticsReports do
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
  end

  describe '#new' do
    it 'returns a new instance' do
      google_analytics = CypressViewportUpdater::GoogleAnalyticsReports.new
      expect(google_analytics).to be_an_instance_of(described_class)
    end
  end

  context 'before #request_report is called' do
    before do
      @google_analytics = CypressViewportUpdater::GoogleAnalyticsReports.new
    end

    describe '#user_report' do
      it 'returns nil' do
        report = @google_analytics.user_report
        expect(report).to be_nil
      end
    end

    describe '#viewport_report' do
      it 'returns nil' do
        report = @google_analytics.viewport_report
        expect(report).to be_nil
      end
    end
  end

  context 'after #request_report is called' do
    before do
      VCR.use_cassette('cypress_viewport_updater/google_analytics_request_report') do
        @request_report = CypressViewportUpdater::GoogleAnalyticsReports
                          .new
                          .request_reports
      end
    end

    describe '#user_report' do
      it 'returns a report object' do
        report = @request_report.user_report
        klass = 'Google::Apis::AnalyticsreportingV4::Report'
        expect(report.class.to_s).to eq(klass)
      end

      it 'returns a report object with metric name ga:users' do
        metric_name = @request_report.user_report.column_header.metric_header.metric_header_entries.first.name
        expect(metric_name).to eq('ga:users')
      end

      it 'returns a report object that has a row count of 1' do
        row_count = @request_report.user_report.data.row_count
        expect(row_count).to eq(1)
      end

      it 'returns a report object that has a total number of users' do
        total_users = @request_report.user_report.data.rows.first.metrics.first.values.first
        expect(total_users).to eq('12599714')
      end
    end

    describe '#viewport_report' do
      it 'returns a report object' do
        report = @request_report.viewport_report
        klass = 'Google::Apis::AnalyticsreportingV4::Report'
        expect(report.class.to_s).to eq(klass)
      end

      it 'returns a report object with metric name ga:users' do
        metric_name = @request_report.viewport_report.column_header.metric_header.metric_header_entries.first.name
        expect(metric_name).to eq('ga:users')
      end

      it 'returns a report object with primary dimension ga:deviceCategory' do
        primary_dimension = @request_report.viewport_report.column_header.dimensions.first
        expect(primary_dimension).to eq('ga:deviceCategory')
      end

      it 'returns a report object with secondary dimension ga:screenResolution' do
        secondary_dimension = @request_report.viewport_report.column_header.dimensions.second
        expect(secondary_dimension).to eq('ga:screenResolution')
      end

      it 'returns a report object that has 100 results' do
        results_total = @request_report.viewport_report.data.rows.count
        expect(results_total).to eq(100)
      end

      it 'returns a report object that includes mobile devices' do
        includes_mobile = @request_report.viewport_report.data.rows.any? do |row|
          row.dimensions.first == 'mobile'
        end

        expect(includes_mobile).to be true
      end

      it 'returns a report object that includes tablet devices' do
        includes_tablet = @request_report.viewport_report.data.rows.any? do |row|
          row.dimensions.first == 'tablet'
        end

        expect(includes_tablet).to be true
      end

      it 'returns a report object that includes desktop devices' do
        includes_desktop = @request_report.viewport_report.data.rows.any? do |row|
          row.dimensions.first == 'desktop'
        end

        expect(includes_desktop).to be true
      end

      it 'returns a report object that includes screen resolutions' do
        includes_screen_resolutions = @request_report.viewport_report.data.rows.any? do |row|
          /\d+x\d+/.match(row.dimensions.second)
        end

        expect(includes_screen_resolutions).to be true
      end
    end
  end
end
