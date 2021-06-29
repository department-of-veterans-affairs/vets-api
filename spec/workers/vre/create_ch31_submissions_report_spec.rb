# frozen_string_literal: true

require 'rails_helper'

describe VRE::CreateCh31SubmissionsReport do
  describe '#perform' do

    let(:vre_claim1) { create :veteran_readiness_employment_claim, regional_office: '377 - San Diego', updated_at: 3.minutes.ago }
    let(:vre_claim2) { create :veteran_readiness_employment_claim, regional_office: '349 - Waco', updated_at: 2.minutes.ago }
    let(:vre_claim3) { create :veteran_readiness_employment_claim, regional_office: '351 - Muskogee', updated_at: 1.minutes.ago }

    it 'sorts them by Regional Office' do
      claims = [vre_claim2, vre_claim3, vre_claim1]
      # expect_any_instance_of(Ch31SubmissionsReportMailer).to receive(:build).with(contain_exactly(claims))

      new_thing = described_class.new
      result = new_thing.get_claims_submitted_in_range
      expected =

      expect(result).to eq(expected)

      # described_class.new.perform
    end
  end
end
