# frozen_string_literal: true

module ChipApi
  ##
  # A service object for isolating dependencies from the PatientCheckInsController and
  # the Chip API. An object responsible for making requests from the Chip API, Caching,
  # Instrumenting, and performing any other tasks related to the Chip API.
  #
  # @!attribute request
  #   @return [ChipApi::Request]
  class Service
    attr_reader :request

    ##
    # Builds a Service instance
    #
    # @return [Service] an instance of this class
    #
    def self.build
      new
    end

    def initialize
      @request = ChipApi::Request.build
    end

    ##
    # Gets the resource by its unique ID
    #
    # @param id [String] a unique string value
    # @return [Hash]
    #
    def get_check_in(id)
      resp = request.get(id)

      { data: resp.body }
    end

    ##
    # Create a resource for the logged in user.
    #
    # @param data [Hash] data submitted by the user.
    # @return [Hash]
    #
    def create_check_in(data)
      resp = request.post(data)

      { data: resp.body }
    end
  end
end
