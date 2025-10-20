# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsBenefits::NotificationEmail do
  let(:saved_claim) { create(:dependents_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(DependentsBenefits::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:dependents_benefits).and_call_original

      args = [
        saved_claim.parsed_form.dig('dependents_application', 'veteran_contact_information', 'email_address'),
        Settings.vanotify.services['21_686c_674'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21_686c_674'].api_key,
        { callback_klass: DependentsBenefits::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
