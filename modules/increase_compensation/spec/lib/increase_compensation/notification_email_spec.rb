# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/notification_email'

RSpec.describe IncreaseCompensation::NotificationEmail do
  let(:saved_claim) { create(:increase_compensation_claim) }

  # describe '#deliver' do
  #   it 'successfully sends an email' do
  #     expect(IncreaseCompensation::SavedClaim).to receive(:find).with(23).and_return saved_claim
  #     expect(Settings.vanotify.services).to receive(:increase_compensation).and_call_original

  #     args = [
  #       saved_claim.email,
  #       Settings.vanotify.services['21_8940v1'].email.submitted.template_id,
  #       anything,
  #       Settings.vanotify.services['21_8940v1'].api_key,
  #       { callback_klass: IncreaseCompensation::NotificationCallback.to_s,
  #         callback_metadata: anything }
  #     ]
  #     expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

  #     described_class.new(23).deliver(:submitted)
  #   end
  # end

  describe '#claim_class' do
    it 'returns a SavedClaim class' do
      # expect(IncreaseCompensation::SavedClaim).to receive(:find).with(23).and_return saved_claim
      notifier = described_class.new(23)
      expect(notifier.send(:claim_class)).to be(IncreaseCompensation::SavedClaim)
    end
  end

  # describe '#first_name' do
  #   it 'returns the veterans first name' do
  #     # expect(IncreaseCompensation::SavedClaim).to receive(:find).with(23).and_return saved_claim
  #     notifier = described_class.new(23)
  #     expect(notifier.send(:first_name)).to eq('Johnny')
  #   end
  # end
end
