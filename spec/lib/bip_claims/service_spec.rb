# frozen_string_literal: true

require 'rails_helper'
require 'bip_claims/service'

RSpec.describe BipClaims::Service do
  let(:service) { described_class.new }
  let(:claim) { build(:burial_claim) }
  let(:mvi_service) { instance_double(MPI::Service) }

  describe '#veteran_attributes' do
    it 'creates valid Veteran object from form data' do
      veteran = service.veteran_attributes(claim)
      expected_result = BipClaims::Veteran.new(
        ssn: '796043735',
        first_name: 'WESLEY',
        last_name: 'FORD',
        birth_date: '1986-05-06'
      )

      expect(veteran.attributes).to eq(expected_result.attributes)
    end

    it 'raises error when passed an unsupported form ID' do
      expect { service.veteran_attributes(OpenStruct.new(form_id: 'INVALID')) }
        .to raise_error(ArgumentError)
    end

    it 'calls MPI::Service for veteran lookup' do
      allow(MPI::Service).to receive(:new).and_return(mvi_service)
      allow(mvi_service).to receive(:find_profile).and_return(
        OpenStruct.new(profile:
          OpenStruct.new(participant_id: 123))
      )
      expect(mvi_service).to receive(:find_profile)

      service.lookup_veteran_from_mpi(claim)
    end
  end
end
