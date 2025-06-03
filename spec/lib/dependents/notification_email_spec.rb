# frozen_string_literal: true

require 'rails_helper'
require 'dependents/notification_callback'
require 'dependents/notification_email'

RSpec.describe Dependents::NotificationEmail do
  let(:saved_claim) { create(:dependency_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:dependents).exactly(3).times.and_call_original
      args = [
        'vets.gov.user+228@gmail.com',
        Settings.vanotify.services['dependents'].email.submitted686.template_id,
        anything,
        Settings.vanotify.services['dependents'].api_key,
        { callback_klass: Dependents::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted686)
    end
  end
end
