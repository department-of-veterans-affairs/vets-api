# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/notification_email'

RSpec.describe IncreaseCompensation::NotificationEmail, skip: 'TODO after schema built' do
  let(:saved_claim) { create(:increase_compensation_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(IncreaseCompensation::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:increase_compensation).and_call_original

      args = [
        saved_claim.email,
        Settings.vanotify.services['21-8940'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21-8940'].api_key,
        { callback_klass: IncreaseCompensation::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
