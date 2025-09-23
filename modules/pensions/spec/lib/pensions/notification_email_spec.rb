# frozen_string_literal: true

require 'rails_helper'
require 'pensions/notification_callback'
require 'pensions/notification_email'

RSpec.describe Pensions::NotificationEmail do
  let(:claim) { create(:pensions_saved_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(Pensions::SavedClaim).to receive(:find).with(23).and_return claim
      expect(Settings.vanotify.services).to receive(:pensions).and_call_original

      args = [
        claim.email,
        Settings.vanotify.services['21p_527ez'].email.confirmation.template_id,
        anything,
        Settings.vanotify.services['21p_527ez'].api_key,
        { callback_klass: Pensions::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:confirmation)
    end

    context 'date_received fallback logic' do
      subject { described_class.new(claim.id) }

      it 'uses lighthouse_updated_at when available' do
        lighthouse_date = Time.current

        form_submission_attempt = double('form_submission_attempt', lighthouse_updated_at: lighthouse_date)
        form_submission = double('form_submission', form_submission_attempts: [form_submission_attempt])

        allow(claim).to receive(:form_submissions).and_return([form_submission])

        expect(subject.send(:date_received).to_date).to eq(lighthouse_date.to_date)
      end

      it 'falls back to submitted_at when lighthouse date is nil' do
        allow(claim).to receive(:form_submissions).and_return(nil)

        expect(subject.send(:date_received)).to eq(claim.submitted_at)
      end

      it 'falls back to created_at when both previous dates are nil' do
        allow(claim).to receive_messages(
          form_submissions: nil,
          submitted_at: nil
        )

        expect(subject.send(:date_received)).to eq(claim.created_at)
      end
    end
  end
end
