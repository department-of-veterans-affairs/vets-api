# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module Questionnaire
      ##
      # A service object for querying the PGD for Questionnaire Response resources.
      #
      # @!attribute access_token
      #   @return [String]
      # @!attribute headers
      #   @return [Hash]
      class MapQuery
        include Lighthouse::FHIRClient
        include Lighthouse::FHIRHeaders

        attr_reader :access_token, :headers

        ##
        # Builds a PatientGeneratedData::Questionnaire::MapQuery instance from a redis session.
        #
        # @param session_store [HealthQuest::SessionStore] the users redis session.
        # @return [PatientGeneratedData::Questionnaire::MapQuery] an instance of this class
        #
        def self.build(session_store)
          new(session_store)
        end

        def initialize(session_store)
          @access_token = session_store.token
          @headers = auth_header
        end

        ##
        # Gets Questionnaire from provided options
        #
        # @param options [Hash] the search options.
        # @return [FHIR::Questionnaire::Bundle] an instance of Bundle
        #
        def search(options)
          client.search(fhir_model, search_options(options))
        end

        ##
        # Gets a Questionnaire from its id
        #
        # @param id [String] the Questionnaire ID.
        # @return [FHIR::Questionnaire::ClientReply] an instance of ClientReply
        #
        def get(id)
          client.read(fhir_model, id)
        end

        ##
        # Returns the FHIR::Questionnaire class object
        #
        # @return [FHIR::Questionnaire]
        #
        def fhir_model
          FHIR::Questionnaire
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
      end
    end
  end
end
