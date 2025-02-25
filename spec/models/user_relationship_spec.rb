# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserRelationship, type: :model do
  describe '.from_bgs_dependent' do
    let(:user_relationship) { described_class.from_bgs_dependent(bgs_dependent) }
    let(:bgs_dependent) do
      {
        award_indicator: 'N',
        city_of_birth: 'WASHINGTON',
        current_relate_status: '',
        date_of_birth: '01/01/2000',
        date_of_death: '',
        death_reason: '',
        email_address: 'Curt@email.com',
        first_name: 'CURT',
        gender: '',
        last_name: 'WEBB-STER',
        middle_name: '',
        proof_of_dependency: 'Y',
        ptcpnt_id: '32354974',
        related_to_vet: 'N',
        relationship: 'Child',
        ssn: '500223351',
        ssn_verify_status: '1',
        state_of_birth: 'DC'
      }
    end

    it 'creates a UserRelationship object with attributes from a BGS Dependent call' do
      expect(user_relationship.first_name).to eq bgs_dependent[:first_name]
      expect(user_relationship.last_name).to eq bgs_dependent[:last_name]
      expect(user_relationship.birth_date).to eq Formatters::DateFormatter.format_date(bgs_dependent[:date_of_birth])
      expect(user_relationship.ssn).to eq bgs_dependent[:ssn]
      expect(user_relationship.gender).to eq bgs_dependent[:gender]
      expect(user_relationship.veteran_status).to be false
      expect(user_relationship.participant_id).to eq bgs_dependent[:ptcpnt_id]
    end
  end

  describe '.from_mpi_relationship' do
    let(:mpi_relationship) { build(:mpi_profile_relationship) }
    let(:user_relationship) { described_class.from_mpi_relationship(mpi_relationship) }

    it 'creates a UserRelationship object with attributes from an MPI Profile RelationshipHolder stanza' do
      expect(user_relationship.first_name).to eq mpi_relationship.given_names.first
      expect(user_relationship.last_name).to eq mpi_relationship.family_name
      expect(user_relationship.birth_date).to eq Formatters::DateFormatter.format_date(mpi_relationship.birth_date)
      expect(user_relationship.ssn).to eq mpi_relationship.ssn
      expect(user_relationship.gender).to eq mpi_relationship.gender
      expect(user_relationship.veteran_status).to eq mpi_relationship.person_types.include? 'VET'
      expect(user_relationship.icn).to eq mpi_relationship.icn
      expect(user_relationship.participant_id).to eq mpi_relationship.participant_id
    end
  end

  describe '#to_hash' do
    let(:mpi_relationship) { build(:mpi_profile_relationship) }
    let(:user_relationship) { described_class.from_mpi_relationship(mpi_relationship) }
    let(:user_relationship_hash) do
      {
        first_name: mpi_relationship.given_names.first,
        last_name: mpi_relationship.family_name,
        birth_date: Formatters::DateFormatter.format_date(mpi_relationship.birth_date)
      }
    end

    it 'creates a spare hash of select attributes for frontend serialization' do
      expect(user_relationship.to_hash).to eq user_relationship_hash
    end
  end

  describe '#get_full_attributes' do
    let(:mpi_relationship) { build(:mpi_profile_relationship) }
    let(:user_relationship) { described_class.from_mpi_relationship(mpi_relationship) }
    let(:mpi_object_double) { double }

    before do
      allow(MPIData).to receive(:for_user).and_return(mpi_object_double)
    end

    it 'returns an MPI profile for relationship attributes' do
      expect(user_relationship.get_full_attributes).to eq mpi_object_double
    end
  end
end
