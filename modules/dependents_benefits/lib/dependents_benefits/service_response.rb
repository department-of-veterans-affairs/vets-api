# frozen_string_literal: true

module DependentsBenefits
  ##
  # Standard response object for service interactions
  #
  # Provides a consistent response structure for all service calls (BGS, ClaimsEvidenceApi,
  # Lighthouse). Includes status, data payload, and error information.
  #
  # @example Successful response
  #   ServiceResponse.new(status: true, data: { id: 123 })
  #
  # @example Error response
  #   ServiceResponse.new(status: false, error: "Connection timeout")
  #
  class ServiceResponse
    # @return [Boolean] Success status of the service call
    attr_reader :status

    # @return [Object, nil] Response data from the service
    attr_reader :data

    # @return [String, Exception, nil] Error message or exception if failed
    attr_reader :error

    ##
    # Creates a new service response
    #
    # @param status [Boolean] Success status of the service call
    # @param data [Object, nil] Response data payload
    # @param error [String, Exception, nil] Error information if failed
    def initialize(status:, data: nil, error: nil)
      @status = status
      @data = data
      @error = error
    end

    ##
    # Checks if the service call was successful
    #
    # @return [Boolean] true if successful, false otherwise
    def success?
      status
    end
  end
end
