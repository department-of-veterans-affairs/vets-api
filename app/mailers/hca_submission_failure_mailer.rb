# frozen_string_literal: true

class HCASubmissionFailureMailer < ApplicationMailer
  def build(email, google_analytics_client_id)
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics_tracking_id

    template = File.read('app/mailers/views/hca_submission_failure.html.erb')

    mail(
      from: "#{FeatureFlipper.staging_email? ? 'stage.va-notifications' : 'vets.gov'}@public.govdelivery.com",
      to: email,
      subject: "We didn't receive your application",
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
