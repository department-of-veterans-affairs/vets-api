# frozen_string_literal: true

require 'forwardable'

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      ##
      # A service object for isolating dependencies from the questionnaire_responses controller.
      #
      # @!attribute session_service
      #   @return [HealthQuest::SessionService]
      # @!attribute user
      #   @return [User]
      # @!attribute map_query
      #   @return [PatientGeneratedData::QuestionnaireResponse::MapQuery]
      # @!attribute options_builder
      #   @return [PatientGeneratedData::QuestionnaireResponse::OptionsBuilder]
      class Factory
        extend Forwardable

        attr_reader :session_service, :user, :map_query, :options_builder

        ##
        # This delegate method is called with the patient id
        #
        # @return [FHIR::QuestionnaireResponse::ClientReply]
        #
        def_delegator :@map_query, :get

        ##
        # Builds a PatientGeneratedData::QuestionnaireResponse::Factory instance from a given User
        #
        # @param user [User] the currently logged in user.
        # @return [PatientGeneratedData::QuestionnaireResponse::Factory] an instance of this class
        #
        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @user = user
          @session_service = HealthQuest::SessionService.new(user)
          @map_query = PatientGeneratedData::QuestionnaireResponse::MapQuery.build(session_service.headers)
          @options_builder = OptionsBuilder
        end

        ##
        # Gets Questionnaire Responses from a given set of OptionsBuilder
        #
        # @param filters [PatientGeneratedData::QuestionnaireResponse::OptionsBuilder] the set of query options.
        # @return [FHIR::QuestionnaireResponse::ClientReply] an instance of ClientReply
        #
        def search(filters)
          with_options = options_builder.manufacture(user, filters).to_hash

          map_query.search(with_options)
        end

        ##
        # Create a QuestionnaireResponse resource from the logged in user.
        #
        # @param data [Hash] questionnaire answers and appointment data hash.
        # @return [FHIR::Patient::ClientReply] an instance of ClientReply
        #
        def create(data)
          questionnaire_response = Resource.manufacture(data, user).prepare

          map_query.create(questionnaire_response)
        end
      end
    end
  end
end
