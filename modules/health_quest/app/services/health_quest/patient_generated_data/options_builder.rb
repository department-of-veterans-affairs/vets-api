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
        if appointment_id.present?
          { subject: subject_reference }
        else
          { author: user.icn }
        end
      end

      ##
      # Build the subject reference for the options that are being used to query the PGD for resources.
      #
      # @return [String]
      #
      def subject_reference
        "#{Settings.hqva_mobile.url}/appointments/v1/patients/#{user.icn}/Appointment/#{appointment_id}"
      end

      ##
      # Get the appointment id from the filters that were passed into the controller action.
      #
      # @return [String]
      #
      def appointment_id
        @appointment_id ||= filters&.fetch(:appointment_id, nil)
      end
    end
  end
end
