# frozen_string_literal: true

class AppealsApiDailyErrorReportMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/appeals_api_daily_error_report_mailer/build
  delegate :build, to: :'AppealsApi::DailyErrorReportMailer'
end
