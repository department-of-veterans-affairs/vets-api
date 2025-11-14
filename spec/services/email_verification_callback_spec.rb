# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailVerificationCallback do
  let(:base_metadata) do
    {
      'statsd_tags' => {
        'service' => 'vagov-profile-email-verification',
        'function' => 'initial_verification_email'
      },
      'email_template_id' => 'fake_template_id'
    }
  end

  let(:initial_verification_tags) do
    { tags: { 'service' => 'vagov-profile-email-verification',
              'function' => 'initial_verification_email' } }
  end

  def build_notification(status:, metadata: base_metadata)
    VANotify::Notification.new(
      notification_id: SecureRandom.uuid,
      status:,
      notification_type: 'email',
      status_reason: nil,
      callback_metadata: metadata,
      source_location: 'spec_location'
    )
  end

  describe '.call' do
    context 'when status is delivered' do
      it 'increments delivered and silent failure metrics' do
        expect(StatsD).to receive(:increment).with(
          'api.vanotify.email_verification.delivered',
          initial_verification_tags
        )
        expect(StatsD).to receive(:increment).with(
          'silent_failure_avoided',
          initial_verification_tags
        )

        described_class.call(build_notification(status: 'delivered'))
      end
    end

    context 'when status is temporary-failure' do
      it 'increments temporary failure metrics' do
        expect(StatsD).to receive(:increment).with(
          'api.vanotify.email_verification.temporary_failure',
          initial_verification_tags
        )
        expect(Rails.logger).to receive(:warn).with(
          'Email verification temporary failure',
          hash_including(initial_verification_tags)
        )

        described_class.call(build_notification(status: 'temporary-failure'))
      end
    end

    context 'when status is permanent-failure' do
      it 'increments permanent failure metrics' do
        expect(StatsD).to receive(:increment).with(
          'api.vanotify.email_verification.permanent_failure',
          initial_verification_tags
        )
        expect(Rails.logger).to receive(:error).with(
          'Email verification permanent failure',
          hash_including(initial_verification_tags)
        )

        described_class.call(build_notification(status: 'permanent-failure'))
      end
    end

    context 'when status is unrecognized' do
      it 'increments other metrics' do
        expect(StatsD).to receive(:increment).with(
          'api.vanotify.email_verification.other',
          initial_verification_tags
        )
        expect(Rails.logger).to receive(:warn).with(
          'Email verification unhandled status',
          hash_including(initial_verification_tags)
        )

        described_class.call(build_notification(status: 'some-weird-status'))
      end
    end

    context 'when callback_metadata is missing or malformed' do
      it 'uses fallback tags when statsd_tags are missing' do
        metadata = { 'email_template_id' => 'fake_template_id' }
        fallback_tags = {
          tags: {
            'service' => 'vagov-profile-email-verification',
            'function' => 'email_verification_callback'
          }
        }

        expect(StatsD).to receive(:increment).with(
          'api.vanotify.email_verification.delivered',
          fallback_tags
        )
        expect(StatsD).to receive(:increment).with(
          'silent_failure_avoided',
          fallback_tags
        )

        described_class.call(build_notification(status: 'delivered', metadata:))
      end

      it 'uses fallback tags when metadata parsing fails' do
        notification = build_notification(status: 'delivered')
        allow(notification).to receive(:callback_metadata).and_raise(StandardError.new('Parse error'))

        fallback_tags = {
          tags: {
            'service' => 'vagov-profile-email-verification',
            'function' => 'email_verification_callback'
          }
        }

        expect(StatsD).to receive(:increment).with(
          'api.vanotify.email_verification.delivered',
          fallback_tags
        )
        expect(StatsD).to receive(:increment).with(
          'silent_failure_avoided',
          fallback_tags
        )

        described_class.call(notification)
      end
    end
  end

  describe '.build_log_payload' do
    it 'includes all required fields in log payload' do
      notification = build_notification(status: 'permanent-failure')
      tags = { 'service' => 'test', 'function' => 'test' }

      payload = described_class.send(:build_log_payload, notification, tags)

      expect(payload).to include(
        :notification_id,
        :notification_type,
        :status,
        :status_reason,
        :tags,
        :timestamp
      )
      expect(payload[:status]).to eq('permanent-failure')
      expect(payload[:tags]).to eq(tags)
    end
  end
end
