# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::RegistrationEmailJob, type: :worker do
  describe '#perform' do
    subject(:job) { described_class.perform_async(email, date, confirmation_id) }

    let(:email) { 'fakeemail@email.com' }
    let(:date) { 'December, 10, 2020' }
    let(:confirmation_id) { 'confirmation_id_uuid' }

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
            template_id: Settings.vanotify.template_id.covid_vaccine_registration,
            personalisation: {
              'date' => date,
              'confirmation_id' => confirmation_id
            },
            reference: confirmation_id
          }
        )
      described_class.perform_async(email, date, confirmation_id)
      expect(Rails.logger).to receive(:info).with(
        '[StatsD] increment worker.covid_vaccine_registration_email.success:1'
      ).once
      expect { described_class.perform_one }.to change(described_class.jobs, :size).from(1).to(0)
    end

    it 'handles errors' do
      allow(VaNotify::Service).to receive(:new).and_raise(StandardError)

      described_class.perform_async(email, date, confirmation_id)
      expect(Raven).to receive(:capture_exception).with(StandardError, { level: 'error' })
      expect(Raven).to receive(:extra_context).with(sid: 'confirmation_id_uuid')
      expect(Rails.logger).to receive(:info).with(
        '[StatsD] increment worker.covid_vaccine_registration_email.error:1'
      ).once

      with_settings(Settings.sentry, dsn: 'T') do
        expect { described_class.perform_one }.to raise_error(StandardError)
      end
    end
  end
end
