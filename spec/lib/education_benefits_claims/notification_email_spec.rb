# frozen_string_literal: true

require 'rails_helper'
require 'education_benefits_claims/notification_email'

RSpec.describe EducationBenefitsClaims::NotificationEmail do
  let(:saved_claim) { create(:va0989) }
  let(:vanotify) { double(send_email: true) }

  describe '#deliver' do
    it 'successfully sends an email' do
      api_key = Settings.vanotify.services['22_0989'].api_key
      callback_options = { callback_klass: EducationBenefitsClaims::NotificationCallback.to_s, callback_metadata: be_a(Hash) }

      expect(VaNotify::Service).to receive(:new).with(api_key, callback_options).and_return(vanotify)
      expect(vanotify).to receive(:send_email).with(
        {
          email_address: saved_claim.email,
          template_id: Settings.vanotify.services['22_0989'].email.error.template_id,
          personalisation: be_a(Hash)
        }.compact
      )

      described_class.new(saved_claim.id).deliver(:error)
    end
  end
end
