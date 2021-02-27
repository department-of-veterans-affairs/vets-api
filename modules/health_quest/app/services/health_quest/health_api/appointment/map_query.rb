# frozen_string_literal: true

module HealthQuest
  module HealthApi
    module Appointment
      ##
      # A service object for querying the Health API for Appointment resources.
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
        # Gets an appointment by it's ID
        #
        # @param id [String] the appointment ID.
        # @return [FHIR::ClientReply] an instance of ClientReply
        #
        def get(id)
          client.read(fhir_model, id)
        end

        ##
        # Gets appointments from the provided options
        #
        # @param options [Hash] the search options.
        # @return [FHIR::Bundle] an instance of Bundle
        #
        def search(options)
          client.search(fhir_model, search_options(options))
        end

        ##
        # Returns the FHIR::Appointment class object
        #
        # @return [FHIR::Appointment]
        #
        def fhir_model
          FHIR::Appointment
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
        # Returns the health api path
        #
        # @return [String]
        #
        def api_query_path
          Settings.hqva_mobile.lighthouse.health_api_path
        end
      end
    end
  end
end
