# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module Questionnaire
      ##
      # A service object for querying the PGD for Questionnaire Response resources.
      #
      # @!attribute headers
      #   @return [Hash]
      class MapQuery
        include PatientGeneratedData::FHIRClient

        attr_reader :headers

        ##
        # Builds a PatientGeneratedData::Questionnaire::MapQuery instance from a given hash of headers.
        #
        # @param headers [Hash] the set of headers.
        # @return [PatientGeneratedData::Questionnaire::MapQuery] an instance of this class
        #
        def self.build(headers)
          new(headers)
        end

        def initialize(headers)
          @headers = headers
        end

        ##
        # Gets Questionnaire from provided options
        #
        # @param options [Hash] the search options.
        # @return [FHIR::Questionnaire::Bundle] an instance of Bundle
        #
        def search(options = {})
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
