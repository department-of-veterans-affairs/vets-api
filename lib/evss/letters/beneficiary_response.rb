# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'evss/response'
require_relative 'benefit_information'
require_relative 'benefit_information_dependent'
require_relative 'benefit_information_veteran'
require_relative 'military_service'

module EVSS
  module Letters
    ##
    # Model for beneficiary responses.
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute benefit_information
    #   @return [EVSS::Letters::BenefitInformation] The user's benefit information
    # @!attribute military_service
    #   @return Array[EVSS::Letters::MilitaryService] An array of military service data
    #
    class BeneficiaryResponse < EVSS::Response
      attribute :benefit_information, EVSS::Letters::BenefitInformation
      attribute :military_service, EVSS::Letters::MilitaryService, array: true, default: []

      def initialize(status, response = nil)
        attributes = response.body if response
        super(status, attributes)
      end

      def benefit_information=(attrs)
        @benefit_information = if veteran_attributes?(attrs)
                                 EVSS::Letters::BenefitInformationVeteran.new(attrs)
                               else
                                 EVSS::Letters::BenefitInformationDependent.new(attrs)
                               end
      end

      private

      def veteran_attributes?(attrs)
        attrs.key? 'has_service_connected_disabilities'
      end
    end
  end
end
