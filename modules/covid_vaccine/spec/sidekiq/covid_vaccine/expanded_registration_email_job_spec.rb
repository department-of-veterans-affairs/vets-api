# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::ExpandedRegistrationEmailJob, type: :worker do
  subject { described_class.new }

  let(:email_confirmation_id) { nil }
  let(:email) { 'vets.gov.user+0@gmail.com' }
  let(:date) { Time.current.to_s }
  let(:registration_submission) do
    create(:covid_vax_expanded_registration, email_confirmation_id:)
  end

  around do |example|
    with_settings(Settings.vanotify, client_url: 'https://fake-vanotify-host.example.com') do
      with_settings(Settings.vanotify.services.va_gov, api_key: "testkey-#{SecureRandom.uuid}-#{SecureRandom.uuid}") do
        example.run
      end
    end
  end

  describe '#perform' do
    it 'logs message to sentry and raises if no submission exists' do
      with_settings(Settings.sentry, dsn: 'T') do
        expect(VaNotify::Service).not_to receive(:new)
        expect(Raven).to receive(:capture_exception)
        expect { subject.perform('non-existent-submission-id') }.to raise_error(StandardError)
      end
    end

    context 'when an email confirmation ID exists' do
      let(:email_confirmation_id) { 1234 }

      it 'avoid sending an email if an email confirmation id is already present' do
        expect(VaNotify::Service).not_to receive(:new)
        subject.perform(registration_submission.id)
      end
    end

    context 'with a valid submission' do
      it 'updates the record with a response id' do
        VCR.use_cassette('covid_vaccine/vanotify/send_email', match_requests_on: %i[method path]) do
          subject.perform(registration_submission.id)
          registration_submission.reload
          expect(registration_submission.email_confirmation_id).to be_truthy
        end
      end

      it 'increments StatsD the record with a response id' do
        VCR.use_cassette('covid_vaccine/vanotify/send_email', match_requests_on: %i[method path]) do
          allow(StatsD).to receive(:increment)
          expect(StatsD).to receive(:increment).with('worker.covid_vaccine_expanded_registration_email.success')
          subject.perform(registration_submission.id)
          registration_submission.reload
          expect(registration_submission.email_confirmation_id).to be_truthy
        end
      end
    end

    context 'with an error response from VANotify' do
      it 'raises an exception' do
        expect_any_instance_of(VaNotify::Service).to receive(:send_email)
          .and_raise(Common::Exceptions::BadGateway)
        expect(StatsD).to receive(:increment).with('worker.covid_vaccine_expanded_registration_email.error')
        expect { subject.perform(registration_submission.id) }.to raise_error(StandardError)
      end

      it 'increments the StatsD error counter' do
        expect_any_instance_of(VaNotify::Service).to receive(:send_email)
          .and_raise(StandardError.new('test error'))
        expect(StatsD).to receive(:increment).with('worker.covid_vaccine_expanded_registration_email.error')
        expect { subject.perform(registration_submission.id) }.to raise_error(StandardError)
      end
    end
  end
end
