# frozen_string_literal: true

require 'rails_helper'

describe VRE::CreateCh31SubmissionsReport do
  describe '#perform' do
    let!(:vre_claim1) { create :veteran_readiness_employment_claim, regional_office: '377 - San Diego', updated_at: 3.minutes.ago }
    let!(:vre_claim2) { create :veteran_readiness_employment_claim, regional_office: '349 - Waco', updated_at: 2.minutes.ago }
    let!(:vre_claim3) { create :veteran_readiness_employment_claim, regional_office: '351 - Muskogee', updated_at: 1.minutes.ago }

    it 'sorts them by Regional Office' do
      expected = [vre_claim2.id, vre_claim3.id, vre_claim1.id]
      result = described_class.new.get_claims_submitted_in_range.ids
      expect(result).to contain_exactly(expected)
    end
  end
end
