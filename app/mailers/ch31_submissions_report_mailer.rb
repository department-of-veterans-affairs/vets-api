# frozen_string_literal: true

require 'reports/uploader'

class Ch31SubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Chapter 31 Submissions Report'

  def build(submitted_claims)
    opt = {}

    opt[:to] = Settings.veteran_readiness_and_employment.daily_report.emails.dup

    @submitted_claims = submitted_claims
    @total = submitted_claims.size
    template = File.read('app/mailers/views/ch31_submissions_report.html.erb')

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: ERB.new(template).result(binding)
      )
    )
  end
end
