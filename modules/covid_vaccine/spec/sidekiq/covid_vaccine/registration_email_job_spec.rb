# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::RegistrationEmailJob, type: :worker do
  describe '#perform' do
    subject(:job) { described_class.perform_async(email, date, confirmation_id) }

    let(:email) { 'fakeemail@email.com' }
    let(:date) { 'December, 10, 2020' }
    let(:confirmation_id) { 'confirmation_id_uuid' }

    it 'the service is initialized with the correct parameters' do
      test_service_api_key = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      instance = instance_double(VaNotify::Service)
      allow(instance).to receive(:send_email)
      with_settings(
        Settings.vanotify.services.va_gov, { api_key: test_service_api_key }
      ) do
        expect(VaNotify::Service).to receive(:new).with(test_service_api_key).and_return(instance)
        described_class.new.perform(email, date, confirmation_id)
      end
    end

    it 'queues the job' do
      expect { job }
        .to change(described_class.jobs, :size).by(1)
    end

    it 'is in urgent queue' do
      expect(described_class.queue).to eq('default')
    end

    it 'executes perform' do
      instance = instance_double(VaNotify::Service, send_email: { id: '123456789' })
      allow(VaNotify::Service).to receive(:new).and_return(instance)

      expect(instance)
        .to receive(:send_email).with(
          {
            email_address: email,
            template_id: Settings.vanotify.services.va_gov.template_id.covid_vaccine_registration,
            personalisation: {
              'date' => date,
              'confirmation_id' => confirmation_id
            },
            reference: confirmation_id
          }
        )
      described_class.perform_async(email, date, confirmation_id)

      expect { described_class.perform_one }
        .to trigger_statsd_increment('worker.covid_vaccine_registration_email.success')
        .and change(described_class.jobs, :size)
        .from(1)
        .to(0)
    end

    it 'handles errors' do
      allow(VaNotify::Service).to receive(:new).and_raise(StandardError)

      described_class.perform_async(email, date, confirmation_id)
      expect(Raven).to receive(:capture_exception).with(StandardError, { level: 'error' })
      expect(Raven).to receive(:extra_context).with({ sid: 'confirmation_id_uuid' })

      with_settings(Settings.sentry, dsn: 'T') do
        expect { described_class.perform_one }
          .to raise_error(StandardError)
          .and trigger_statsd_increment('worker.covid_vaccine_registration_email.error')
      end
    end
  end
end
