# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    module QuestionnaireResponse
      ##
      # A service object for isolating dependencies from the questionnaire_responses controller.
      #
      # @!attribute session_service
      #   @return [HealthQuest::Lighthouse::Session]
      # @!attribute user
      #   @return [User]
      # @!attribute map_query
      #   @return [PatientGeneratedData::QuestionnaireResponse::MapQuery]
      # @!attribute options_builder
      #   @return [PatientGeneratedData::QuestionnaireResponse::OptionsBuilder]
      class Factory
        attr_reader :session_service, :user, :map_query, :options_builder

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
          @session_service = HealthQuest::Lighthouse::Session.build(user)
          @map_query = PatientGeneratedData::QuestionnaireResponse::MapQuery.build(session_service.retrieve)
          @options_builder = OptionsBuilder
        end

        ##
        # Gets the QuestionnaireResponse from it's unique ID
        #
        # @param data [String] a unique string value
        # @return [FHIR::QuestionnaireResponse::ClientReply]
        #
        def get(id) # rubocop:disable Rails/Delegate
          map_query.get(id)
        end

        ##
        # Gets Questionnaire Responses from a given set of OptionsBuilder
        #
        # @param filters [Hash] the set of query options.
        # @return [FHIR::QuestionnaireResponse::ClientReply] an instance of ClientReply
        #
        def search(filters = {})
          filters.merge!(resource_name)

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
          map_query.create(data, user)
        end

        ##
        # Builds the key/value pair for identifying the resource
        #
        # @return [Hash] a key value pair
        #
        def resource_name
          { resource_name: 'questionnaire_response' }
        end
      end
    end
  end
end
