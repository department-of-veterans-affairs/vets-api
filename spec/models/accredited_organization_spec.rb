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

  describe '#validate_address' do
    let(:raw_address_data) do
      {
        'address_line1' => '123 Main St',
        'city' => 'Brooklyn',
        'state_code' => 'NY',
        'zip_code' => '11249'
      }
    end
    let(:organization) { create(:accredited_organization, raw_address: raw_address_data) }
    let(:mock_service) { instance_double(RepresentationManagement::AddressValidationService) }

    before do
      allow(RepresentationManagement::AddressValidationService).to receive(:new).and_return(mock_service)
    end

    context 'when raw_address is blank' do
      let(:organization) { create(:accredited_organization, raw_address: nil) }

      it 'returns false' do
        expect(organization.validate_address).to be false
      end
    end

    context 'when address validation succeeds' do
      let(:validated_attrs) do
        {
          address_line1: '123 Main St',
          city: 'Brooklyn',
          state_code: 'NY',
          lat: 40.717029,
          long: -73.964956,
          location: 'POINT(-73.964956 40.717029)'
        }
      end

      before do
        allow(mock_service).to receive(:validate_address).and_return(validated_attrs)
      end

      it 'updates the record with validated attributes' do
        organization.validate_address
        organization.reload
        expect(organization.lat).to eq(40.717029)
        expect(organization.long).to eq(-73.964956)
      end

      it 'returns true' do
        expect(organization.validate_address).to be true
      end
    end

    context 'when address validation returns nil' do
      before do
        allow(mock_service).to receive(:validate_address).and_return(nil)
      end

      it 'returns false' do
        expect(organization.validate_address).to be false
      end
    end

    context 'when an error occurs' do
      before do
        allow(mock_service).to receive(:validate_address).and_raise(StandardError.new('Service error'))
      end

      it 'returns false' do
        expect(organization.validate_address).to be false
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Address validation failed for AccreditedOrganization/)
        organization.validate_address
      end
    end
  end
end
