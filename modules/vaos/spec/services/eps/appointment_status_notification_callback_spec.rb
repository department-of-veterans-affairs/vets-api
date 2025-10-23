# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::AppointmentStatusNotificationCallback, type: :service do
  let(:notification_id) { 'abc123-def456-ghi789' }
  let(:user_uuid) { '12345678-1234-1234-1234-123456789012' }
  let(:appointment_id_last4) { '7890' }
  let(:created_at) { Time.zone.now }
  let(:sent_at) { 1.minute.from_now }
  let(:completed_at) { 2.minutes.from_now }
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
           status_reason: 'Test reason',
           created_at:,
           sent_at:,
           completed_at:)
  end

  before do
    allow(StatsD).to receive(:increment)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Rails.logger).to receive(:warn)
  end

  describe '.call' do
    context 'when status is delivered' do
      let(:status) { 'delivered' }

      it 'logs success and increments success metric' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.success",
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).not_to have_received(:error)
      end
    end

    context 'when status is permanent-failure' do
      let(:status) { 'permanent-failure' }

      it 'logs failure and increments failure metric' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ['service:community_care_appointments']
        )
        expect(StatsD).to have_received(:increment).with(
          described_class::STATSD_NOTIFY_SILENT_FAILURE,
          tags: described_class::STATSD_CC_SILENT_FAILURE_TAGS
        )
        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback delivery failed',
          {
            notification_id:,
            user_uuid:,
            appointment_id_last4:,
            status: 'permanent-failure',
            created_at:,
            sent_at:,
            completed_at:,
            status_reason: 'Test reason',
            failure_type: 'permanent'
          }
        )
        expect(Rails.logger).not_to have_received(:info)
      end
    end

    context 'when status is temporary-failure' do
      let(:status) { 'temporary-failure' }

      it 'logs failure with temporary failure type' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback delivery failed',
          hash_including(failure_type: 'temporary')
        )
      end
    end

    context 'when status is technical-failure' do
      let(:status) { 'technical-failure' }

      it 'logs failure with technical failure type' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback delivery failed',
          hash_including(failure_type: 'technical')
        )
      end
    end

    context 'when status is unknown' do
      let(:status) { 'some-unknown-status' }

      it 'logs warning and increments unknown_status metric' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.unknown_status",
          tags: ['service:community_care_appointments']
        )
        expect(Rails.logger).to have_received(:warn).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback received unknown status',
          {
            notification_id:,
            user_uuid:,
            appointment_id_last4:,
            status: 'some-unknown-status',
            created_at:,
            sent_at:,
            completed_at:,
            status_reason: 'Test reason'
          }
        )
      end
    end

    context 'when callback_metadata is missing' do
      let(:status) { 'permanent-failure' }
      let(:callback_metadata) { nil }

      it 'logs warning about missing metadata and processes with missing values' do
        described_class.call(notification)

        expect(Rails.logger).to have_received(:warn).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback received missing or incomplete metadata',
          {
            notification_id:,
            metadata_present: false,
            user_uuid_present: false,
            appointment_id_present: false,
            status: 'permanent-failure'
          }
        )

        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback delivery failed',
          {
            notification_id:,
            user_uuid: 'missing',
            appointment_id_last4: 'missing',
            status: 'permanent-failure',
            created_at:,
            sent_at:,
            completed_at:,
            status_reason: 'Test reason',
            failure_type: 'permanent'
          }
        )

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ['service:community_care_appointments']
        )
      end
    end

    context 'when callback_metadata is incomplete' do
      let(:status) { 'permanent-failure' }
      let(:callback_metadata) { { 'user_uuid' => user_uuid } } # missing appointment_id_last4

      it 'logs warning about incomplete metadata' do
        described_class.call(notification)

        expect(Rails.logger).to have_received(:warn).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback received missing or incomplete metadata',
          {
            notification_id:,
            metadata_present: true,
            user_uuid_present: true,
            appointment_id_present: false,
            status: 'permanent-failure'
          }
        )

        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback delivery failed',
          {
            notification_id:,
            user_uuid:,
            appointment_id_last4: 'missing',
            created_at:,
            sent_at:,
            completed_at:,
            status: 'permanent-failure',
            status_reason: 'Test reason',
            failure_type: 'permanent'
          }
        )
        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.failure",
          tags: ['service:community_care_appointments']
        )
      end
    end

    context 'when notification is nil' do
      it 'handles missing notification gracefully' do
        described_class.call(nil)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.missing_notification"
        )
        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback called with nil notification object'
        )
      end
    end

    context 'when an error occurs during processing' do
      let(:status) { 'delivered' }
      let(:error) { StandardError.new('Something went wrong') }

      before do
        allow(notification).to receive(:status).and_raise(error)
      end

      it 'handles callback errors gracefully' do
        described_class.call(notification)

        expect(StatsD).to have_received(:increment).with(
          "#{described_class::STATSD_KEY}.callback_error"
        )
        expect(Rails.logger).to have_received(:error).with(
          'Community Care Appointments: Eps::AppointmentNotificationCallback error processing callback',
          {
            error_class: 'StandardError',
            error_message: 'Something went wrong',
            notification_id:,
            user_uuid:,
            appointment_id_last4:
          }
        )
      end
    end
  end
end
