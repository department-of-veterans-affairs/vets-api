# frozen_string_literal: true

# For a given user, checks for the presence of certain identifiers required by Form526
# Returns a mapping of the identifier name to a boolean indicating whether we have that information for a user or not
module Users
  class Form526UserIdentifiersStatusService
    FORM526_REQUIRED_IDENTIFIERS = %w[participant_id birls_id ssn birth_date edipi].freeze

    def self.call(*)
      new(*).call
    end

    def initialize(user)
      @user = user
    end

    def call
      identifer_mapping
    end

    private

    def identifer_mapping
      FORM526_REQUIRED_IDENTIFIERS.index_with { |identifier| @user[identifier].present? }
    end
  end
end
