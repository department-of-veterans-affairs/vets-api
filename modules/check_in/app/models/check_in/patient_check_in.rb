# frozen_string_literal: true

module CheckIn
  ##
  # A class responsible for Check-in related business logic
  #
  # @!attribute uuid
  #   @return [String]
  class PatientCheckIn
    ##
    # Regex for matching UUID
    #
    UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

    attr_reader :uuid

    ##
    # Builds a PatientCheckIn instance
    #
    # @param opts [Hash]
    # @return [PatientCheckIn] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts)
      @uuid = opts[:uuid]
    end

    ##
    # Returns true if the UUID is valid or false if it's not
    #
    # @return [Boolean]
    #
    def valid?
      UUID_REGEX.match?(uuid)
    end

    ##
    # The client error response if the UUID is invalid
    #
    # @return [Faraday::Response]
    #
    def client_error
      body = { error: true, message: "Invalid uuid #{uuid}" }

      Faraday::Response.new(body:, status: 400)
    end
  end
end
