# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::AccreditationTotal, type: :model do
  describe 'validations' do
    it 'allows null values for individual fields' do
      total = described_class.new(
        attorneys: nil,
        claims_agents: 50,
        vso_representatives: 75,
        vso_organizations: 20
      )
      expect(total).to be_valid
    end

    it 'creates a valid record with all fields populated' do
      total = described_class.create!(
        attorneys: 100,
        claims_agents: 50,
        vso_representatives: 75,
        vso_organizations: 20
      )
      expect(total).to be_persisted
    end
  end

  describe 'data integrity' do
    it 'stores integer values for all count fields' do
      total = described_class.new(
        attorneys: 100,
        claims_agents: 50,
        vso_representatives: 75,
        vso_organizations: 20
      )

      expect(total.attorneys).to be_a(Integer)
      expect(total.claims_agents).to be_a(Integer)
      expect(total.vso_representatives).to be_a(Integer)
      expect(total.vso_organizations).to be_a(Integer)
    end

    it 'maintains null values when a count is not updated' do
      total = described_class.create!(
        attorneys: nil,
        claims_agents: 50,
        vso_representatives: nil,
        vso_organizations: 20
      )

      total.reload
      expect(total.attorneys).to be_nil
      expect(total.claims_agents).to eq(50)
      expect(total.vso_representatives).to be_nil
      expect(total.vso_organizations).to eq(20)
    end
  end
end
