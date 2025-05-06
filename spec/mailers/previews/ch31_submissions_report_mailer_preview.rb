# frozen_string_literal: true

class Ch31SubmissionsReportMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/ch31_submissions_report_mailer

  def build
    claims = [create(:veteran_readiness_employment_claim, updated_at: '2017-07-26 00:00:00 UTC')]
    Ch31SubmissionsReportMailer.build(claims)
  end
end
