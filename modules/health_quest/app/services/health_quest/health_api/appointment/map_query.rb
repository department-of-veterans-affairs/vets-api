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
        # Returns the FHIR::Appointment class object
        #
        # @return [FHIR::Appointment]
        #
        def fhir_model
          FHIR::Appointment
        end
      end
    end
  end
end
