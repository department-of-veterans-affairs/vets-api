# frozen_string_literal: true

require 'google/apis/analyticsreporting_v4'

module CypressViewportUpdater
  class GoogleAnalyticsReports
    include Google::Apis::AnalyticsreportingV4
    include Google::Auth
    include SentryLogging

    JSON_CREDENTIALS = Settings.google_analytics_cvu.to_json
    SCOPE = 'https://www.googleapis.com/auth/analytics.readonly'
    VIEW_ID = '176188361'

    def initialize
      @analytics = AnalyticsReportingService.new
      @analytics.authorization = ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(JSON_CREDENTIALS),
        scope: SCOPE
      )
      @reports = nil
    end

    def request_reports
      request = GetReportsRequest.new(report_requests: [
                                        user_report_request,
                                        viewport_report_request
                                      ])
      begin
        @reports = @analytics.batch_get_reports(request).reports
      rescue => e
        log_exception_to_sentry(e)
      end

      self
    end

    def user_report
      @reports[0] if @reports && @reports[0]
    end

    def viewport_report
      @reports[1] if @reports && @reports[1]
    end

    private

    def user_report_request
      ReportRequest.new(
        view_id: VIEW_ID,
        date_ranges: [date_range],
        metrics: [metric_user]
      )
    end

    def viewport_report_request
      ReportRequest.new(
        view_id: VIEW_ID,
        date_ranges: [date_range],
        metrics: [metric_user],
        dimensions: [dimension_device_category, dimension_screen_resolution],
        order_bys: [{ field_name: 'ga:users', sort_order: 'DESCENDING' }],
        page_size: 100
      )
    end

    def date_range
      start_date = CypressViewportUpdater::UpdateCypressViewportsJob::START_DATE
      end_date = CypressViewportUpdater::UpdateCypressViewportsJob::END_DATE
      DateRange.new(start_date:, end_date:)
    end

    def metric_user
      Metric.new(expression: 'ga:users')
    end

    def dimension_device_category
      Dimension.new(name: 'ga:deviceCategory')
    end

    def dimension_screen_resolution
      Dimension.new(name: 'ga:screenResolution')
    end
  end
end
