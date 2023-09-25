# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DirectDepositEmailJob, type: :model do
  describe '.send_to_emails' do
    context 'when multiple emails are passed in' do
      it 'sends an email for each address' do
        emails = %w[
          email1@mail.com
          email2@mail.com
        ]

        emails.each do |email|
          expect(described_class).to receive(:perform_async).with(email, nil, :ch33)
        end

        described_class.send_to_emails(emails, nil, :ch33)
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

        described_class.send_to_emails([], nil, :ch33)
      end
    end
  end

  describe '#perform' do
    it 'sends a confirmation email' do
      mail = double('mail')
      allow(DirectDepositMailer).to receive(:build).with('test@example.com', 123_456_789, :comp_pen).and_return(mail)
      expect(mail).to receive(:deliver_now)
      subject.perform('test@example.com', 123_456_789, :comp_pen)
    end
  end
end
