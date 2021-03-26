# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::ExpandedRegistrationEmailJob, type: :worker do
  describe '#perform' do
    subject(:job) { described_class.new.perform(registration_submission.id) }

    let(:email_confirmation_id) { nil }
    let(:registration_submission) { create(:covid_vax_registration, email_confirmation_id: email_confirmation_id) }

    it 'logs message to sentry and returns if no submission exists' do
      expect(VaNotify::Service).not_to receive(:new)
      with_settings(Settings.sentry, dsn: 'T') do
        expect { described_class.new.perform('non-existent-submission-id') }
          .to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with a valid submission that already has email confirmation id' do
      let(:email_confirmation_id) { 1234 }

      it 'the service is not invoked and we return right away' do
        expect(VaNotify::Service).not_to receive(:new)
        job
      end
    end

    context 'with a valid submission that does not already have an email confirmation id' do
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
              email_address: registration_submission.email,
              template_id: Settings.vanotify.template_id.covid_vaccine_expanded_registration,
              personalisation: {
                'date' => registration_submission.created_at,
                'registration_submission_id' => registration_submission.id
              },
              reference: registration_submission.id
            }
          ).and_return(double('EmailResponse', id: 'VANotifyID'))
        described_class.perform_async(registration_submission.id)
        expect(Rails.logger).to receive(:info).with(
          '[StatsD] increment worker.covid_vaccine_expanded_registration_email.success:1'
        ).once
        expect(registration_submission.email_confirmation_id).to be_nil
        expect { described_class.perform_one }.to change(described_class.jobs, :size).from(1).to(0)
        expect(registration_submission.reload.email_confirmation_id).to eq('VANotifyID')
      end

      it 'handles errors' do
        allow(VaNotify::Service).to receive(:new).and_raise(StandardError)

        described_class.perform_async(registration_submission.id)
        expect(Raven).to receive(:capture_exception).with(StandardError, { level: 'error' })
        expect(Raven).to receive(:extra_context).with(sid: 'confirmation_id_uuid')
        expect(Rails.logger).to receive(:info).with(
          '[StatsD] increment worker.covid_vaccine_expanded_registration_email.error:1'
        ).once

        with_settings(Settings.sentry, dsn: 'T') do
          expect(registration_submission.email_confirmation_id).to be_nil
          expect { described_class.perform_one }.to raise_error(StandardError)
          expect(registration_submission.email_confirmation_id).to be_nil
        end
      end
    end
  end
end
