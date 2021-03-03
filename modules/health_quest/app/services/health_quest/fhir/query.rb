# frozen_string_literal: true

module HealthQuest
  module FHIR
    ##
    # A service object for querying the lighthouse for FHIR resources.
    #
    # @!attribute access_token
    #   @return [String]
    # @!attribute headers
    #   @return [Hash]
    class Query
      include Lighthouse::FHIRClient
      include Lighthouse::FHIRHeaders

      attr_reader :access_token, :api, :headers, :resource_identifier

      ##
      # Builds a Query instance from a redis session.
      #
      # @param opts [Hash] options.
      # @return [Query] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @api = opts[:api]
        @resource_identifier = opts[:resource_identifier]
        @access_token = opts[:session_store].token
        @headers = auth_header
      end

      ##
      # Queries for FHIR resources using the provided options
      #
      # @param options [Hash] the search options.
      # @return [FHIR::Bundle] an instance of Bundle
      #
      def search(options)
        client.search(fhir_model, search_options(options))
      end

      ##
      # Queries for a resource by its id
      #
      # @param id [String] the unique ID.
      # @return [FHIR::ClientReply] an instance of ClientReply
      #
      def get(id)
        client.read(fhir_model, id)
      end

      ##
      # Creates a resource in lighthouse for the logged in user.
      #
      # @param data [Hash] user submitted data.
      # @param user [User] the current user.
      # @return [FHIR::ClientReply] an instance of ClientReply
      #
      def create(data, user)
        headers.merge!(content_type_header)

        questionnaire_response = client_model.manufacture(data, user).prepare
        client.create(questionnaire_response)
      end

      ##
      # Returns the FHIR::<resource> class object supplied
      # by the calling controller
      #
      # @return [FHIR::<resource>]
      #
      def fhir_model
        klass = 'FHIR' + "/#{resource_identifier}".camelize

        klass.constantize
      end

      ##
      # Returns the client class for structuring the data
      # for POSTing or PUTting to the FHIR server
      #
      # @return [ClientModel::<model>]
      #
      def client_model
        klass = 'health_quest/'.camelize + 'FHIR' + "/client_model/#{resource_identifier}".camelize

        klass.constantize
      end

      ##
      # Builds a hash of options for the `#search` method
      #
      # @param options [Hash] search options.
      # @return [Hash] a configured set of key values
      #
      def search_options(options)
        {
          search: {
            parameters: options
          }
        }
      end

      ##
      # Returns the resource specific api path
      #
      # @return [String]
      #
      def api_query_path
        case api
        when 'pgd_api'
          Settings.hqva_mobile.lighthouse.pgd_path
        when 'health_api'
          Settings.hqva_mobile.lighthouse.health_api_path
        end
      end
    end
  end
end
