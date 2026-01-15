# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'sidekiq/attr_package'
require 'va_notify/default_callback'

RSpec.describe VANotify::DeliveryStatusUpdateJob, type: :worker do
  let(:notification_id) { SecureRandom.uuid }
  let(:template_id) { SecureRandom.uuid }
  let(:attr_package_params_cache_key) { SecureRandom.hex(32) }
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
    allow(Sidekiq::AttrPackage).to receive(:find).with(attr_package_params_cache_key).and_return(notification_params)
    allow(Sidekiq::AttrPackage).to receive(:delete)
  end

  describe '#perform' do
    context 'when retrieving params from AttrPackage' do
      let!(:notification) do
        VANotify::Notification.create(
          notification_id:,
          template_id:,
          source_location: 'original_location',
          callback_metadata: 'some_metadata'
        )
      end

      it 'retrieves notification params from Sidekiq::AttrPackage' do
        described_class.new.perform(notification_id, attr_package_params_cache_key)

        expect(Sidekiq::AttrPackage).to have_received(:find).with(attr_package_params_cache_key)
      end

      it 'updates the notification with retrieved params' do
        expect(notification.status).to be_nil

        described_class.new.perform(notification_id, attr_package_params_cache_key)

        notification.reload
        expect(notification.status).to eq('delivered')
        expect(notification.source_location).to eq('some_location')
      end
    end

    context 'when AttrPackage.find returns nil' do
      before do
        allow(Sidekiq::AttrPackage).to receive(:find).with(attr_package_params_cache_key).and_return(nil)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs an error about missing cached params' do
        described_class.new.perform(notification_id, attr_package_params_cache_key)

        expect(Rails.logger).to have_received(:error).with(
          'va_notify delivery_status_update_job - Cached params not found for cache key',
          { notification_id:, attr_package_params_cache_key: }
        )
      end

      it 'returns early without processing' do
        expect(VANotify::Notification).not_to receive(:find_by)

        described_class.new.perform(notification_id, attr_package_params_cache_key)
      end

      it 'does not increment success or not_found metrics' do
        described_class.new.perform(notification_id, attr_package_params_cache_key)

        expect(StatsD).not_to have_received(:increment)
          .with('sidekiq.jobs.va_notify_delivery_status_update_job.success')
        expect(StatsD).not_to have_received(:increment)
          .with('sidekiq.jobs.va_notify_delivery_status_update_job.not_found')
      end

      it 'increments cache_miss metric' do
        described_class.new.perform(notification_id, attr_package_params_cache_key)

        expect(StatsD).to have_received(:increment)
          .with('sidekiq.jobs.va_notify_delivery_status_update_job.cached_params_not_found')
      end
    end

    context 'when notification is found' do
      let!(:notification) do
        VANotify::Notification.create(
          notification_id:,
          template_id:,
          source_location: 'original_location',
          callback_metadata: 'some_metadata'
        )
      end

      it 'increments success metric' do
        described_class.new.perform(notification_id, attr_package_params_cache_key)

        expect(StatsD).to have_received(:increment).with('sidekiq.jobs.va_notify_delivery_status_update_job.success')
      end

      it 'deletes the cache key after successful processing' do
        described_class.new.perform(notification_id, attr_package_params_cache_key)

        expect(Sidekiq::AttrPackage).to have_received(:delete).with(attr_package_params_cache_key)
      end
    end

    context 'when notification is not found' do
      it 'raises an error to trigger Sidekiq retry' do
        expect do
          described_class.new.perform(notification_id, attr_package_params_cache_key)
        end.to raise_error(
          VANotify::DeliveryStatusUpdateJob::NotificationNotFound,
          "Notification #{notification_id} not found; retrying until exhaustion"
        )
      end

      it 'does not call callbacks' do
        expect(VANotify::DefaultCallback).not_to receive(:new)
        expect(VANotify::CustomCallback).not_to receive(:new)

        begin
          described_class.new.perform(notification_id, attr_package_params_cache_key)
        rescue VANotify::DeliveryStatusUpdateJob::NotificationNotFound
          # Expected
        end
      end
    end
  end

  describe 'when job has failed' do
    let(:error) { RuntimeError.new('an error occurred!') }

    context 'when cached params are not found' do
      let(:msg) do
        {
          'jid' => 123,
          'class' => described_class.to_s,
          'error_class' => 'VANotify::DeliveryStatusUpdateJob::NotificationNotFound',
          'error_message' => "Notification #{notification_id} not found; retrying until exhaustion",
          'args' => [notification_id, attr_package_params_cache_key]
        }
      end

      before do
        allow(Sidekiq::AttrPackage).to receive(:find).with(attr_package_params_cache_key).and_return(nil)
      end

      it 'logs error with minimal context' do
        expect(Rails.logger).to receive(:error).with(
          'VANotify::DeliveryStatusUpdateJob retries exhausted - notification not found',
          {
            job_id: 123,
            job_class: described_class.to_s,
            error_class: 'VANotify::DeliveryStatusUpdateJob::NotificationNotFound',
            error_message: "Notification #{notification_id} not found; retrying until exhaustion",
            notification_id:,
            attr_package_params_cache_key:
          }
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end

      it 'increments retries_exhausted metric with minimal tags' do
        expect(StatsD).to receive(:increment).with(
          'sidekiq.jobs.va_notify/delivery_status_update_job.retries_exhausted',
          tags: [
            "notification_id:#{notification_id}",
            "attr_package_params_cache_key:#{attr_package_params_cache_key}",
            'notification_type:',
            'status:'
          ]
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end
    end

    context 'when cached params are found' do
      let(:msg) do
        {
          'jid' => 'job123',
          'class' => 'VANotify::DeliveryStatusUpdateJob',
          'error_class' => 'VANotify::DeliveryStatusUpdateJob::NotificationNotFound',
          'error_message' => "Notification #{notification_id} not found; retrying until exhaustion",
          'args' => [notification_id, attr_package_params_cache_key]
        }
      end

      before do
        allow(Sidekiq::AttrPackage).to receive(:find)
          .with(attr_package_params_cache_key).and_return(notification_params)
      end

      it 'retrieves params from AttrPackage' do
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)

        described_class.sidekiq_retries_exhausted_block.call(msg, error)

        expect(Sidekiq::AttrPackage).to have_received(:find).with(attr_package_params_cache_key)
      end

      it 'logs error with full context from cached params' do
        expect(Rails.logger).to receive(:error).with(
          'VANotify::DeliveryStatusUpdateJob retries exhausted - notification not found',
          {
            job_id: 'job123',
            job_class: 'VANotify::DeliveryStatusUpdateJob',
            error_class: 'VANotify::DeliveryStatusUpdateJob::NotificationNotFound',
            error_message: "Notification #{notification_id} not found; retrying until exhaustion",
            notification_id:,
            attr_package_params_cache_key:,
            notification_type: 'email',
            status: 'delivered'
          }
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end

      it 'increments retries_exhausted metric with all tags' do
        expect(StatsD).to receive(:increment).with(
          'sidekiq.jobs.va_notify/delivery_status_update_job.retries_exhausted',
          tags: [
            "notification_id:#{notification_id}",
            "attr_package_params_cache_key:#{attr_package_params_cache_key}",
            'notification_type:email',
            'status:delivered'
          ]
        )

        described_class.sidekiq_retries_exhausted_block.call(msg, error)
      end
    end
  end
end
