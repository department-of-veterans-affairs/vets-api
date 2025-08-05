# frozen_string_literal: true

require 'vets/model'

module DisabilityCompensation
  module ApiProvider
    class IntentToFile
      include Vets::Model

      # The spelling of these status types has been validated with the partner team
      STATUS_TYPES = %w[
        active
        claim_recieved
        duplicate
        expired
        incomplete
        canceled
      ].freeze

      attribute :id, String
      attribute :creation_date, DateTime
      attribute :expiration_date, DateTime
      attribute :participant_id, Integer
      attribute :source, String
      attribute :status, String
      attribute :type, String
    end

    # array of Intent to Files
    class IntentToFilesResponse
      include Vets::Model

      attribute :intent_to_file, DisabilityCompensation::ApiProvider::IntentToFile, array: true
    end

    # a single Intent to File
    class IntentToFileResponse
      include Vets::Model

      attribute :intent_to_file, DisabilityCompensation::ApiProvider::IntentToFile
    end
  end
end
