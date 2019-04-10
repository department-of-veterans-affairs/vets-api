# frozen_string_literal: true

require 'evss/response'

module EVSS
  module DisabilityCompensationForm
    # Model for a parsed 526 submission response
    #
    # @param status [Integer] the HTTP status code
    #
    # @!attribute claim_id
    #   @return [Integer] The lookup id for the claim returned by EVSS
    # @!attribute inflight_document_id
    #   @return [Integer] The inflight id
    # @!attribute end_product_claim_code
    #   @return [Integer] The code for the form e.g. '020SUPP'
    # @!attribute end_product_claim_name
    #   @return [Integer] The name of the form e.g. 'eBenefits 526EZ-Supplemental (020)'
    #
    class FormSubmitResponse < EVSS::Response
      attribute :claim_id, Integer
      attribute :inflight_document_id, Integer
      attribute :end_product_claim_code, String
      attribute :end_product_claim_name, String

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
