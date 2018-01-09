# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module Letters
    class Letter < Common::Base
      LETTER_TYPES = %w[
        commissary
        proof_of_service
        medicare_partd
        minimum_essential_coverage
        service_verification
        civil_service
        benefit_summary
        benefit_verification
        certificate_of_eligibility
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
