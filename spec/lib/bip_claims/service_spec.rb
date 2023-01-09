# frozen_string_literal: true

require 'rails_helper'
require 'bip_claims/service'

RSpec.describe BipClaims::Service do
  let(:service) { described_class.new }
  let(:claim) { build(:burial_claim) }

  describe '#veteran_attributes' do
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { OpenStruct.new(participant_id: 123) }

    before do
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes).with(
        ssn: '796043735',
        first_name: 'WESLEY',
        last_name: 'FORD',
        birth_date: '1986-05-06'
      ).and_return(
        find_profile_response
      )
    end

    it 'raises error when passed an unsupported form ID' do
      expect { service.veteran_attributes(OpenStruct.new(form_id: 'INVALID')) }
        .to raise_error(ArgumentError)
    end

    it 'returns expected MPI profile' do
      profile = service.lookup_veteran_from_mpi(claim)
      expect(profile).to eq(mpi_profile)
    end
  end
end
