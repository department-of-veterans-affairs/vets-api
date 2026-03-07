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
        'certificate_of_eligibility_home_loan',
        'civil_service',
        'commissary',
        'foreign_medical_program',
        'medicare_partd',
        'minimum_essential_coverage',
        'proof_of_service',
        'service_verification'
      )

      VISIBLE_TYPES = %w[
        benefit_summary
        benefit_verification
        certificate_of_eligibility_home_loan
        civil_service
        commissary
        foreign_medical_program
        medicare_partd
        minimum_essential_coverage
        proof_of_service
        service_verification
      ].freeze

      attribute :name, Types::String
      attribute :letter_type, LETTER_TYPE
      attribute :reference_number, Types::String.optional.default(nil) # only for COE home loan letters
      attribute :coe_status, Types::String.optional.default(nil) # only for COE home loan letters

      def initialize(attributes)
        if attributes[:letter_type] == 'benefit_summary'
          attributes[:name] = 'Benefit Summary and Service Verification Letter'
        elsif attributes[:letter_type] == 'foreign_medical_program'
          attributes[:name] = 'Foreign Medical Program Enrollment Letter'
        end

        super
      end

      def displayable?(user = nil)
        return false unless self.class::VISIBLE_TYPES.include?(letter_type)

        # Hide foreign_medical_program behind user-specific feature flag
        if letter_type == 'foreign_medical_program'
          return Flipper.enabled?(:fmp_benefits_authorization_letter) if user.nil?

          return Flipper.enabled?(:fmp_benefits_authorization_letter, user)
        end

        true
      end
    end
  end
end
