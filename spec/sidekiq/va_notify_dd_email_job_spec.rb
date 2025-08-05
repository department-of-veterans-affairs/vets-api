# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotifyDdEmailJob, type: :model do
  let(:email) { 'user@example.com' }

  describe '.send_to_emails' do
    context 'when multiple emails are passed in' do
      it 'sends an email for each address' do
        emails = %w[
          email1@mail.com
          email2@mail.com
        ]

        emails.each do |email|
          expect(described_class).to receive(:perform_async).with(email)
        end

        described_class.send_to_emails(emails)
      end
    end

    context 'when no emails are passed in' do
      it 'logs info message' do
        expect(Rails.logger).to receive(:info).with(
          event: 'direct_deposit_confirmation_skipped',
          reason: 'missing_email',
          context: {
            feature: 'direct_deposit',
            job: described_class.name
          },
          message: 'No email address present for Direct Deposit confirmation email'
        )

        described_class.send_to_emails([])
      end
    end
  end

  describe '#perform' do
    let(:notification_client) { double('Notifications::Client') }

    context 'with default email template' do
      it 'sends a confirmation email using the direct_deposit template' do
        allow(VaNotify::Service).to receive(:new)
          .with(Settings.vanotify.services.va_gov.api_key).and_return(notification_client)

        expect(notification_client).to receive(:send_email).with(
          email_address: email, template_id: 'direct_deposit_template_id'
        )

        described_class.new.perform(email)
      end
    end

    it 'handles 4xx errors when sending an email' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)

      error = Common::Exceptions::BackendServiceException.new(
        'VANOTIFY_400',
        { source: VaNotify::Service.to_s },
        400,
        'Error'
      )

      allow(notification_client).to receive(:send_email).and_raise(error)

      expect(Rails.logger).to receive(:error)
      expect { subject.perform(email) }
        .to trigger_statsd_increment('worker.direct_deposit_confirmation_email.error')
    end

    it 'handles 5xx errors when sending an email' do
      allow(Notifications::Client).to receive(:new).and_return(notification_client)

      error = Common::Exceptions::BackendServiceException.new(
        'VANOTIFY_500',
        { source: VaNotify::Service.to_s },
        500,
        'Error'
      )

      allow(notification_client).to receive(:send_email).and_raise(error)

      expect(Rails.logger).to receive(:error)
      expect { subject.perform(email) }
        .to raise_error(Common::Exceptions::BackendServiceException)
        .and trigger_statsd_increment('worker.direct_deposit_confirmation_email.error')
    end
  end
end
