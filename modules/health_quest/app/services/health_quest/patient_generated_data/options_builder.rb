# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    ##
    # A search options hash builder for a FHIR::Client's search instance method.
    #
    # @!attribute user
    #   @return [User]
    # @!attribute filters
    #   @return [Hash]
    class OptionsBuilder
      attr_reader :user, :filters

      ##
      # Builds a PatientGeneratedData::OptionsBuilder instance from a given User and Hash
      #
      # @param user [User] the currently logged in user.
      # @param filters [PatientGeneratedData::QuestionnaireResponse::OptionsBuilder] the set of query options.
      # @return [PatientGeneratedData::QuestionnaireResponse::Factory] an instance of this class
      #
      def self.manufacture(user, filters)
        new(user, filters)
      end

      def initialize(user, filters)
        @user = user
        @filters = filters
      end

      ##
      # Build the options hash that will be used to query the PGD for resources.
      #
      # @return [Hash]
      #
      def to_hash
        name = filters.delete(:resource_name)
        query_param = filters.keys.pop

        registry[name.to_sym][query_param.to_sym]
      end

      ##
      # The registry which holds the return value for `to_hash`.
      #
      # @return [Hash]
      #
      def registry
        {
          questionnaire_response: {
            appointment_id: { _tag: appointment_reference },
            patient: { subject: user.icn },
            authored: { authored: resource_created_date }
          },
          questionnaire: {
            use_context: { 'context-type-value': context_type_value }
          }
        }
      end

      ##
      # Build the subject reference for the options that are being used to query the PGD for resources.
      #
      # @return [String]
      #
      def appointment_reference
        @appointment_reference ||=
          "#{lighthouse.url}#{lighthouse.pgd_path}/NamingSystem/va-appointment-identifier|#{appointment_id}"
      end

      ##
      # Get the appointment id from the filters.
      #
      # @return [String]
      #
      def appointment_id
        @appointment_id ||= filters&.fetch(:appointment_id, nil)
      end

      ##
      # Get the authored date from the filters.
      #
      # @return [String]
      #
      def resource_created_date
        @resource_created_date ||= filters&.fetch(:authored, nil)
      end

      ##
      # Get the use context values from the filters.
      #
      # @return [String]
      #
      def context_type_value
        @context_type_value ||= filters&.fetch(:use_context, nil)
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
