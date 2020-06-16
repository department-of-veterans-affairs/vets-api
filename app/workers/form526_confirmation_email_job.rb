# frozen_string_literal: true

require 'notifications/client'

class Form526ConfirmationEmailJob
  include Sidekiq::Worker
  sidekiq_options expires_in: 1.day

  def perform(_id, email = '')
    @notify_client ||= Notifications::Client.new(
      Settings.notifications_api.secret_token,
      Settings.notifications_api.client_url
    )
    @notify_client.send_email(
      email_address: email,
      template_id: Settings.notifications_api.template_id.form526_confirmation_email
    )
  end
end
