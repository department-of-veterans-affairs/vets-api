# frozen_string_literal: true

require 'appeals_api/stats_report'

module AppealsApi
  class StatsReportMailer < ApplicationMailer
    def build(date_from:, date_to:, recipients:, subject:)
      report = AppealsApi::StatsReport.new(date_from, date_to)
      mail(
        content_type: 'text/html',
        to: recipients,
        subject:,
        body: report.text.lines.join('<br>')
      )
    end
  end
end
