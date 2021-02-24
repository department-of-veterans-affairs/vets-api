# frozen_string_literal: true 

module Identity
  class Identity
    include Virtus.model

    attribute :uuid,         String # Current Account Id
    attribute :email,        String
    attribute :first_name,   String
    attribute :middle_name,  String
    attribute :family_name,  String
    attribute :common_name,  String
    attribute :suffix,       String
    attribute :gender,       String
    attribute :birth_date,   Common::DateTimeString
    attribute :ssn,          String
    attribute :loa           String
    attribute :person_types, Array[String]
    attribute :addresses,    Array[Identity::Address]
    attribute :phones,       Array[Identity::Phone]
    attribute :indeitifiers  Array[Identity::Identifier]
    attribute :search_token, String

    def phones
      []
    end

    def addresses
      []
    end

    def identifiers
      []
    end

    private

    def mpi_profile
      Identity::MPI::Profile.find(self)
    end
  end
end