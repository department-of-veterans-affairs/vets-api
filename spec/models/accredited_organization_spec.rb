# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedOrganization, type: :model do
  describe 'validations' do
    subject { build(:accredited_organization, poa_code: 'A12') }

    it { is_expected.to have_many(:accredited_individuals).through(:accreditations) }

    it { expect(subject).to validate_presence_of(:ogc_id) }
    it { expect(subject).to validate_presence_of(:poa_code) }
    it { expect(subject).to validate_length_of(:poa_code).is_equal_to(3) }
    it { expect(subject).to validate_uniqueness_of(:poa_code) }
  end

  describe '.find_within_max_distance' do
    # ~6 miles from Washington, D.C.
    let!(:ai1) do
      create(:accredited_organization, poa_code: '123', long: -77.050552, lat: 38.820450,
                                       location: 'POINT(-77.050552 38.820450)')
    end

    # ~35 miles from Washington, D.C.
    let!(:ai2) do
      create(:accredited_organization, poa_code: '234', long: -76.609383, lat: 39.299236,
                                       location: 'POINT(-76.609383 39.299236)')
    end

    # ~47 miles from Washington, D.C.
    let!(:ai3) do
      create(:accredited_organization, poa_code: '345', long: -77.466316, lat: 38.309875,
                                       location: 'POINT(-77.466316 38.309875)')
    end

    # ~57 miles from Washington, D.C.
    let!(:ai4) do
      create(:accredited_organization, poa_code: '456', long: -76.3483, lat: 39.5359,
                                       location: 'POINT(-76.3483 39.5359)')
    end

    context 'when there are organizations within the max search distance' do
      it 'returns all organizations located within the default max distance' do
        # check within 50 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072)

        expect(results.pluck(:id)).to contain_exactly(ai1.id, ai2.id, ai3.id)
      end

      it 'returns all organizations located within the specified max distance' do
        # check within 40 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 64_373.8)

        expect(results.pluck(:id)).to contain_exactly(ai1.id, ai2.id)
      end
    end

    context 'when there are no organizations within the max search distance' do
      it 'returns an empty array' do
        # check within 1 mile of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 1609.344)

        expect(results).to eq([])
      end
    end
  end

  describe '#registration_numbers' do
    let(:organization) { create(:accredited_organization) }

    context 'when the organization has no accredited_individual associations' do
      it 'returns an empty array' do
        expect(organization.registration_numbers).to eq([])
      end
    end

    context 'when the organization has accredited_individual associations' do
      let(:ind1) { create(:accredited_individual, registration_number: '12300') }
      let(:ind2) { create(:accredited_individual, registration_number: '45600') }

      it 'returns an array of all associated registration_numbers' do
        organization.accredited_individuals.push(ind1, ind2)

        expect(organization.reload.registration_numbers).to match_array(%w[12300 45600])
      end
    end
  end
end
