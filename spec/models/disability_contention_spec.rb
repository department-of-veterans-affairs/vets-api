# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DisabilityContention, type: :model do
  describe '.suggested' do
    before do
      create(:disability_contention_arrhythmia)
      create(:disability_contention_arteriosclerosis)
      create(:disability_contention_arthritis)
    end

    it 'finds records that only match the medical term' do
      expect(DisabilityContention.suggested('ar').count).to eq(3)
    end

    it 'refines records that only match the medical term' do
      expect(DisabilityContention.suggested('arte').count).to eq(1)
    end

    it 'finds records that only match the lay term' do
      expect(DisabilityContention.suggested('joint').count).to eq(1)
    end

    it 'find records that match both medical and lay terms' do
      expect(DisabilityContention.suggested('art').count).to eq(3)
    end
  end
end
