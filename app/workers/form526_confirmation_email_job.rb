require 'notifications/client'
# frozen_string_literal: true

class Form526ConfirmationEmailJob
  include Sidekiq::Worker
  sidekiq_options expires_in: 1.day

  def perform(id, email='')
    client = Notifications::Client.new(
      Settings.notifications_api.secret_token,
      Settings.notifications_api.client_url
    )
    email_response = client.send_email(
      email_address: email,
      template_id: Settings.notifications_api.template_id
    )
    
    puts "Id: #{id}"
    puts "Email was sent with id: #{email_response[:id]}"
  end
end
