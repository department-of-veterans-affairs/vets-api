# frozen_string_literal: true

require 'rails_helper'
require 'notifications/client'

RSpec.describe Form526ConfirmationEmailJob, type: :worker do
  before { Sidekiq::Worker.clear_all }

  describe '#perform' do
    let(:notification_client) { double('Notifications::Client') }

    context 'defaults' do
      before do
        @email_address = 'foo@example.com'
        @email_response = {
          'content': {
            'body': '<html><body><h1>Hello</h1> World.</body></html>',
            'from_email': 'from_email',
            'subject': 'Hello World'
          },
          'id': '123456789',
          'reference': nil,
          'scheduled_for': nil,
          'template': {
            'id': Settings.vanotify.template_id.form526_confirmation_email,
            'uri': 'template_url',
            'version': 1
          },
          'uri': 'url'
        }
      end

      it 'sends a confirmation email when an email address is provided' do
        requirements = {
          email_address: @email_address,
          template_id: Settings.vanotify
                               .template_id
                               .form526_confirmation_email
        }
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email).and_return(@email_response)

        expect(notification_client).to receive(:send_email).with(requirements)
        subject.perform(123, @email_address)
      end

      it 'returns one job triggered' do
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email).and_return(@email_response)

        expect do
          Form526ConfirmationEmailJob.perform_async(123, @email_address)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
      end
    end
  end
end
