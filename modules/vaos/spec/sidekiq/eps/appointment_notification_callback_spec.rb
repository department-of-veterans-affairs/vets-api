# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::AppointmentNotificationCallback, type: :service do
  let(:notification_id) { 'abc123-def456-ghi789' }
  let(:user_uuid) { '12345678-1234-1234-1234-123456789012' }
  let(:appointment_id_last4) { '7890' }
  let(:callback_metadata) do
    {
      'user_uuid' => user_uuid,
      'appointment_id_last4' => appointment_id_last4
    }
  end

  let(:notification) do
    double('notification',
           notification_id:,
           callback_metadata:,
           status:,
           status_reason: 'Test reason')
  end

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '.call' do
    context 'when status is delivered' do
      let(:status) { 'delivered' }

      it 'logs success and increments success metric' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.success",
          tags: ["user_uuid:#{user_uuid}", "appointment_id_last4:#{appointment_id_last4}"]
        )
        expect(Rails.logger).to have_received(:info).with(
          'Appointment status notification delivered',
          {
            notification_id:,
            user_uuid:,
            appointment_id_last4:
          }
        )
        expect(Rails.logger).not_to have_received(:error)
      end
    end

    context 'when status is not delivered' do
      let(:status) { 'permanent-failure' }

      it 'logs failure and increments failure metric' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ["user_uuid:#{user_uuid}", "appointment_id_last4:#{appointment_id_last4}"]
        )
        expect(Rails.logger).to have_received(:error).with(
          'Appointment status notification failed',
          {
            notification_id:,
            user_uuid:,
            appointment_id_last4:,
            status: 'permanent-failure',
            status_reason: 'Test reason'
          }
        )
        expect(Rails.logger).not_to have_received(:info)
      end
    end

    context 'when callback_metadata is missing' do
      let(:status) { 'permanent-failure' }
      let(:callback_metadata) { nil }

      it 'logs error and increments failure metric with missing tags' do
        described_class.call(notification)

        expect(Rails.logger).to have_received(:error).with(
          'Appointment status notification failed',
          {
            notification_id:,
            user_uuid: 'missing',
            appointment_id_last4: 'missing',
            status: 'permanent-failure',
            status_reason: 'Test reason'
          }
        )

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ['user_uuid:missing', 'appointment_id_last4:missing']
        )
        expect(Rails.logger).not_to have_received(:info)
      end
    end
  end
end
