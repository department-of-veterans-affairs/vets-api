# frozen_string_literal: true

# lib
require 'burials/notification_email'

# spec
require 'rails_helper'

RSpec.describe Burials::NotificationEmail do
  let(:claim) { build(:burial_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(SavedClaim::Burial).to receive(:find).with(23).and_return claim
      expect(Settings.vanotify.services).to receive(:burials).and_call_original

      args = [
        claim.email,
        Settings.vanotify.services['21p_530ez'].email.confirmation.template_id,
        anything,
        Settings.vanotify.services['21p_530ez'].api_key,
        { callback_klass: Burials::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:confirmation)
    end
  end
end
