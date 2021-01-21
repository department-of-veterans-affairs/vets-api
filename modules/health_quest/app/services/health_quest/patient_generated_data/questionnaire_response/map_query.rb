# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      ##
      # A service object for querying the PGD for Questionnaire Response resources.
      #
      # @!attribute headers
      #   @return [Hash]
      class MapQuery
        include PatientGeneratedData::FHIRClient

        attr_reader :headers

        ##
        # Builds a PatientGeneratedData::QuestionnaireResponse::MapQuery instance from a given hash of headers.
        #
        # @param headers [Hash] the set of headers.
        # @return [PatientGeneratedData::QuestionnaireResponse::MapQuery] an instance of this class
        #
        def self.build(headers)
          new(headers)
        end

        def initialize(headers)
          @headers = headers
        end

        ##
        # Gets QuestionnaireResponse from provided options
        #
        # @param options [Hash] the search options.
        # @return [FHIR::QuestionnaireResponse::Bundle] an instance of Bundle
        #
        def search(options = {})
          client.search(fhir_model, search_options(options))
        end

        ##
        # Gets a QuestionnaireResponse from its id
        #
        # @param id [String] the QuestionnaireResponse ID.
        # @return [FHIR::QuestionnaireResponse::ClientReply] an instance of ClientReply
        #
        def get(id)
          client.read(fhir_model, id)
        end

        ##
        # Create a QuestionnaireResponse resource from the logged in user.
        #
        # @param data [Hash] questionnaire answers and appointment data hash.
        # @return [FHIR::Patient::ClientReply] an instance of ClientReply
        #
        def create(data) # rubocop:disable Rails/Delegate
          client.create(data)
        end

        ##
        # Returns the FHIR::QuestionnaireResponse class object
        #
        # @return [FHIR::QuestionnaireResponse]
        #
        def fhir_model
          FHIR::QuestionnaireResponse
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
