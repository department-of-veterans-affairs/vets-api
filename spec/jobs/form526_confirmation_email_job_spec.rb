# frozen_string_literal: true

require 'rails_helper'
require 'notifications/client'

RSpec.describe Form526ConfirmationEmailJob do
  before { Sidekiq::Worker.clear_all }

  describe '#perform' do
    context 'defaults' do
      it 'sends a confirmation email' do
        email_address = 'foo@example.com'
        email_response = {
          'content': {
            'body': '<html><body><h1>Hello</h1> World.</body></html>',
            'from_email': 'from_email',
            'subject': 'Hello World'
          },
          'id': '123456789',
          'reference': nil,
          'scheduled_for': nil,
          'template': {
            'id': Settings.notifications_api.template_id,
            'uri': 'template_url',
            'version': 1
          },
          'uri': 'url'
        }
        notification_client = double('Notifications::Client', { send_email: email_response })

        allow(Notifications::Client).to receive(:new).and_return(notification_client)

        expect(notification_client).to receive(:send_email).with(
          {
            email_address: email_address,
            template_id: Settings.notifications_api.template_id.form526_confirmation_email
          }
        )

        subject.perform(123, email_address)
      end
    end
  end
end
