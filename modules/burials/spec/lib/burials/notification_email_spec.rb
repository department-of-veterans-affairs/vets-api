# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Burials::NotificationEmail do
  let(:saved_claim) { create(:burials_saved_claim) }
  let(:vanotify) { double(send_email: true) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(Burials::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:burials).and_call_original

      api_key = Settings.vanotify.services['21p_530ez'].api_key
      callback_options = { callback_klass: Burials::NotificationCallback.to_s, callback_metadata: be_a(Hash) }

      expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(vanotify)
      expect(vanotify).to receive(:send_email).with(
        {
          email_address: saved_claim.email,
          template_id: Settings.vanotify.services['21p_530ez'].email.confirmation.template_id,
          personalisation: be_a(Hash)
        }.compact
      )

      described_class.new(23).deliver(:confirmation)
    end

    context 'date_received fallback logic' do
      subject { described_class.new(saved_claim.id) }

      it 'uses lighthouse_updated_at when available' do
        lighthouse_date = Time.current

        form_submission_attempt = double('form_submission_attempt', lighthouse_updated_at: lighthouse_date)
        form_submission = double('form_submission', form_submission_attempts: [form_submission_attempt])

        allow(saved_claim).to receive(:form_submissions).and_return([form_submission])

        expect(subject.send(:date_received).to_date).to eq(lighthouse_date.to_date)
      end

      it 'falls back to submitted_at when lighthouse date is nil' do
        allow(saved_claim).to receive(:form_submissions).and_return(nil)

        expect(subject.send(:date_received)).to eq(saved_claim.submitted_at)
      end

      it 'falls back to created_at when both previous dates are nil' do
        allow(saved_claim).to receive_messages(
          form_submissions: nil,
          submitted_at: nil
        )

        expect(subject.send(:date_received)).to eq(saved_claim.created_at)
      end
    end
  end
end
