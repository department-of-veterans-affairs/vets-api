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
  let(:statsd) { VeteranFacingServices::NotificationEmail::Monitor::STATSD }
  let(:vanotify) { double(send_email: true) }

  before do
    allow(Settings.vanotify).to receive(:services).and_return vanotify_services_settings
    allow(SavedClaim).to receive(:find).and_return(fake_claim)
    allow(VaNotify::Service).to receive(:new).and_return(vanotify)
  end

  describe '#deliver' do
    context 'with a valid template_id and no flipper_id' do
      it 'successfully sends a confirmation email' do
        api_key = vanotify_services_settings.form23_42fake.api_key
        callback_options = { callback_klass: be_a(String), callback_metadata: be_a(Hash) }
        personalization = { 'date_submitted' => fake_claim.submitted_at,
                            'confirmation_number' => fake_claim.confirmation_number }

        expect(fake_claim).to receive(:va_notification?).with confirmation_email_template_id
        expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(vanotify)
        expect(vanotify).to receive(:send_email).with(
          {
            email_address: fake_email,
            template_id: confirmation_email_template_id,
            personalisation: personalization
          }.compact
        )
        expect(fake_claim).to receive(:insert_notification).with(confirmation_email_template_id)

        metric = "#{statsd}.send_success"
        # monitor.send_success
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:info)

        notification.deliver(:confirmation)
      end
    end

    context 'with a valid template_id and flipper_id' do
      it 'successfully sends when the flipper is enabled' do
        allow(Flipper).to receive(:enabled?).with(:"#{error_email_flipper_id}").and_return true

        expect(vanotify).to receive(:send_email)
        expect(StatsD).to receive(:increment)
        expect(Rails.logger).to receive(:info) # confirmation of the email sending
        expect(fake_claim).to receive(:insert_notification).with(error_email_template_id)

        notification.deliver(:error)
      end

      it 'does not send when the flipper is disabled' do
        allow(Flipper).to receive(:enabled?).with(:"#{error_email_flipper_id}").and_return false

        expect(vanotify).not_to receive(:send_email)
        expect(StatsD).not_to receive(:increment)
        expect(Rails.logger).not_to receive(:info) # confirmation of the email sending

        notification.deliver(:error)
      end
    end

    context 'with invalid email type' do
      it 'records a failure to send' do
        metric = "#{statsd}.send_failure"
        # monitor.send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(vanotify).not_to receive(:send_email)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver('foobar')
      end
    end

    context 'with missing email config' do
      it 'records a failure to send' do
        metric = "#{statsd}.send_failure"
        # monitor.send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(vanotify).not_to receive(:send_email)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver(:no_config)
      end
    end

    context 'with missing email template' do
      it 'records a failure to send' do
        metric = "#{statsd}.send_failure"
        # monitor.send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(vanotify).not_to receive(:send_email)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver(:no_template)
      end
    end

    context 'with no email' do
      it 'records a failure to send' do
        allow(fake_claim).to receive(:email).and_return nil

        metric = "#{statsd}.send_failure"
        # monitor.send_failure
        expect(StatsD).to receive(:increment).with(metric, tags: anything)
        expect(Rails.logger).to receive(:error)

        expect(vanotify).not_to receive(:send_email)
        expect(fake_claim).not_to receive(:insert_notification)

        notification.deliver(:confirmation)
      end
    end

    it 'records a duplicate attempt' do
      allow(fake_claim).to receive(:va_notification?).and_return true

      metric = "#{statsd}.duplicate_attempt"
      # monitor.duplicate_attempt
      expect(StatsD).to receive(:increment).with(metric, tags: anything)
      expect(Rails.logger).to receive(:warn)

      expect(vanotify).not_to receive(:send_email)

      notification.deliver(:confirmation)
    end
  end
end
