# frozen_string_literal: true

module EVSS
  module Dependents
    ##
    # Model for the retrieve endpoint response. Body (response_body) is passed straight through from the service.
    #
    # @!attribute response_body
    #   @return [Hash] response_body
    #
    class RetrieveInfoResponse < EVSS::Response
      attribute :response_body, Hash
    end
  end
end
