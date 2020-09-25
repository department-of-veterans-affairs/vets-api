# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526ConfirmationEmailJob, type: :worker do
  before { Sidekiq::Worker.clear_all }

  describe '#perform' do
    let(:notification_client) { double('Notifications::Client') }

    context 'with default attributes' do
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

      it 'sends a confirmation email' do
        requirements = {
          email_address: @email_address,
          template_id: Settings.vanotify
                               .template_id
                               .form526_confirmation_email,
          personalisation: {
            'claim_id' => '600191990',
            'date_submitted' => 'July 12, 2020',
            'full_name' => 'first last'
          }
        }
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email).and_return(@email_response)

        expect(notification_client).to receive(:send_email).with(requirements)
        subject.perform({
                          'email' => @email_address,
                          'submitted_claim_id' => '600191990',
                          'date_submitted' => 'July 12, 2020',
                          'full_name' => 'first last'
                        })
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

        personalization_parameters = {
          'email' => @email_address,
          'submitted_claim_id' => '600191990',
          'date_submitted' => 'July 12, 2020',
          'full_name' => 'first last'
        }
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

        personalization_parameters = {
          'email' => @email_address,
          'submitted_claim_id' => '600191990',
          'date_submitted' => 'July 12, 2020',
          'full_name' => 'first last'
        }
        expect(subject).to receive(:log_exception_to_sentry).with(error)
        expect { subject.perform(personalization_parameters) }
          .to raise_error(Common::Exceptions::BackendServiceException)
          .and trigger_statsd_increment('worker.form526_confirmation_email.error')
      end

      it 'returns one job triggered' do
        allow(Notifications::Client).to receive(:new).and_return(notification_client)
        allow(notification_client).to receive(:send_email).and_return(@email_response)

        expect do
          personalization_parameters = {
            'email' => @email_address,
            'submitted_claim_id' => '600191990',
            'date_submitted' => 'July 12, 2020',
            'full_name' => 'first last'
          }
          Form526ConfirmationEmailJob.perform_async(personalization_parameters)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
      end
    end
  end
end
