# frozen_string_literal: true

require 'rails_helper'
require 'veteran_facing_services/notification_email/saved_claim'

RSpec.describe VeteranFacingServices::NotificationEmail::SavedClaim do
  let(:confirmation_email_template_id) { 'form9999ez_confirmation_email_template_id' }
  let(:error_email_template_id) { 'form9999ez_error_email_template_id' }
  let(:error_email_flipper_id) { 'form9999ez_error_email_flipper_id' }

  let(:vanotify_services_settings) do
    OpenStruct.new(
      form23_42fake: OpenStruct.new(
        api_key: 'fake-api-key',
        email: OpenStruct.new(
          confirmation: OpenStruct.new(
            template_id: confirmation_email_template_id,
            flipper_id: false
          ),
          error: OpenStruct.new(
            template_id: error_email_template_id,
            flipper_id: error_email_flipper_id
          ),
          received: nil,
          no_config: nil,
          no_template: OpenStruct.new(
            template_id: nil,
            flipper_id: false
          )
        )
      )
    )
  end

  let(:fake_claim) { build(:fake_saved_claim) }
  let(:fake_email) { fake_claim.email }
  let(:notification) { described_class.new(fake_claim.id) }

  before do
    allow(Settings.vanotify).to receive(:services).and_return vanotify_services_settings
    allow(SavedClaim).to receive(:find).and_return(fake_claim)
  end

  describe '#deliver' do
    context 'with a valid template_id and no flipper_id' do
      it 'successfully sends a confirmation email' do
        expect(fake_claim).to receive(:va_notification?).with confirmation_email_template_id
        expect(VANotify::EmailJob).to receive(:perform_async).with(
          fake_email,
          confirmation_email_template_id,
          { 'date_submitted' => fake_claim.submitted_at, 'confirmation_number' => fake_claim.confirmation_number },
          vanotify_services_settings.form23_42fake.api_key,
          { callback_klass: VeteranFacingServices::NotificationCallback::SavedClaim.to_s,
            callback_metadata: anything }
        )
        expect(fake_claim).to receive(:insert_notification).with(confirmation_email_template_id)

        metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.deliver_success"
        # monitor_deliver_success
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
          { 'date_submitted' => fake_claim.submitted_at, 'confirmation_number' => fake_claim.confirmation_number },
          vanotify_services_settings.form23_42fake.api_key,
          { callback_klass: VeteranFacingServices::NotificationCallback::SavedClaim.to_s,
            callback_metadata: anything }
        )
        expect(fake_claim).to receive(:insert_notification).with(confirmation_email_template_id)

        metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.deliver_success"
        # monitor_deliver_success
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:info)

        notification.deliver(:confirmation, at:)
      end
    end

    context 'with a valid template_id and flipper_id' do
      it 'successfully sends when the flipper is enabled' do
        allow(Flipper).to receive(:enabled?).with(:"#{error_email_flipper_id}").and_return true

        expect(VANotify::EmailJob).to receive(:perform_async)
        expect(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:info) # confirmation of the email sending
        expect(fake_claim).to receive(:insert_notification).with(error_email_template_id)

        notification.deliver(:error)
      end

      it 'does not send when the flipper is disabled' do
        allow(Flipper).to receive(:enabled?).with(:"#{error_email_flipper_id}").and_return false

        expect(VANotify::EmailJob).not_to receive(:perform_async)
        expect(StatsD).not_to receive(:increment)
        expect(Rails.logger).not_to receive(:info) # confirmation of the email sending

        notification.deliver(:error)
      end
    end

    context 'with invalid email type' do
      it 'records a failure to send' do
        metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.send_failure"
        # monitor_send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(VANotify::EmailJob).not_to receive(:perform_async)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver('foobar')
      end
    end

    context 'with missing email config' do
      it 'records a failure to send' do
        metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.send_failure"
        # monitor_send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(VANotify::EmailJob).not_to receive(:perform_async)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver(:no_config)
      end
    end

    context 'with missing email template' do
      it 'records a failure to send' do
        metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.send_failure"
        # monitor_send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(VANotify::EmailJob).not_to receive(:perform_async)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver(:no_template)
      end
    end

    context 'with no email' do
      it 'records a failure to send' do
        allow(fake_claim).to receive(:email).and_return nil

        metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.send_failure"
        # monitor_send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(VANotify::EmailJob).not_to receive(:perform_async)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver(:confirmation)
      end
    end

    it 'records a duplicate attempt' do
      allow(fake_claim).to receive(:va_notification?).and_return true

      metric = "#{VeteranFacingServices::NotificationEmail::STATSD}.duplicate_attempt"
      # monitor_duplicate_attempt
      expect(StatsD).to receive(:increment).with(metric, tags: anything)
      expect(Rails.logger).to receive(:warn)

      expect(VANotify::EmailJob).not_to receive(:perform_async)

      notification.deliver(:confirmation)
    end
  end
end
