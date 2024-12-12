# frozen_string_literal: true

require 'rails_helper'
require 'pensions/notification_email'

RSpec.describe Pensions::NotificationEmail do
  let(:claim) { build(:pensions_module_pension_claim) }

  describe '#deliver' do
    it 'successfully sends an email' do
      expect(Pensions::SavedClaim).to receive(:find).with(23).and_return claim
      expect(Settings.vanotify.services).to receive(:pensions).and_call_original

      args = [claim.email,
              Settings.vanotify.services['21p_527ez'].email.confirmation.template_id,
              {
                'date_submitted' => claim.submitted_at,
                'confirmation_number' => claim.confirmation_number,
                'first_name' => claim.first_name.titleize
              }]
      expect(VANotify::EmailJob).to receive(:perform_async).with(*args)

      described_class.new(23).deliver(:confirmation)
    end
  end
end
