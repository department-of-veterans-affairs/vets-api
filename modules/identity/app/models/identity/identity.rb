# frozen_string_literal: true

module Identity
  class Identity
    attr_accessor :first_name, :last_name, :middle_name, :common_name, :title,
                  :suffix, :gender, :ssn, :date_of_birth, :loa, :authn_context,
                  :services, :person_types

    # Find Via UUID and return, this should be our only entry point to finding the
    # identity of a user moving forward.
    def self.find(uuid)
      # Find in MPI
      # Return a parsed identity class.
    end

    # Create a user in MPI, not sure that we will ever do this but we need to be
    # able to just in case.
    def self.create(attrs={})
    end

    def initialize(attrs={})
      attrs.each { |k, v| send(k, v) }
    end

    # The identifiers associated with this relation.
    def identifiers
      []
    end

    # An array of relations
    def relations
      []
    end

    def addresses
      []
    end
  end
end
