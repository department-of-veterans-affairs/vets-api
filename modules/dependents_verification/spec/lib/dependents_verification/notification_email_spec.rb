# frozen_string_literal: true

require 'rails_helper'
require 'dependents_verification/notification_callback'
require 'dependents_verification/notification_email'

RSpec.describe DependentsVerification::NotificationEmail do
  let(:saved_claim) { create(:dependents_verification_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(DependentsVerification::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:dependents_verification).and_call_original

      args = [
        saved_claim.email,
        Settings.vanotify.services[210_538].email.submitted.template_id,
        {
          'date_received' => saved_claim.form_submissions.last&.form_submission_attempts&.last&.lighthouse_updated_at,
          'date_submitted' => saved_claim.submitted_at,
          'confirmation_number' => saved_claim.confirmation_number,
          'first_name' => saved_claim.veteran_first_name.titleize
        },
        Settings.vanotify.services[210_538].api_key,
        { callback_klass: DependentsVerification::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
