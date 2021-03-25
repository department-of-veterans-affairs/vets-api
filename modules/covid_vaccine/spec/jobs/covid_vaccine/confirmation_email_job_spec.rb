# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::ConfirmationEmailJob, type: :worker do
  describe '#perform' do
    subject(:job) { described_class.perform_async(email, date, confirmation_id) }

    let(:email) { 'fakeemail@email.com' }
    let(:date) { 'December, 10, 2020' }
    let(:confirmation_id) { 'confirmation_id_uuid' }

    it 'logs message to sentry and returns if no submission exists' do
      expect(Raven).to receive(:capture_message).with('No SID found!', { level: 'warning' })
      expect(Raven).to receive(:extra_context).with(email: email, sid: confirmation_id)
      expect(VaNotify::Service).not_to receive(:new)
      with_settings(Settings.sentry, dsn: 'T') do
        described_class.new.perform(email, date, confirmation_id)
      end
    end

    it 'returns if an email confirmation id exists on submission without logging' do
      expect(VaNotify::Service).not_to receive(:new)
      described_class.new.perform(email, date, confirmation_id)
    end

    context 'with a valid submission that already has email confirmation id' do
      before { create(:covid_vax_registration, sid: confirmation_id, email_confirmation_id: '1234') }

      it 'the service is not invoked and we return right away' do
        expect(VaNotify::Service).not_to receive(:new)
        described_class.new.perform(email, date, confirmation_id)
      end
    end

    context 'with a valid submission that does not have email confirmation id' do
      let(:submission) { create(:covid_vax_registration, sid: confirmation_id) }

      before { submission }

      it 'the service is initialized with the correct parameters with enabled toggle' do
        Flipper.enable(:vanotify_service_enhancement)
        test_service_api_key = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        instance = instance_double(VaNotify::Service)
        allow(instance).to receive(:send_email).and_return(double('EmailResponse', id: 'VANotifyID'))
        with_settings(
          Settings.vanotify.services.va_gov, { api_key: test_service_api_key }
        ) do
          expect(VaNotify::Service).to receive(:new).with(test_service_api_key).and_return(instance)
          expect(submission.email_confirmation_id).to be_nil
          described_class.new.perform(email, date, confirmation_id)
          expect(submission.reload.email_confirmation_id).to eq('VANotifyID')
        end
      end

      it 'the service is initialized with the correct parameters with disabled toggle' do
        Flipper.disable(:vanotify_service_enhancement)
        test_service_api_key = 'baaaaaaa-1111-aaaa-aaaa-aaaaaaaaaaaa-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
        instance = instance_double(VaNotify::Service)
        allow(instance).to receive(:send_email).and_return(double('EmailResponse', id: 'VANotifyID'))
        with_settings(
          Settings.vanotify, { api_key: test_service_api_key }
        ) do
          expect(VaNotify::Service).to receive(:new).with(test_service_api_key).and_return(instance)
          expect(submission.email_confirmation_id).to be_nil
          described_class.new.perform(email, date, confirmation_id)
          expect(submission.reload.email_confirmation_id).to eq('VANotifyID')
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
        instance = instance_double(VaNotify::Service)
        allow(VaNotify::Service).to receive(:new).and_return(instance)

        expect(instance)
          .to receive(:send_email).with(
            {
              email_address: email,
              template_id: Settings.vanotify.template_id.covid_vaccine_confirmation,
              personalisation: {
                'date' => date,
                'confirmation_id' => confirmation_id
              },
              reference: confirmation_id
            }
          ).and_return(double('EmailResponse', id: 'VANotifyID'))
        described_class.perform_async(email, date, confirmation_id)
        expect(Rails.logger).to receive(:info).with(
          '[StatsD] increment worker.covid_vaccine_confirmation_email.success:1'
        ).once
        expect(submission.email_confirmation_id).to be_nil
        expect { described_class.perform_one }.to change(described_class.jobs, :size).from(1).to(0)
        expect(submission.reload.email_confirmation_id).to eq('VANotifyID')
      end

      it 'handles errors' do
        allow(VaNotify::Service).to receive(:new).and_raise(StandardError)

        described_class.perform_async(email, date, confirmation_id)
        expect(Raven).to receive(:capture_exception).with(StandardError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with(sid: 'confirmation_id_uuid')
        expect(Rails.logger).to receive(:info).with(
          '[StatsD] increment worker.covid_vaccine_confirmation_email.error:1'
        ).once

        with_settings(Settings.sentry, dsn: 'T') do
          expect(submission.email_confirmation_id).to be_nil
          expect { described_class.perform_one }.to raise_error(StandardError)
          expect(submission.email_confirmation_id).to be_nil
        end
      end
    end
  end
end
