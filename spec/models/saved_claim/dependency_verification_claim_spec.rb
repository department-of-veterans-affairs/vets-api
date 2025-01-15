# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::DependencyVerificationClaim do
  let(:claim) { create(:dependency_verification_claim) }
  let(:user_object) { create(:evss_user, :loa3) }

  describe '#regional_office' do
    it 'returns an empty array for regional office' do
      expect(claim.regional_office).to eq([])
    end
  end

  describe '#send_to_central_mail!' do
    it 'sends claim to central mail for processing' do
      claim.send_to_central_mail!
    end

    it 'calls process_attachments! method' do
      expect(claim).to receive(:process_attachments!)
      claim.send_to_central_mail!
    end
  end
end
