# frozen_string_literal: true

class DirectDepositMailer < ApplicationMailer
  SUBJECT = 'Confirmation - Your direct deposit information changed on VA.gov'
  GA_CAMPAIGN_NAME = 'direct-deposit-update' # TODO: confirm
  GA_DOCUMENT_PATH = '/placeholder' # TODO: replace
  GA_LABEL = 'placeholder' # TODO: replace

  def build(email, google_analytics_client_id)
    @google_analytics_client_id = google_analytics_client_id
    @google_analytics_tracking_id = Settings.google_analytics_tracking_id

    template = File.read('app/mailers/views/direct_deposit.html.erb')

    mail(
      to: email,
      subject: SUBJECT,
      content_type: 'text/html',
      body: ERB.new(template).result(binding)
    )
  end
end
