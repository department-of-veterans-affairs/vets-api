# frozen_string_literal: true

class PreneedsSubmissionsReportMailer < ApplicationMailer
  RECIPIENTS = %w[
    johnny@oddball.io
    Ronald.Newcomb@va.gov
    Anthony.Tignola@va.gov
    Ashutosh.Shah@va.gov
    Caitlyn.McIntosh@va.gov
  ].freeze

  def build(data)
    @start_date = data[:start_date]
    @end_date = data[:end_date]
    @successes_count = data[:successes_count]
    @error_persisting_count = data[:error_persisting_count]
    @server_unavailable_count = data[:server_unavailable_count]
    @other_errors_count = data[:other_errors_count]

    opt = {}
    opt[:to] = FeatureFlipper.staging_email? ? 'johnny@oddball.io' : RECIPIENTS.clone

    template = File.read('app/mailers/views/preneeds_submissions_report.erb')

    mail(
      opt.merge(
        subject: 'Preneeds submissions report',
        body: ERB.new(template).result(binding),
        content_type: 'text/html'
      )
    )
  end
end
