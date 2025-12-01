# frozen_string_literal: true

require 'rails_helper'
require 'employment_questionnaires/notification_email'

RSpec.describe EmploymentQuestionnaires::NotificationEmail, skip: 'TODO after schema built' do
  let(:saved_claim) { create(:employment_questionnaires_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(EmploymentQuestionnaires::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:employment_questionnaires).and_call_original

      args = [
        saved_claim.email,
        Settings.vanotify.services['21_4140'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21_4140'].api_key,
        { callback_klass: EmploymentQuestionnaires::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
