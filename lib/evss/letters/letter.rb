# frozen_string_literal: true

require 'vets/model'

module EVSS
  module Letters
    ##
    # Model for a letter
    #
    # @param args [Hash] Response attributes. Must include 'letter_type' and 'letter_name'
    #
    # @!attribute name
    #   @return [String] The letter name
    # @!attribute letter_type
    #   @return [String] The letter type (must be one of LETTER_TYPES)
    #
    class Letter
      include Vets::Model

      # if you update LETTER_TYPES, update LETTER_TYPES in vets-website src/applications/letters/utils/constants.js
      LETTER_TYPES = %w[
        benefit_summary
        benefit_summary_dependent
        benefit_verification
        certificate_of_eligibility
        civil_service
        commissary
        foreign_medical_program
        medicare_partd
        minimum_essential_coverage
        proof_of_service
        service_verification
      ].freeze

      attribute :name, String
      attribute :letter_type, String

      def initialize(args)
        raise ArgumentError, 'name and letter_type are required' if args.values.any?(&:nil?)
        unless LETTER_TYPES.include? args['letter_type']
          raise ArgumentError, "invalid letter type: #{args['letter_type']}"
        end

        super({ name: args['letter_name'], letter_type: args['letter_type'] })
      end
    end
  end
end
