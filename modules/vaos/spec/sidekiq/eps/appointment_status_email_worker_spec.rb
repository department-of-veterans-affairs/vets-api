# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::AppointmentStatusEmailWorker, type: :job do
  let(:user_uuid) { 'user123' }
  let(:appointment_id) { '12345' }
  let(:appointment_id_last4) { '2345' }
  let(:error_message) { 'Appointment failed' }
  let(:email) { 'test@example.com' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  let(:va_notify_service) { instance_double(VaNotify::Service) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(VaNotify::Service).to receive(:new).and_return(va_notify_service)
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
    Rails.cache.clear

    redis_client = Eps::RedisClient.new
    redis_client.store_appointment_data(
      uuid: user_uuid,
      appointment_id:,
      email:
    )
  end

  after do
    Rails.cache.clear
  end

  describe '#perform' do
    context 'when successful' do
      before { allow(va_notify_service).to receive(:send_email) }

      it 'sends email notification' do
        subject.perform(user_uuid, appointment_id_last4, error_message)

        expect(va_notify_service).to have_received(:send_email).with(
          email_address: email,
          template_id: Settings.vanotify.services.va_gov.template_id.va_appointment_failure,
          personalisation: { 'error' => error_message }
        )
      end
    end

    context 'when appointment data is missing from Redis' do
      before { Rails.cache.clear }

      it 'logs failure and does not send email' do
        subject.perform(user_uuid, appointment_id_last4, error_message)

        expect(Rails.logger).to have_received(:error).with(
          /missing appointment id/,
          { user_uuid:, appointment_id_last4: }
        )
        allow(va_notify_service).to receive(:send_email)
        expect(va_notify_service).not_to have_received(:send_email)
        check_statsd_failure_increment(user_uuid, appointment_id_last4)
      end
    end

    context 'when email is missing from appointment data' do
      before do
        redis_client = Eps::RedisClient.new
        allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
        allow(redis_client).to receive(:fetch_appointment_data).and_return({ appointment_id:, email: nil })
      end

      it 'logs failure and does not send email' do
        subject.perform(user_uuid, appointment_id_last4, error_message)

        expect(Rails.logger).to have_received(:error).with(
          /missing email/,
          { user_uuid:, appointment_id_last4: }
        )
        allow(va_notify_service).to receive(:send_email)
        expect(va_notify_service).not_to have_received(:send_email)
        check_statsd_failure_increment(user_uuid, appointment_id_last4)
      end
    end

    context 'when VA Notify raises 4xx error' do
      let(:client_error) { VANotify::Error.new(400, 'Bad request') }

      before { allow(va_notify_service).to receive(:send_email).and_raise(client_error) }

      it 'logs permanent failure without retrying' do
        subject.perform(user_uuid, appointment_id_last4, error_message)

        expect(Rails.logger).to have_received(:error).with(
          /upstream error - will not retry: 400/,
          { user_uuid:, appointment_id_last4: }
        )
        check_statsd_failure_increment(user_uuid, appointment_id_last4)
      end
    end

    context 'when VA Notify raises 5xx error' do
      let(:server_error) { VANotify::Error.new(500, 'Server error') }

      before { allow(va_notify_service).to receive(:send_email).and_raise(server_error) }

      it 'logs temporary failure and re-raises for retry' do
        expect { subject.perform(user_uuid, appointment_id_last4, error_message) }
          .to raise_error(VANotify::Error)

        expect(Rails.logger).to have_received(:error).with(
          /upstream error - will retry: 500/,
          { user_uuid:, appointment_id_last4: }
        )
        expect(StatsD).not_to have_received(:increment)
      end
    end

    context 'when unexpected error occurs' do
      let(:unexpected_error) { StandardError.new('Something went wrong') }

      before { allow(va_notify_service).to receive(:send_email).and_raise(unexpected_error) }

      it 'logs unexpected error as permanent failure' do
        subject.perform(user_uuid, appointment_id_last4, error_message)

        expect(Rails.logger).to have_received(:error).with(
          /unexpected error: StandardError/,
          { user_uuid:, appointment_id_last4: }
        )
        check_statsd_failure_increment(user_uuid, appointment_id_last4)
      end
    end
  end

  describe '.sidekiq_retries_exhausted' do
    let(:msg) do
      {
        'error_class' => 'VANotify::Error',
        'error_message' => 'Service unavailable',
        'args' => [user_uuid, appointment_id_last4, error_message]
      }
    end
    let(:exception) { VANotify::Error.new(503, 'Service unavailable') }

    it 'logs retries exhausted' do
      described_class.sidekiq_retries_exhausted_block.call(msg, exception)

      expect(Rails.logger).to have_received(:error).with(
        /retries exhausted: VANotify::Error - Service unavailable/,
        { user_uuid:, appointment_id_last4: }
      )
      check_statsd_failure_increment(user_uuid, appointment_id_last4)
    end
  end

  def check_statsd_failure_increment(uuid, last4)
    expect(StatsD).to have_received(:increment).with(
      "#{described_class::STATSD_KEY}.failure",
      tags: ["user_uuid:#{uuid}", "appointment_id_last4:#{last4}"]
    )
  end
end
