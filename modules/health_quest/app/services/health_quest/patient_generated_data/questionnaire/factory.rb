# frozen_string_literal: true

require 'forwardable'

module HealthQuest
  module PatientGeneratedData
    module Questionnaire
      ##
      # A service object for isolating dependencies from the questionnaire controller.
      #
      # @!attribute session_service
      #   @return [HealthQuest::Lighthouse::Session]
      # @!attribute user
      #   @return [User]
      # @!attribute map_query
      #   @return [PatientGeneratedData::Questionnaire::MapQuery]
      # @!attribute options_builder
      #   @return [PatientGeneratedData::Questionnaire::OptionsBuilder]
      class Factory
        attr_reader :session_service, :user, :map_query, :options_builder

        ##
        # Builds a PatientGeneratedData::Questionnaire::Factory instance from a given User
        #
        # @param user [User] the currently logged in user.
        # @return [PatientGeneratedData::Questionnaire::Factory] an instance of this class
        #
        def self.manufacture(user)
          new(user)
        end

        def initialize(user)
          @user = user
          @session_service = HealthQuest::Lighthouse::Session.build(user)
          @map_query = PatientGeneratedData::Questionnaire::MapQuery.build(session_service.retrieve)
          @options_builder = OptionsBuilder
        end

        ##
        # Gets Questionnaires from a given set of options
        #
        # @param filters [Hash] a set of query options
        # @return [FHIR::Questionnaire::ClientReply] an instance of ClientReply
        #
        def search(filters = {})
          filters.merge!(resource_name)

          with_options = options_builder.manufacture(user, filters).to_hash
          map_query.search(with_options)
        end

        ##
        # Gets a questionnaire resource from a given ID
        #
        # @param id [String] a questionnaire ID
        # @return [FHIR::Questionnaire::ClientReply] an instance of ClientReply
        #
        def get(id) # rubocop:disable Rails/Delegate
          map_query.get(id)
        end

        ##
        # Builds the key/value pair for identifying the resource
        #
        # @return [Hash] a key value pair
        #
        def resource_name
          { resource_name: 'questionnaire' }
        end
      end
    end
  end
end
