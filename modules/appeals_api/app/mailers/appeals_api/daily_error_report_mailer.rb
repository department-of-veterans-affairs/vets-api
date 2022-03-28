# frozen_string_literal: true

require 'appeals_api/decision_review_report'

module AppealsApi
  class DailyErrorReportMailer < ApplicationMailer
    def build
      @report = DecisionReviewReport.new
      @friendly_env = (Settings.vsp_environment || Rails.env).titleize

      return if @report.no_faulty_records? && @report.no_stuck_records?

      template = File.read(path)
      body = ERB.new(template).result(binding)

      mail(
        to: Settings.modules_appeals_api.reports.daily_error.recipients,
        subject: "Daily Error Decision Review API report (#{@friendly_env})",
        content_type: 'text/html',
        body: body
      )
    end

    private

    def path
      AppealsApi::Engine.root.join(
        'app',
        'views',
        'appeals_api',
        'daily_error_report_mailer',
        'mailer.html.erb'
      )
    end
  end
end
