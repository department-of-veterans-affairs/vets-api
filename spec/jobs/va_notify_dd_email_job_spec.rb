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
          expect(described_class).to receive(:perform_async).with(email, :ch33)
        end

        described_class.send_to_emails(emails, :ch33)
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

        described_class.send_to_emails([], :ch33)
      end
    end
  end

  describe '#perform' do
    %w[ch33 comp_pen].each do |dd_type|
      context "with a dd type of #{dd_type}" do
        it 'sends a confirmation email' do
          client = double
          expect(VaNotify::Service).to receive(:new).with(Settings.vanotify.services.va_gov.api_key).and_return(client)

          expect(client).to receive(:send_email).with(
            email_address: email,
            template_id: dd_type == 'ch33' ? 'edu_template_id' : 'comp_pen_template_id'
          )

          described_class.new.perform(email, dd_type.to_sym)
        end
      end
    end
  end
end
