# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StructuredData::Utilities do
  let(:claim) { build(:burial_claim) }
  let(:bgs_service) { instance_double(LighthouseBGS::Services) }

  describe '#find_dependents' do
    it 'calls LighthouseBGS::Services for claimant lookup' do
      allow(LighthouseBGS::Services).to receive(:new).and_return(bgs_service)

      people_service = OpenStruct.new(find_dependents: { dependent: [] })
      allow(bgs_service).to receive(people: people_service)

      expect(StructuredData::Utilities.find_dependents(123)).to eq([])
    end
  end
end
