# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
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
        # Builds a PatientGeneratedData::QuestionnaireResponse::MapQuery instance from a redis session.
        #
        # @param session_store [HealthQuest::SessionStore] the users redis session.
        # @return [PatientGeneratedData::QuestionnaireResponse::MapQuery] an instance of this class
        #
        def self.build(session_store)
          new(session_store)
        end

        def initialize(session_store)
          @access_token = session_store.token
          @headers = auth_header
        end

        ##
        # Gets QuestionnaireResponse from provided options
        #
        # @param options [Hash] the search options.
        # @return [FHIR::QuestionnaireResponse::Bundle] an instance of Bundle
        #
        def search(options)
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
        # @param user [User] the current user.
        # @return [FHIR::ClientReply] an instance of ClientReply
        #
        def create(data, user)
          headers.merge!(content_type_header)

          questionnaire_response = Resource.manufacture(data, user).prepare
          client.create(questionnaire_response)
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

        ##
        # Returns the PGD api path
        #
        # @return [String]
        #
        def api_query_path
          Settings.hqva_mobile.lighthouse.pgd_path
        end
      end
    end
  end
end
