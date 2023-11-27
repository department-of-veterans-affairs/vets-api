# frozen_string_literal: true

require 'map/security_token/service'

module Map
  ##
  # A class to provide functionality related to MAP appointments service.
  #
  class Service
    attr_reader :patient_identifier, :query_params, :redis_client

    ##
    # Builds a Service instance
    #
    # @param opts [Hash] options to create the object
    #
    # @return [Service] an instance of this class
    #
    def self.build(opts = {})
      new(opts)
    end

    def initialize(opts = {})
      @patient_identifier = opts[:patient_identifier]
      @query_params = opts[:query_params]
      @redis_client = RedisClient.build
    end
  end
end
