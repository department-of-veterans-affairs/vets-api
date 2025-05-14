# frozen_string_literal: true

require 'rails_helper'
require 'va_notify'
require_relative '../../app/sidekiq/eps/va_notify_appointment_worker'

RSpec.describe Eps::VaNotifyAppointmentWorker, type: :job do
  subject(:worker) { described_class.new }

  let(:user) { build(:user) }
  let(:error_message) { 'Test error message' }
  let(:va_notify_service) { instance_double(VaNotify::Service) }

  before do
    Sidekiq::Job.clear_all
    allow(VaNotify::Service).to receive(:new)
      .with(Settings.vanotify.services.va_gov.api_key)
      .and_return(va_notify_service)
  end

  describe '.perform_async' do
    it 'submits successfully' do
      expect do
        described_class.perform_async(user, error_message)
      end.to change(described_class.jobs, :size).by(1)
    end

    it 'sends email notification' do
      expect(va_notify_service).to receive(:send_email).with(
        email_address: user.va_profile_email,
        template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
        parameters: {
          'error' => error_message
        }
      )
      worker.perform(user, error_message)
    end

    context 'when an error occurs' do
      before do
        allow(va_notify_service).to receive(:send_email).and_raise(StandardError.new('Service unavailable'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and re-raises it' do
        expect(Rails.logger).to receive(:error).with('VA Notify appointment notification failed: Service unavailable')
        expect { worker.perform(user, error_message) }.to raise_error(StandardError, 'Service unavailable')
      end

      it 'has retry configured' do
        expect(described_class.sidekiq_options_hash['retry']).to be_present
      end

      it 'retries in case of failure' do
        expect(described_class.get_sidekiq_options['retry']).to eq(12)

        allow(Sidekiq).to receive(:server?).and_return(false)
        expect(described_class.get_sidekiq_options['retry']).not_to eq(0)
        expect(described_class.get_sidekiq_options['retry']).not_to eq(false)
      end
    end

    context 'when email delivery fails' do
      let(:user_without_email) { build(:user) }

      before do
        allow(user_without_email).to receive(:va_profile_email).and_return(nil)
        allow(va_notify_service).to receive(:send_email).and_raise(StandardError.new('Missing email address'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and raises an exception' do
        expect(Rails.logger).to receive(:error).with('VA Notify appointment notification failed: Missing email address')
        expect { worker.perform(user_without_email, error_message) }.to raise_error(StandardError, 'Missing email address')
      end
    end

    context 'when VA Notify is down' do
      before do
        allow(va_notify_service).to receive(:send_email).and_raise(StandardError.new('Service unavailable'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and raises an exception' do
        expect(Rails.logger).to receive(:error).with('VA Notify appointment notification failed: Service unavailable')
        expect { worker.perform(user, error_message) }.to raise_error(StandardError, 'Service unavailable')
      end
    end
  end
end
