# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::EmailDeliveryStatusCallback do
  let(:base_metadata) do
    {
      'form_number' => 'Form Number',
      'statsd_tags' => {
        'service' => 'representation-management',
        'function' => 'appoint_a_representative_confirmation_email'
      },
      'email_template_id' => '123456789fake'
    }
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
      it 'increments delivery and silent failure metrics' do
        expect(StatsD).to receive(:increment).with(
          'api.vanotify.notifications.delivered',
          service: 'representation-management',
          function: 'appoint_a_representative_confirmation_email'
        )
        expect(StatsD).to receive(:increment).with(
          'silent_failure_avoided',
          service: 'representation-management',
          function: 'appoint_a_representative_confirmation_email'
        )

        described_class.call(build_notification(status: 'delivered'))
      end
    end

    shared_examples 'a failed delivery status' do |status|
      it "logs error and increments #{status} metric" do
        expect(StatsD).to receive(:increment).with(
          "api.vanotify.notifications.#{status}",
          service: 'representation-management',
          function: 'appoint_a_representative_confirmation_email'
        )
        expect(Rails.logger).to receive(:error).with(
          a_string_including(%("status":"#{status}"))
        )

        described_class.call(build_notification(status:))
      end
    end

    include_examples 'a failed delivery status', 'permanent-failure'
    include_examples 'a failed delivery status', 'temporary-failure'

    context 'when status is unrecognized' do
      it 'logs a warning and increments other metric' do
        expect(StatsD).to receive(:increment).with(
          'api.vanotify.notifications.other',
          service: 'representation-management',
          function: 'appoint_a_representative_confirmation_email'
        )
        expect(Rails.logger).to receive(:warn).with(
          a_string_including('"message":"Unhandled callback status"')
        )

        described_class.call(build_notification(status: 'some-weird-status'))
      end
    end

    context 'when callback_metadata is missing statsd_tags' do
      it 'uses fallback service and function tags' do
        metadata = { 'form_number' => 'Form Number' } # missing statsd_tags

        expect(StatsD).to receive(:increment).with(
          'api.vanotify.notifications.delivered',
          service: 'va_notify',
          function: 'callback_status_email'
        )
        expect(StatsD).to receive(:increment).with(
          'silent_failure_avoided',
          service: 'va_notify',
          function: 'callback_status_email'
        )

        described_class.call(build_notification(status: 'delivered', metadata:))
      end
    end
  end
end
