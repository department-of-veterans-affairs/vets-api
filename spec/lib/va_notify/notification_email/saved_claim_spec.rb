# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/notification_email/saved_claim'

RSpec.describe VANotify::NotificationEmail::SavedClaim do
  let(:confirmation_email_template_id) { 'form9999ez_confirmation_email_template_id' }
  let(:vanotify_services_settings) do
    OpenStruct.new(
      form23_42fake: OpenStruct.new(
        api_key: 'fake-api-key',
        email: OpenStruct.new(
          confirmation: OpenStruct.new(
            template_id: confirmation_email_template_id,
            flipper_id: false
          ),
          error: nil,
          received: nil
        )
      )
    )
  end

  let(:fake_claim) { FactoryBot.build(:fake_saved_claim) }
  let(:fake_email) { fake_claim.email }
  let(:notification) { described_class.new(fake_claim) }

  describe '#deliver' do
    before do
      allow(Settings.vanotify).to receive(:services).and_return vanotify_services_settings
    end

    it 'successfully sends a confirmation email' do
      expect(fake_claim).to receive(:va_notification?).with confirmation_email_template_id
      expect(VANotify::EmailJob).to receive(:perform_async).with(
        fake_email,
        confirmation_email_template_id,
        { 'date_submitted' => fake_claim.submitted_at, 'confirmation_number' => fake_claim.confirmation_number }
      )
      expect(fake_claim).to receive(:insert_notification).with(confirmation_email_template_id)

      metric = "#{VANotify::NotificationEmail::STATSD}.deliver_success"
      # monitor_send_failure
      expect(StatsD).to receive(:increment).with(metric, tags: anything)
      expect(Rails.logger).to receive(:info)

      notification.deliver(:confirmation)
    end

    it 'successfully enqueues a confirmation email' do
      at = 23.days.from_now

      expect(fake_claim).to receive(:va_notification?).with confirmation_email_template_id
      expect(VANotify::EmailJob).to receive(:perform_at).with(
        at,
        fake_email,
        confirmation_email_template_id,
        { 'date_submitted' => fake_claim.submitted_at, 'confirmation_number' => fake_claim.confirmation_number }
      )
      expect(fake_claim).to receive(:insert_notification).with(confirmation_email_template_id)

      metric = "#{VANotify::NotificationEmail::STATSD}.deliver_success"
      # monitor_send_failure
      expect(StatsD).to receive(:increment).with(metric, tags: anything)
      expect(Rails.logger).to receive(:info)

      notification.deliver(:confirmation, at:)
    end

    it 'records a failure to send' do
      allow(fake_claim).to receive(:email).and_return nil

      metric = "#{VANotify::NotificationEmail::STATSD}.send_failure"
      # monitor_send_failure
      expect(StatsD).to receive(:increment).with(metric, tags: anything)
      expect(Rails.logger).to receive(:error)

      notification.deliver(:confirmation)
    end

    it 'records a duplicate attempt' do
      allow(fake_claim).to receive(:va_notification?).and_return true

      metric = "#{VANotify::NotificationEmail::STATSD}.duplicate_attempt"
      # monitor_duplicate_attempt
      expect(StatsD).to receive(:increment).with(metric, tags: anything)
      expect(Rails.logger).to receive(:warn)

      notification.deliver(:confirmation)
    end
  end
end
