# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncreaseCompensation::V0::ClaimsController do
  describe '#short_name' do
    it 'returns a string' do
      expect(controller.short_name).to eq('increase_compensation_claim')
    end
  end

  describe '#claim_class' do
    it 'returns a IncreaseCompensation::SavedClaim class' do
      expect(controller.claim_class).to be(IncreaseCompensation::SavedClaim)
    end
  end
end
