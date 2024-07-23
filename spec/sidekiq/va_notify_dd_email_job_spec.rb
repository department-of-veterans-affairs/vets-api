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
          expect(described_class).to receive(:perform_async).with(email, 'ch33')
        end

        described_class.send_to_emails(emails, 'ch33')
      end
    end

    context 'when no emails are passed in' do
      it 'logs a message to sentry' do
        expect(described_class).to receive(:log_message_to_sentry).with(
          'Direct Deposit info update: no email address present for confirmation email',
          :info,
          {},
          feature: 'direct_deposit'
        )

        described_class.send_to_emails([], 'ch33')
      end
    end
  end

  describe '#perform' do
    let(:notification_client) { double('Notifications::Client') }

    context 'with a dd type of ch33' do
      it 'sends a confirmation email using the edu template' do
        allow(VaNotify::Service).to receive(:new)
          .with(Settings.vanotify.services.va_gov.api_key).and_return(notification_client)

        expect(notification_client).to receive(:send_email).with(
          email_address: email, template_id: 'edu_template_id'
        )

        described_class.new.perform(email, 'ch33')
      end
    end

    context 'with a dd type of comp_pen' do
      it 'sends a confirmation email using the comp and pen template' do
        allow(VaNotify::Service).to receive(:new)
          .with(Settings.vanotify.services.va_gov.api_key).and_return(notification_client)

        expect(notification_client).to receive(:send_email).with(
          email_address: email, template_id: 'comp_pen_template_id'
        )

        described_class.new.perform(email, 'comp_pen')
      end
    end

    context 'with a dd type of comp_and_pen' do
      it 'sends a confirmation email using the comp and pen template' do
        allow(VaNotify::Service).to receive(:new)
          .with(Settings.vanotify.services.va_gov.api_key).and_return(notification_client)

        expect(notification_client).to receive(:send_email).with(
          email_address: email, template_id: 'comp_pen_template_id'
        )

        described_class.new.perform(email, 'comp_and_pen')
      end
    end

    context 'without a dd type' do
      it 'sends a confirmation email using the direct_deposit template' do
        allow(VaNotify::Service).to receive(:new)
          .with(Settings.vanotify.services.va_gov.api_key).and_return(notification_client)

        expect(notification_client).to receive(:send_email).with(
          email_address: email, template_id: 'direct_deposit_template_id'
        )

        described_class.new.perform(email, nil)
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

      expect(described_class).to receive(:log_exception_to_sentry).with(error)
      expect { subject.perform(email, 'comp_pen') }
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

      expect(described_class).to receive(:log_exception_to_sentry).with(error)
      expect { subject.perform(email, 'comp_and_pen') }
        .to raise_error(Common::Exceptions::BackendServiceException)
        .and trigger_statsd_increment('worker.direct_deposit_confirmation_email.error')
    end
  end

  describe '#get_template' do
    let(:job) { VANotifyDdEmailJob.new }

    context 'when dd_type is nil' do
      it 'returns the direct_deposit template' do
        expect(job.template_type(nil)).to eq('direct_deposit')
      end
    end

    context 'when dd_type is unknown' do
      it 'returns the direct_deposit template' do
        expect(job.template_type('fake')).to eq('direct_deposit')
      end
    end

    context 'when dd_type is comp_pen' do
      it 'returns the direct_deposit_comp_pen template' do
        expect(job.template_type('comp_pen')).to eq('direct_deposit_comp_pen')
      end
    end

    context 'when dd_type is comp_and_pen' do
      it 'returns the direct_deposit_comp_pen template' do
        expect(job.template_type('comp_and_pen')).to eq('direct_deposit_comp_pen')
      end
    end

    context 'when dd_type is edu' do
      it 'returns the direct_deposit_edu template' do
        expect(job.template_type('ch33')).to eq('direct_deposit_edu')
      end
    end
  end
end
