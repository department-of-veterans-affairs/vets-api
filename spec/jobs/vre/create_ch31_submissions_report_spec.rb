# frozen_string_literal: true

require 'rails_helper'

describe VRE::CreateCh31SubmissionsReport do
  describe '#get_claims_submitted_in_range' do
    let!(:vre_claim1) do
      create :veteran_readiness_employment_claim, regional_office: '377 - San Diego'
    end
    let!(:vre_claim2) do
      create :veteran_readiness_employment_claim, regional_office: '349 - Waco'
    end
    let!(:vre_claim3) do
      create :veteran_readiness_employment_claim, regional_office: '351 - Muskogee'
    end

    before do
      vre_claim1.update(updated_at: 3.minutes.ago)
      vre_claim2.update(updated_at: 2.minutes.ago)
      vre_claim3.update(updated_at: 1.minute.ago)
    end

    it 'sorts them by Regional Office' do
      expected = [vre_claim2.id, vre_claim3.id, vre_claim1.id]
      result = described_class.new.get_claims_submitted_in_range.map(&:id)
      expect(result).to eq(expected)
    end
  end
end
