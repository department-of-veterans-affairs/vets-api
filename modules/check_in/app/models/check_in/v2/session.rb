# frozen_string_literal: true

module CheckIn
  module V2
    ##
    # An object responsible for handling restful session creation
    # for a user for the Check-in experience.
    #
    # @!attribute uuid
    #   @return [String] uuid of the session
    # @!attribute last4
    #   @return [String] last4 of the user for Low Risk Auth
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

      UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.freeze
      LAST_FOUR_REGEX = /^[0-9]{4}$/.freeze
      LAST_NAME_REGEX = /^.{1,600}$/.freeze

      attr_reader :uuid, :last4, :last_name, :settings, :jwt, :check_in_type

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
        @last4 = opts.dig(:data, :last4)
        @last_name = opts.dig(:data, :last_name)
        @check_in_type = opts.dig(:data, :check_in_type)
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
        UUID_REGEX.match?(uuid) && LAST_FOUR_REGEX.match?(last4) && LAST_NAME_REGEX.match?(last_name)
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
        { permissions: 'read.none', status: 'success', uuid: uuid }
      end

      #
      # Returns the authorized permissions
      #
      # @return [Hash]
      #
      def success_message
        { permissions: 'read.full', status: 'success', uuid: uuid }
      end

      #
      # Returns the Faraday::Response when client side data is invalid
      #
      # @return [Faraday::Response]
      #
      def client_error
        { error: true, message: 'Invalid last4 or last name!' }
      end
    end
  end
end
