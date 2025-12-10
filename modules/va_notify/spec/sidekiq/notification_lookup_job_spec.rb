# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'va_notify/default_callback'

RSpec.describe VANotify::NotificationLookupJob, type: :worker do
  let(:notification_id) { SecureRandom.uuid }
  let(:template_id) { SecureRandom.uuid }
  let(:notification_params) do
    {
      'status' => 'delivered',
      'notification_type' => 'email',
      'to' => 'user@example.com',
      'status_reason' => '',
      'source_location' => 'some_location'
    }
  end

  before do
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    context 'when notification is found' do
      let!(:notification) do
        VANotify::Notification.create(
          notification_id:,
          template_id:,
          source_location: 'original_location',
          callback_metadata: 'some_metadata'
        )
      end

      it 'updates the notification' do
        expect(notification.status).to be_nil

        described_class.new.perform(notification_id, notification_params)

        notification.reload
        expect(notification.status).to eq('delivered')
        expect(notification.source_location).to eq('some_location')
      end

      it 'logs success' do
        allow(Rails.logger).to receive(:info)

        described_class.new.perform(notification_id, notification_params)

        expect(Rails.logger).to have_received(:info).with(
          "va_notify notification_lookup_job - Found and updated notification: #{notification.id}", {
            notification_id: notification.id,
            source_location: 'some_location',
            template_id:,
            callback_metadata: 'some_metadata',
            status: 'delivered',
            status_reason: ''
          }
        )
      end

      it 'increments success metric' do
        described_class.new.perform(notification_id, notification_params)

        expect(StatsD).to have_received(:increment).with('sidekiq.jobs.va_notify_notification_lookup_job.success')
      end
    end

    context 'when notification is not found' do
      it 'logs a warning' do
        allow(Rails.logger).to receive(:warn)

        described_class.new.perform(notification_id, notification_params)

        expect(Rails.logger).to have_received(:warn).with(
          "va_notify notification_lookup_job - Notification still not found: #{notification_id}"
        )
      end

      it 'increments not_found metric' do
        described_class.new.perform(notification_id, notification_params)

        expect(StatsD).to have_received(:increment).with('sidekiq.jobs.va_notify_notification_lookup_job.not_found')
      end

      it 'does not call callbacks' do
        expect(VANotify::DefaultCallback).not_to receive(:new)
        expect(VANotify::CustomCallback).not_to receive(:new)

        described_class.new.perform(notification_id, notification_params)
      end
    end
  end

  describe 'when job has failed' do
    let(:error) { RuntimeError.new('an error occurred!') }

    context 'without notification_type or status' do
      let(:msg) do
        {
          'jid' => 123,
          'class' => described_class.to_s,
          'error_class' => 'ActiveRecord::RecordNotFound',
          'error_message' => 'Not found',
          'args' => [notification_id, {}]
        }
      end

      it 'logs error with context' do
        expect(Rails.logger).to receive(:error).with(
          'VANotify::NotificationLookupJob retries exhausted - notification not found',
          {
            job_id: 123,
            job_class: described_class.to_s,
            error_class: 'ActiveRecord::RecordNotFound',
            error_message: 'Not found',
            notification_id:
          }
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end

      it 'increments retries_exhausted metric with minimal tags' do
        expect(StatsD).to receive(:increment).with(
          'sidekiq.jobs.va_notify/notification_lookup_job.retries_exhausted',
          tags: [
            "notification_id:#{notification_id}",
            'notification_type:',
            'status:'
          ]
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end
    end

    context 'with notification_type and status' do
      let(:msg) do
        {
          'jid' => 'job123',
          'class' => 'VANotify::NotificationLookupJob',
          'error_class' => 'ActiveRecord::RecordNotFound',
          'error_message' => 'Not found',
          'args' => [notification_id, notification_params]
        }
      end

      it 'logs error with full context' do
        expect(Rails.logger).to receive(:error).with(
          'VANotify::NotificationLookupJob retries exhausted - notification not found',
          {
            job_id: 'job123',
            job_class: 'VANotify::NotificationLookupJob',
            error_class: 'ActiveRecord::RecordNotFound',
            error_message: 'Not found',
            notification_id:,
            notification_type: 'email',
            status: 'delivered'
          }
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end

      it 'increments retries_exhausted metric with all tags' do
        expect(StatsD).to receive(:increment).with(
          'sidekiq.jobs.va_notify/notification_lookup_job.retries_exhausted',
          tags: [
            "notification_id:#{notification_id}",
            'notification_type:email',
            'status:delivered'
          ]
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end
    end
  end
end
