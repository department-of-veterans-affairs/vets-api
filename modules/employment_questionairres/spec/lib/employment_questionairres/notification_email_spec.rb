# frozen_string_literal: true

require 'rails_helper'
require 'employment_questionairres/notification_email'

RSpec.describe EmploymentQuestionairres::NotificationEmail, skip: 'TODO after schema built' do
  let(:saved_claim) { create(:employment_questionairres_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(EmploymentQuestionairres::SavedClaim).to receive(:find).with(23).and_return saved_claim
      expect(Settings.vanotify.services).to receive(:employment_questionairres).and_call_original

      args = [
        saved_claim.email,
        Settings.vanotify.services['21_4140'].email.submitted.template_id,
        anything,
        Settings.vanotify.services['21_4140'].api_key,
        { callback_klass: EmploymentQuestionairres::NotificationCallback.to_s,
          callback_metadata: anything }
      ]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:submitted)
    end
  end
end
