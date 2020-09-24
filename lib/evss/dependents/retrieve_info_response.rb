# frozen_string_literal: true

module EVSS
  module Dependents
    ##
    # Model for the retrieve endpoint response. Body is passed straight through from the service.
    #
    # @!attribute body
    #   @return [Hash] response body
    #
    class RetrieveInfoResponse < EVSS::Response
      attribute :body, Hash
    end
  end
end
