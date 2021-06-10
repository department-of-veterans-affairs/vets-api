# frozen_string_literal: true

module HealthQuest
  module Resource
    ##
    # A service object for querying the lighthouse for FHIR resources.
    #
    # @!attribute access_token
    #   @return [String]
    # @!attribute api
    #   @return [String]
    # @!attribute headers
    #   @return [Hash]
    # @!attribute resource_identifier
    #   @return [String]
    #
    class Query
      include Lighthouse::FHIRClient
      include Lighthouse::FHIRHeaders

      FHIR_MODEL_PREFIX = 'FHIR'

      attr_reader :access_token, :api, :headers, :resource_identifier

      ##
      # Builds a Query instance from a set of options.
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
      # Queries the Lighthouse APIs for a bundle of FHIR resources using the provided options
      #
      # @param options [Hash] the search options.
      # @return [FHIR::Bundle] an instance of Bundle
      #
      def search(options)
        client.search(fhir_model, search_options(options))
      end

      ##
      # Queries the Lighthouse APIs for a resource by its unique ID
      #
      # @param id [String] the unique ID.
      # @return [FHIR::ClientReply] an instance of ClientReply
      #
      def get(id)
        client.read(fhir_model, id)
      end

      ##
      # Creates a resource in Lighthouse for the logged in user via a POST request
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
      # Returns the FHIR::<resource> class specified by the calling controller
      #
      # @return [FHIR::<resource>]
      #
      def fhir_model
        klass = FHIR_MODEL_PREFIX + "/#{resource_identifier}".camelize

        klass.constantize
      end

      ##
      # Returns the class which lets us structure the client
      # data before submitting it to Lighthouse
      #
      # @return [ClientModel::<model>]
      #
      def client_model
        "health_quest/resource/client_model/#{resource_identifier}".camelize.constantize
      end

      ##
      # Builds a hash of options for the `#search` method which
      # get structured into query params during the lighthouse request
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
      # Returns the path for the `url` method in `Lighthouse::FHIRClient`
      # so we know if we have to call the PGD or the Health API
      #
      # @return [String] the API path
      #
      def api_query_path
        case api
        when lighthouse.pgd_api
          Settings.hqva_mobile.lighthouse.pgd_path
        when lighthouse.health_api
          Settings.hqva_mobile.lighthouse.health_api_path
        end
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
