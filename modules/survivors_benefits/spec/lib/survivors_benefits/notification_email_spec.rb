# frozen_string_literal: true

require 'rails_helper'
require 'survivors_benefits/notification_email'

RSpec.describe SurvivorsBenefits::NotificationEmail, skip: 'TODO after schema built' do
  let(:saved_claim) { create(:survivors_benefits_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(SurvivorsBenefits::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:survivors_benefits).and_call_original

      args = [
        saved_claim.email,
        Settings.vanotify.services['21p_534ez'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21p_534ez'].api_key,
        { callback_klass: SurvivorsBenefits::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
