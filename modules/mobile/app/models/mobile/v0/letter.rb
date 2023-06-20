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

      VISIBLE_TYPES = %w[
        benefit_summary
        benefit_verification
        civil_service
        commissary
        medicare_partd
        minimum_essential_coverage
        proof_of_service
        service_verification
      ].freeze

      attribute :name, Types::String
      attribute :letter_type, LETTER_TYPE

      def initialize(attributes)
        if attributes[:letter_type] == 'benefit_summary'
          attributes[:name] = 'Benefit Summary and Service Verification Letter'
        end

        super
      end

      def displayable?
        self.class::VISIBLE_TYPES.include?(letter_type)
      end
    end
  end
end
