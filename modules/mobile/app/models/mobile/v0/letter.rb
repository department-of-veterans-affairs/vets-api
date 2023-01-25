# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Letter < Common::Resource
      LETTER_TYPE = Types::String.enum(
        'benefit_summary',
        'benefit_summary_dependent',
        'benefit_verification',
        'certificate_of_eligibility',
        'civil_service',
        'commissary',
        'medicare_partd',
        'minimum_essential_coverage',
        'proof_of_service',
        'service_verification'
      )

      attribute :name, Types::String
      attribute :letter_type, LETTER_TYPE
    end
  end
end
