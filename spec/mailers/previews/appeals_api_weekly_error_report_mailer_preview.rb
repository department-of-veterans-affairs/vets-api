# frozen_string_literal: true

class AppealsApiWeeklyErrorReportMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/appeals_api_weekly_error_report_mailer/build
  def build
    recipients = Settings.modules_appeals_api.reports.weekly_error.recipients
    AppealsApi::WeeklyErrorReportMailer.build(
      date_from: Time.zone.now, date_to:  1.week.ago.beginning_of_day,
      friendly_duration: 'Weekly', recipients:
    )
  end
end
