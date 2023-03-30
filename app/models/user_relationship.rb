# frozen_string_literal: true

class UserRelationship
  attr_accessor :first_name, :last_name, :birth_date, :ssn,
                :gender, :veteran_status, :participant_id, :icn

  PERSON_TYPE_VETERAN = 'VET'

  # Initializer with a single 'person' from a BGS get_dependents call
  def self.from_bgs_dependent(bgs_dependent)
    user_relationship = new
    # Profile attributes
    user_relationship.first_name = bgs_dependent[:first_name]
    user_relationship.last_name = bgs_dependent[:last_name]
    user_relationship.birth_date = Formatters::DateFormatter.format_date(bgs_dependent[:date_of_birth])
    user_relationship.ssn = bgs_dependent[:ssn]
    user_relationship.gender = bgs_dependent[:gender]
    user_relationship.veteran_status = bgs_dependent[:veteran_indicator] == 'Y'
    # ID attributes
    user_relationship.participant_id = bgs_dependent[:ptcpnt_id]
    user_relationship
  end

  # Initializer with a single 'person' from an MPI response RelationshipHolder stanza
  def self.from_mpi_relationship(mpi_relationship)
    user_relationship = new
    # Profile attributes
    user_relationship.first_name = mpi_relationship.given_names&.first
    user_relationship.last_name = mpi_relationship.family_name
    user_relationship.birth_date = Formatters::DateFormatter.format_date(mpi_relationship.birth_date)
    user_relationship.ssn = mpi_relationship.ssn
    user_relationship.gender = mpi_relationship.gender
    user_relationship.veteran_status = mpi_relationship.person_types.include? PERSON_TYPE_VETERAN
    # ID attributes
    user_relationship.icn = mpi_relationship.icn
    user_relationship.participant_id = mpi_relationship.participant_id
    user_relationship
  end

  # Sparse hash to serialize to frontend
  def to_hash
    {
      first_name:,
      last_name:,
      birth_date:
    }
  end

  # Full MPI Profile object
  def get_full_attributes
    user_identity = build_user_identity
    MPIData.for_user(user_identity)
  end

  private

  def build_user_identity
    UserIdentity.new(
      uuid: SecureRandom.uuid,
      first_name: first_name.to_s,
      last_name: last_name.to_s,
      birth_date: birth_date.to_s,
      gender: gender.to_s,
      ssn: ssn.to_s,
      icn: icn.to_s,
      mhv_icn: icn.to_s,
      loa: {
        current: LOA::THREE,
        highest: LOA::THREE
      }
    )
  end
end
