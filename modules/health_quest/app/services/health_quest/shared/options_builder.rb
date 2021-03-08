# frozen_string_literal: true

module HealthQuest
  module Shared
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
      # Builds a Shared::OptionsBuilder instance from a given User and Hash
      #
      # @param user [User] the currently logged in user.
      # @param filters [Hash] the set of query options.
      # @return [Shared::OptionsBuilder] an instance of this class
      #
      def self.manufacture(user, filters)
        new(user, filters)
      end

      def initialize(user, filters)
        @user = user
        @filters = filters
      end

      ##
      # Build the options hash that will be used to query the lighthouse for resources.
      #
      # @return [Hash]
      #
      def to_hash
        name = filters.delete(:resource_name).to_sym
        query_params = filters.keys.map(&:to_sym)

        registry[name].slice(*query_params)
      end

      ##
      # The registry which holds the return value for the `to_hash` method.
      #
      # @return [Hash]
      #
      def registry
        {
          appointment: {
            patient: user.icn,
            date: appointment_dates,
            location: clinic_id
          },
          location: { _id: location_ids },
          organization: { _id: organization_ids },
          questionnaire_response: {
            subject: appointment_reference,
            source: user.icn,
            authored: resource_created_date
          },
          questionnaire: { 'context-type-value': context_type_value }
        }
      end

      def location_ids
        @location_ids ||= filters&.fetch(:_id, nil)
      end

      def organization_ids
        @organization_ids ||= filters&.fetch(:_id, nil)
      end

      ##
      # Get the location id from the filters.
      #
      # @return [String]
      #
      def clinic_id
        @clinic_id ||= filters&.fetch(:location, nil)
      end

      ##
      # Get the range of appointment dates from the filters.
      #
      # @return [String]
      #
      def appointment_dates
        @appointment_dates ||= filters&.fetch(:date, nil)
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
        @appointment_id ||= filters&.fetch(:subject, nil)
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
        @context_type_value ||= filters&.fetch(:'context-type-value', nil)
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
