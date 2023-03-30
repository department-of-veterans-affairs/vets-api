# frozen_string_literal: true

module CheckIn
  module V2
    ##
    # An object responsible for handling restful session creation
    # for a user for the Check-in experience.
    #
    # @!attribute uuid
    #   @return [String] uuid of the session
    # @!attribute last_name
    #   @return [String] last name of the user for Low Risk Auth
    # @!attribute settings
    #   @return [Config::Options]
    # @!attribute jwt
    #   @return [String]
    # @!attribute check_in_type
    #   @return [String] whether this is a preCheckIn or (day of) CheckIn session
    # @!attribute redis_session_prefix
    #   @return (see Config::Options#redis_session_prefix)
    class Session
      extend Forwardable

      UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
      DOB_REGEX = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/
      LAST_NAME_REGEX = /^.{1,600}$/

      attr_reader :uuid, :dob, :last_name, :settings, :jwt, :check_in_type, :handoff

      def_delegators :settings, :redis_session_prefix

      ##
      # Builds a CheckIn::V2::Session instance
      #
      # @return [CheckIn::V2::Session] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @settings = Settings.check_in.lorota_v2
        @jwt = opts[:jwt]
        @uuid = opts.dig(:data, :uuid)
        @dob = opts.dig(:data, :dob)
        @last_name = opts.dig(:data, :last_name)
        @check_in_type = opts.dig(:data, :check_in_type)
        @handoff = opts.dig(:data, :handoff)
      end

      #
      # Determines if the incoming request to the sessions controllers
      # show action already has a JWT token with the vets-api
      #
      # @return [Boolean]
      #
      def authorized?
        jwt.present? && Rails.cache.read(key, namespace: 'check-in-lorota-v2-cache').present?
      end

      #
      # Determines if the incoming request to the sessions controllers
      # show action has a valid UUID format
      #
      # @return [Boolean]
      #
      def valid_uuid?
        UUID_REGEX.match?(uuid)
      end

      #
      # Determines if the incoming request to the sessions controllers
      # show action has all valid parameters
      #
      # @return [Boolean]
      #
      def valid?
        UUID_REGEX.match?(uuid) && DOB_REGEX.match?(dob) && LAST_NAME_REGEX.match?(last_name)
      end

      #
      # Returns the JWT session Redis key
      #
      # @return [String]
      #
      def key
        "#{redis_session_prefix}_#{uuid}_read.full"
      end

      #
      # Returns the unauthorized permissions
      #
      # @return [Hash]
      #
      def unauthorized_message
        { permissions: 'read.none', status: 'success', uuid: }
      end

      #
      # Returns the authorized permissions
      #
      # @return [Hash]
      #
      def success_message
        { permissions: 'read.full', status: 'success', uuid: }
      end

      #
      # Returns the message when client side data is invalid
      #
      # @return [Hash]
      #
      def client_error
        { error: true, message: 'Invalid dob or last name!' }
      end

      #
      # Returns the message for invalid request from client
      #
      # @return [Hash]
      #
      def invalid_request
        { error: true, message: 'Invalid parameter request' }
      end
    end
  end
end
