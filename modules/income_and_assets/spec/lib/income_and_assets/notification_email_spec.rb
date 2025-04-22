# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncomeAndAssets::NotificationEmail do
  let(:saved_claim) { create(:income_and_assets_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(IncomeAndAssets::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:income_and_assets).and_call_original

      args = [
        saved_claim.email,
        Settings.vanotify.services['21p_0969'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21p_0969'].api_key,
        { callback_klass: IncomeAndAssets::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
