# frozen_string_literal: true

module HealthQuest
  module Resource
    ##
    # A service object for isolating dependencies from the resource controller.
    #
    # @!attribute session_service
    #   @return [HealthQuest::Lighthouse::Session]
    # @!attribute user
    #   @return [User]
    # @!attribute query
    #   @return [Query]
    # @!attribute resource_identifier
    #   @return [String]
    # @!attribute options_builder
    #   @return [Shared::OptionsBuilder]
    #
    class Factory
      attr_reader :session_service, :user, :query, :resource_identifier, :options_builder

      ##
      # Builds a Factory instance from a given User
      #
      # @param user [User] the currently logged in user.
      # @return [Factory] an instance of this class
      #
      def self.manufacture(opts = {})
        new(opts)
      end

      def initialize(opts)
        @user = opts[:user]
        @resource_identifier = opts[:resource_identifier]
        @session_service = HealthQuest::Lighthouse::Session.build(user:, api: opts[:api])
        @query = Query.build(session_store: session_service.retrieve,
                             api: opts[:api],
                             resource_identifier:)
        @options_builder = Shared::OptionsBuilder
      end

      ##
      # Gets the resource by it's unique ID
      #
      # @param id [String] a unique string value
      # @return [FHIR::ClientReply]
      #
      def get(id) # rubocop:disable Rails/Delegate
        query.get(id)
      end

      ##
      # Gets resources from a given set of key/values
      #
      # @param filters [Hash] the set of query options.
      # @return [FHIR::ClientReply] an instance of ClientReply
      #
      def search(filters = {})
        filters.merge!(resource_name)

        with_options = options_builder.manufacture(user, filters).to_hash
        query.search(with_options)
      end

      ##
      # Create a resource for the logged in user.
      #
      # @param data [Hash] data submitted by the user.
      # @return [FHIR::ClientReply] an instance of ClientReply
      #
      def create(data)
        query.create(data, user)
      end

      ##
      # Builds the key/value pair for identifying the resource
      #
      # @return [Hash] a key value pair
      #
      def resource_name
        { resource_name: resource_identifier }
      end
    end
  end
end
