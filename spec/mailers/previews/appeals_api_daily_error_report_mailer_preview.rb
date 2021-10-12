# frozen_string_literal: true

class AppealsApiDailyErrorReportMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/appeals_api_daily_error_report_mailer/build
  def build
    AppealsApi::DailyErrorReportMailer.build
  end
end
