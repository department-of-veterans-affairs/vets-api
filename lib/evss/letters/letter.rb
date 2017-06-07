# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module Letters
    class Letter < Common::Base
      LETTER_TYPES = %w(
        commissary
        proof_of_service
        medicare_partd
        minimum_essential_coverage
        service_verification
        civil_service
        benefit_summary
        benefit_verification
      ).freeze

      attribute :name, String
      attribute :letter_type, String

      def self.find_by_user(user)
        service = EVSS::Letters::ServiceFactory.get_service(mock_service: Settings.evss.mock_letters)
        service.letters_by_user(user)
      end

      def initialize(args)
        raise ArgumentError, 'name and letter_type are required' if args.values.any?(&:nil?)
        unless LETTER_TYPES.include? args['letter_type']
          raise ArgumentError, "invalid letter type: #{args['letter_type']}"
        end
        super({ name: args['letter_name'], letter_type: args['letter_type'] })
      end
    end

    class Address < Common::Base
      attribute :full_name, String
      attribute :address_line1, String
      attribute :address_line2, String
      attribute :address_line3, String
      attribute :city, String
      attribute :state, String
      attribute :country, String
      attribute :foreign_code, String
      attribute :zip_code, String
    end
  end
end
