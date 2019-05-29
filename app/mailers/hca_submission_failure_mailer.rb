# frozen_string_literal: true

class HCASubmissionFailureMailer < ApplicationMailer
  # Note: if subject changes, `SubmissionFailureEmailAnalyticsJob#hca_emails` will need to include the new and previous
  # subject lines for at least one job execution (currently daily)
  SUBJECT = "We can't process your health care application"
  GA_CAMPAIGN_NAME = 'hca-failure'
  GA_DOCUMENT_PATH = '/email/health-care/apply/application/introduction'
  GA_LABEL = 'hca--submission-failed'

  def build(email, google_analytics_client_id)
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics_tracking_id

    template = File.read('app/mailers/views/hca_submission_failure.html.erb')

    mail(
      to: email,
      subject: SUBJECT,
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
