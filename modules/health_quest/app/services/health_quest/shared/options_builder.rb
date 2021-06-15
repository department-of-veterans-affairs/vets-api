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
          appointment: appointment_registry,
          location: location_registry,
          organization: organization_registry,
          questionnaire_response: questionnaire_response_registry,
          questionnaire: questionnaire_registry
        }
      end

      ##
      # The configuration for the appointment registry.
      #
      # @return [Hash]
      #
      def appointment_registry
        {
          patient: user.icn,
          date: appointment_dates,
          location: clinic_id,
          _count: resource_count,
          page: resource_page
        }
      end

      ##
      # The configuration for the location registry.
      #
      # @return [Hash]
      #
      def location_registry
        {
          _id: location_ids,
          organization: org_id,
          identifier: location_identifier,
          _count: resource_count,
          page: resource_page
        }
      end

      ##
      # The configuration for the organization registry.
      #
      # @return [Hash]
      #
      def organization_registry
        {
          _id: organization_ids,
          identifier: organization_identifier,
          _count: resource_count,
          page: resource_page
        }
      end

      ##
      # The configuration for the questionnaire response registry.
      #
      # @return [Hash]
      #
      def questionnaire_response_registry
        {
          subject: appointment_reference,
          source: user.icn,
          authored: resource_created_date,
          _count: resource_count,
          page: resource_page
        }
      end

      ##
      # The configuration for the questionnaire registry.
      #
      # @return [Hash]
      #
      def questionnaire_registry
        {
          'context-type-value': context_type_value,
          _count: resource_count,
          page: resource_page
        }
      end

      ##
      # Get the list of location ids from the filters.
      #
      # @return [String]
      #
      def location_ids
        @location_ids ||= filters&.fetch(:_id, nil)
      end

      ##
      # Get the list of organization ids from the filters.
      #
      # @return [String]
      #
      def organization_ids
        @organization_ids ||= filters&.fetch(:_id, nil)
      end

      ##
      # Get the list of locations for an organization from the filters.
      #
      # @return [String]
      #
      def org_id
        @org_id ||= filters&.fetch(:organization, nil)
      end

      ##
      # Get the organization identifier from the filters.
      #
      # @return [String]
      #
      def organization_identifier
        @organization_identifier ||= filters&.fetch(:identifier, nil)
      end

      ##
      # Get the organization identifier from the filters.
      #
      # @return [String]
      #
      def location_identifier
        @location_identifier ||= filters&.fetch(:identifier, nil)
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

      ##
      # Get the resource count from the filters.
      #
      # @return [String]
      #
      def resource_count
        @resource_count ||= filters&.fetch(:_count, nil)
      end

      ##
      # Get the resource page from the filters.
      #
      # @return [String]
      #
      def resource_page
        @resource_page ||= filters&.fetch(:page, nil)
      end

      private

      def lighthouse
        Settings.hqva_mobile.lighthouse
      end
    end
  end
end
