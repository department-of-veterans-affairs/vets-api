# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526ConfirmationEmailJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:notification_client) { double('Notifications::Client') }

    context 'with default attributes' do
      let(:email_address) { 'foo@example.com' }
      let(:email_response) do
        {
          content: {
            body: '<html><body><h1>Hello</h1> World.</body></html>',
            from_email: 'from_email',
            subject: 'Hello World'
          },
          id: '123456789',
          reference: nil,
          scheduled_for: nil,
          template: {
            id: Settings.vanotify.services.va_gov.template_id.form526_confirmation_email,
            uri: 'template_url',
            version: 1
          },
          uri: 'url'
        }
      end
      let(:personalization_parameters) do
        {
          'email' => email_address,
          'submitted_claim_id' => '600191990',
          'date_submitted' => 'July 12, 2020',
          'first_name' => 'firstname'
        }
      end

      it 'the service is initialized with the correct parameters' do
        test_service_api_key = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        with_settings(
          Settings.vanotify.services.va_gov, { api_key: test_service_api_key }
        ) do
          mocked_notification_service = instance_double('VaNotify::Service')
          allow(VaNotify::Service).to receive(:new).and_return(mocked_notification_service)
          allow(mocked_notification_service).to receive(:send_email).and_return(email_response)
          subject.perform('')
          expect(VaNotify::Service).to have_received(:new).with(test_service_api_key)
        end
      end

      it 'sends a confirmation email' do
        requirements = {
          email_address:,
          template_id: Settings.vanotify
                               .services
                               .va_gov
                               .template_id
                               .form526_confirmation_email,
          personalisation: {
            'claim_id' => '600191990',
            'date_submitted' => 'July 12, 2020',
            'first_name' => 'firstname'
          }
        }
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email).and_return(email_response)

        expect(notification_client).to receive(:send_email).with(requirements)
        subject.perform(personalization_parameters)
      end

      it 'handles 4xx errors when sending an email' do
        allow(Notifications::Client).to receive(:new).and_return(notification_client)

        error = Common::Exceptions::BackendServiceException.new(
          'VANOTIFY_400',
          { source: VaNotify::Service.to_s },
          400,
          'Error'
        )
        allow(notification_client).to receive(:send_email).and_raise(error)

        expect(subject).to receive(:log_exception_to_sentry).with(error)
        expect { subject.perform(personalization_parameters) }
          .to trigger_statsd_increment('worker.form526_confirmation_email.error')
      end

      it 'handles 5xx errors when sending an email' do
        allow(Notifications::Client).to receive(:new).and_return(notification_client)

        error = Common::Exceptions::BackendServiceException.new(
          'VANOTIFY_500',
          { source: VaNotify::Service.to_s },
          500,
          'Error'
        )
        allow(notification_client).to receive(:send_email).and_raise(error)

        expect(subject).to receive(:log_exception_to_sentry).with(error)
        expect { subject.perform(personalization_parameters) }
          .to raise_error(Common::Exceptions::BackendServiceException)
          .and trigger_statsd_increment('worker.form526_confirmation_email.error')
      end

      it 'returns one job triggered' do
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email).and_return(email_response)

        expect do
          Form526ConfirmationEmailJob.perform_async(personalization_parameters)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
      end
    end
  end
end
