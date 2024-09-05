# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedIndividual, type: :model do
  describe 'validations' do
    subject { build(:accredited_individual) }

    it { is_expected.to have_many(:accredited_organizations).through(:accreditations) }

    it { expect(subject).to validate_presence_of(:ogc_id) }
    it { expect(subject).to validate_presence_of(:registration_number) }
    it { expect(subject).to validate_presence_of(:individual_type) }
    it { expect(subject).to validate_length_of(:poa_code).is_equal_to(3).allow_blank }

    it {
      expect(subject).to validate_uniqueness_of(:individual_type)
        .scoped_to(:registration_number)
        .ignoring_case_sensitivity
    }

    it {
      expect(subject).to define_enum_for(:individual_type)
        .with_values({
                       'attorney' => 'attorney',
                       'claims_agent' => 'claims_agent',
                       'representative' => 'representative'
                     })
        .backed_by_column_of_type(:string)
    }
  end

  describe '.find_within_max_distance' do
    # ~6 miles from Washington, D.C.
    let!(:ai1) do
      create(:accredited_individual, registration_number: '12300', long: -77.050552, lat: 38.820450,
                                     location: 'POINT(-77.050552 38.820450)')
    end

    # ~35 miles from Washington, D.C.
    let!(:ai2) do
      create(:accredited_individual, registration_number: '23400', long: -76.609383, lat: 39.299236,
                                     location: 'POINT(-76.609383 39.299236)')
    end

    # ~47 miles from Washington, D.C.
    let!(:ai3) do
      create(:accredited_individual, registration_number: '34500', long: -77.466316, lat: 38.309875,
                                     location: 'POINT(-77.466316 38.309875)')
    end

    # ~57 miles from Washington, D.C.
    let!(:ai4) do
      create(:accredited_individual, registration_number: '45600', long: -76.3483, lat: 39.5359,
                                     location: 'POINT(-76.3483 39.5359)')
    end

    context 'when there are individuals within the max search distance' do
      it 'returns all individuals located within the default max distance' do
        # check within 50 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072)

        expect(results.pluck(:id)).to contain_exactly(ai1.id, ai2.id, ai3.id)
      end

      it 'returns all individuals located within the specified max distance' do
        # check within 40 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 64_373.8)

        expect(results.pluck(:id)).to contain_exactly(ai1.id, ai2.id)
      end
    end

    context 'when there are no individuals within the max search distance' do
      it 'returns an empty array' do
        # check within 1 mile of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 1609.344)

        expect(results).to eq([])
      end
    end
  end

  describe '.find_with_full_name_similar_to' do
    before do
      # word similarity to Bob Law value = 1
      create(:accredited_individual, registration_number: '12300', first_name: 'Bob', last_name: 'Law')

      # word similarity to Bob Law value = 0.375
      create(:accredited_individual, registration_number: '23400', first_name: 'Bobby', last_name: 'Low')

      # word similarity to Bob Law value = 0.375
      create(:accredited_individual, registration_number: '34500', first_name: 'Bobbie', last_name: 'Lew')

      # word similarity to Bob Law value = 0.25
      create(:accredited_individual, registration_number: '45600', first_name: 'Robert', last_name: 'Lanyard')
    end

    context 'when there are accredited individuals with full names similar to the search phrase' do
      it 'returns all individuals with full names >= the word similarity threshold' do
        results = described_class.find_with_full_name_similar_to('Bob Law', 0.3)

        expect(results.pluck(:registration_number)).to match_array(%w[12300 23400 34500])
      end
    end

    context 'when there are no accredited individuals with full names similar to the search phrase' do
      it 'returns an empty array' do
        results = described_class.find_with_full_name_similar_to('No Name')

        expect(results.pluck(:registration_number)).to eq([])
      end
    end
  end

  describe '#poa_codes' do
    context 'when the individual has no poa code' do
      let(:individual) { create(:accredited_individual) }

      context 'when the individual has no accredited_organization associations' do
        it 'returns an empty array' do
          expect(individual.poa_codes).to eq([])
        end
      end

      context 'when the individual has accredited_organization associations' do
        let(:org1) { create(:accredited_organization, poa_code: 'ABC') }
        let(:org2) { create(:accredited_organization, poa_code: 'DEF') }

        it 'returns an array of the associated accredited_organizations poa_codes' do
          individual.accredited_organizations.push(org1, org2)

          expect(individual.reload.poa_codes).to match_array(%w[ABC DEF])
        end
      end
    end

    context 'when the individual has a poa code' do
      let(:individual) { create(:accredited_individual, individual_type: 'attorney', poa_code: 'A12') }

      context 'when the individual has no accredited_organization associations' do
        it 'returns an array of only the individual poa_code' do
          expect(individual.poa_codes).to eq(['A12'])
        end
      end

      context 'when the individual has accredited_organization associations' do
        let(:org1) { create(:accredited_organization, poa_code: 'ABC') }
        let(:org2) { create(:accredited_organization, poa_code: 'DEF') }

        it 'returns an array of all associated poa_codes' do
          individual.accredited_organizations.push(org1, org2)

          expect(individual.reload.poa_codes).to match_array(%w[ABC DEF A12])
        end
      end
    end
  end
end
