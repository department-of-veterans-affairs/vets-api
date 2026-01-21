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

  describe '#set_full_name' do
    subject { build(:accredited_individual, first_name:, last_name:) }

    context 'when both first_name and last_name are present' do
      let(:first_name) { 'John' }
      let(:last_name) { 'Doe' }

      it 'sets full_name to "first_name last_name"' do
        subject.save

        expect(subject.full_name).to eq('John Doe')
      end
    end

    context 'when only first_name is present' do
      let(:first_name) { 'John' }
      let(:last_name) { nil }

      it 'sets full_name to first_name only' do
        subject.save

        expect(subject.full_name).to eq('John')
      end
    end

    context 'when only last_name is present' do
      let(:first_name) { nil }
      let(:last_name) { 'Doe' }

      it 'sets full_name to last_name only' do
        subject.save

        expect(subject.full_name).to eq('Doe')
      end
    end

    context 'when both first_name and last_name are blank' do
      let(:first_name) { nil }
      let(:last_name) { nil }

      it 'sets full_name to empty string' do
        subject.save

        expect(subject.full_name).to eq('')
      end
    end

    context 'when first_name is empty string and last_name is present' do
      let(:first_name) { '' }
      let(:last_name) { 'Doe' }

      it 'sets full_name to last_name only' do
        subject.save

        expect(subject.full_name).to eq('Doe')
      end
    end

    context 'when last_name is empty string and first_name is present' do
      let(:first_name) { 'John' }
      let(:last_name) { '' }

      it 'sets full_name to first_name only' do
        subject.save

        expect(subject.full_name).to eq('John')
      end
    end

    context 'when both first_name and last_name are empty strings' do
      let(:first_name) { '' }
      let(:last_name) { '' }

      it 'sets full_name to empty string' do
        subject.save

        expect(subject.full_name).to eq('')
      end
    end

    context 'when names contain whitespace' do
      let(:first_name) { '  John  ' }
      let(:last_name) { '  Doe  ' }

      it 'removes whitespace in full_name' do
        subject.save

        expect(subject.full_name).to eq('John Doe')
      end
    end

    context 'when names contain special characters' do
      let(:first_name) { "O'Connor" }
      let(:last_name) { 'Smith-Johnson' }

      it 'preserves special characters in full_name' do
        subject.save

        expect(subject.full_name).to eq("O'Connor Smith-Johnson")
      end
    end

    context 'when updating an existing record' do
      let(:individual) { create(:accredited_individual, first_name: 'Jane', last_name: 'Smith') }

      it 'updates full_name when first_name changes' do
        individual.update(first_name: 'Janet')

        expect(individual.full_name).to eq('Janet Smith')
      end

      it 'updates full_name when last_name changes' do
        individual.update(last_name: 'Jones')

        expect(individual.full_name).to eq('Jane Jones')
      end

      it 'updates full_name when both names change' do
        individual.update(first_name: 'Bob', last_name: 'Wilson')

        expect(individual.full_name).to eq('Bob Wilson')
      end

      it 'updates full_name when first_name is set to nil' do
        individual.update(first_name: nil)

        expect(individual.full_name).to eq('Smith')
      end

      it 'updates full_name when last_name is set to nil' do
        individual.update(last_name: nil)

        expect(individual.full_name).to eq('Jane')
      end
    end

    context 'when manually calling set_full_name' do
      let(:individual) { build(:accredited_individual, first_name: 'Test', last_name: 'User') }

      it 'updates full_name without saving' do
        individual.first_name = 'Updated'
        individual.set_full_name

        expect(individual.full_name).to eq('Updated User')
        expect(individual.changed?).to be true
      end
    end
  end

  describe 'full_name attribute' do
    context 'when creating a new record' do
      it 'is automatically set via before_save callback' do
        individual = create(:accredited_individual, first_name: 'Auto', last_name: 'Generated')

        expect(individual.full_name).to eq('Auto Generated')
      end
    end

    context 'when full_name is manually set' do
      let(:individual) { build(:accredited_individual, first_name: 'John', last_name: 'Doe') }

      it 'is overwritten by before_save callback' do
        individual.full_name = 'Manual Name'
        individual.save

        expect(individual.full_name).to eq('John Doe')
      end
    end

    context 'when used in database queries' do
      before do
        create(:accredited_individual, first_name: 'Alice', last_name: 'Johnson')
        create(:accredited_individual, first_name: 'Bob', last_name: 'Smith')
        create(:accredited_individual, first_name: 'Charlie', last_name: nil)
      end

      it 'can be searched by full_name' do
        results = described_class.where(full_name: 'Alice Johnson')

        expect(results.count).to eq(1)
        expect(results.first.first_name).to eq('Alice')
      end

      it 'can be ordered by full_name' do
        results = described_class.order(:full_name)

        expect(results.pluck(:full_name)).to eq(['Alice Johnson', 'Bob Smith', 'Charlie'])
      end
    end
  end

  describe '#validate_address' do
    let(:raw_address_data) do
      {
        'address_line1' => '123 Main St',
        'address_line2' => 'Suite 100',
        'city' => 'Brooklyn',
        'state_code' => 'NY',
        'zip_code' => '11249'
      }
    end

    let(:validated_attributes) do
      {
        address_line1: '123 Main St',
        address_line2: 'Suite 100',
        city: 'Brooklyn',
        state_code: 'NY',
        zip_code: '11249',
        lat: 40.717029,
        long: -73.964956,
        location: 'POINT(-73.964956 40.717029)'
      }
    end

    let(:mock_service) { instance_double(RepresentationManagement::AddressValidationService) }

    context 'with valid raw_address' do
      let(:individual) { create(:accredited_individual, raw_address: raw_address_data) }

      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).with(raw_address_data).and_return(validated_attributes)
      end

      it 'delegates to the validation service' do
        expect(RepresentationManagement::AddressValidationService).to receive(:new)
        expect(mock_service).to receive(:validate_address).with(raw_address_data)

        individual.validate_address
      end

      it 'saves validated attributes to the record' do
        expect(individual.validate_address).to be true
        individual.reload

        expect(individual.address_line1).to eq('123 Main St')
        expect(individual.city).to eq('Brooklyn')
        expect(individual.state_code).to eq('NY')
        expect(individual.lat).to eq(40.717029)
        expect(individual.long).to eq(-73.964956)
      end

      it 'returns true when validation succeeds' do
        expect(individual.validate_address).to be true
      end
    end

    context 'with blank raw_address' do
      let(:individual) { create(:accredited_individual, raw_address: nil) }

      it 'skips validation service' do
        expect(RepresentationManagement::AddressValidationService).not_to receive(:new)
        expect(individual.validate_address).to be false
      end

      it 'leaves the record unchanged' do
        original_address = individual.address_line1
        individual.validate_address
        expect(individual.reload.address_line1).to eq(original_address)
      end
    end

    context 'with empty hash raw_address' do
      let(:individual) { create(:accredited_individual, raw_address: {}) }

      it 'bails out early' do
        expect(RepresentationManagement::AddressValidationService).not_to receive(:new)
        expect(individual.validate_address).to be false
      end
    end

    context 'when validation service returns nil' do
      let(:individual) { create(:accredited_individual, raw_address: raw_address_data) }

      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).and_return(nil)
      end

      it 'handles failed validation gracefully' do
        expect(individual.validate_address).to be false
      end

      it 'keeps original address intact' do
        original_address = individual.address_line1
        individual.validate_address
        expect(individual.reload.address_line1).to eq(original_address)
      end
    end

    context 'when validation service raises an error' do
      let(:individual) { create(:accredited_individual, raw_address: raw_address_data) }

      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).and_raise(StandardError.new('Service error'))
      end

      it 'catches and logs the error' do
        expect(Rails.logger).to receive(:error).with(/Address validation failed for AccreditedIndividual/)
        individual.validate_address
      end

      it 'returns false on exception' do
        allow(Rails.logger).to receive(:error)
        expect(individual.validate_address).to be false
      end

      it 'rolls back changes' do
        allow(Rails.logger).to receive(:error)
        original_address = individual.address_line1
        individual.validate_address
        expect(individual.reload.address_line1).to eq(original_address)
      end
    end

    context 'when update fails' do
      let(:individual) { create(:accredited_individual, raw_address: raw_address_data) }

      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).and_return(validated_attributes)
        allow(individual).to receive(:update).and_return(false)
      end

      it 'returns false when update fails' do
        expect(individual.validate_address).to be false
      end
    end

    context 'idempotency' do
      let(:individual) { create(:accredited_individual, raw_address: raw_address_data) }

      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).with(raw_address_data).and_return(validated_attributes)
      end

      it 'handles repeated calls without issues' do
        expect(individual.validate_address).to be true
        first_lat = individual.reload.lat

        expect(individual.validate_address).to be true
        second_lat = individual.reload.lat

        expect(first_lat).to eq(second_lat)
      end
    end

    context 'with different individual types' do
      before do
        allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:validate_address).and_return(validated_attributes)
      end

      it 'validates attorneys' do
        attorney = create(:accredited_individual, :attorney, raw_address: raw_address_data)
        expect(attorney.validate_address).to be true
      end

      it 'validates claims agents' do
        agent = create(:accredited_individual, :claims_agent, raw_address: raw_address_data)
        expect(agent.validate_address).to be true
      end

      it 'validates representatives' do
        rep = create(:accredited_individual, :representative, raw_address: raw_address_data)
        expect(rep.validate_address).to be true
      end
    end
  end
end
