# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobileFacilityService < VAOS::SessionService
      # Retrieves information about a VA clinic from the VAOS Service.
      #
      # @param station_id [String] the ID of the VA facility where the clinic is located
      # @param clinic_id [String] the ID of the clinic to retrieve
      #
      # @return [OpenStruct] An OpenStruct object containing information about the clinic.
      #
      def get_clinic(station_id:, clinic_id:)
        params = { clinicIds: clinic_id }
        parent_site_id = station_id[0, 3]
        with_monitoring do
          response = perform(:get, clinic_url(parent_site_id), params, headers)
          OpenStruct.new(response[:body][:data]&.first) # only one clinic is returned
        end
      end

      # Retrieves a clinic from the cache if it exists, otherwise retrieves the clinic from the VAOS Service.
      #
      # @param station_id [String] the ID of the VA facility where the clinic is located
      # @param clinic_id [String] the ID of the clinic to retrieve
      #
      # @return [OpenStruct] an OpenStruct containing information about the clinic,
      #         retrieved from either the cache or the VAOS Service.
      #
      def get_clinic_with_cache(station_id:, clinic_id:)
        Rails.cache.fetch("vaos_clinic_#{station_id}_#{clinic_id}", expires_in: 12.hours) do
          get_clinic(station_id:, clinic_id:)
        end
      end

      # Get clinic details for a given station and clinic ids from the VAOS Service
      #
      # @param station_id [String] The id of the station to get clinic details for
      # @param clinic_ids [Array] A list of clinic ids to get details for
      #
      # @return [Array<OpenStruct>] - An array of OpenStruct objects containing clinic details
      #
      # @raise [Common::Exceptions::PrameterMissing] if station_id or clinic_ids are not provided
      #
      # @example
      #   ids = %w[16, 455]
      #   station_id = '983'
      #   clinics = VAOS::V2::MobileFacilityService.new.get_clinics(station_id, ids)
      #   or
      #   clinics = VAOS::V2::MobileFacilityService.new(session: session).get_clinics(station_id, 16, 455)
      #
      def get_clinics(station_id, *clinic_ids)
        raise Common::Exceptions::ParameterMissing, 'station_id' if station_id.blank?
        raise Common::Exceptions::ParameterMissing, 'clinic_ids' if bad_arg?(clinic_ids)

        params = { clinicIds: clinic_ids.join(',') }
        parent_site_id = station_id[0, 3]
        with_monitoring do
          response = perform(:get, clinic_url(parent_site_id), params, headers)
          response.body[:data]&.map { |clinic| OpenStruct.new(clinic) }
        end
      end

      # Retrieves facilities based on the provided parameters from the Mobile Facility Service.
      #
      # @param ids [String] a required parameter that contains a comma-separated list of facility IDs.
      # @param children [Boolean] an optional parameter that specifies if child facilities should be included (true) or
      # excluded (false/nil).
      # @param type [String] an optional parameter that specifies the type of facility to retrieve.
      # @param pagination_params [Hash] an optional parameter that contains pagination parameters to use in the request
      #
      # @return [Hash] a hash with two keys:
      #   - :data: A hash containing information about the facilities
      #   - :meta: A hash containing pagination information
      #
      def get_facilities(ids:, children: nil, type: nil, schedulable: nil, pagination_params: {})
        params = {
          ids:,
          children:,
          type:,
          schedulable:
        }.merge(page_params(pagination_params)).compact
        with_monitoring do
          options = { params_encoder: Faraday::FlatParamsEncoder }
          response = perform(:get, facilities_url, params, headers, options)
          {
            data: deserialized_facilities(response.body[:data]),
            meta: pagination(pagination_params)
          }
        end
      end

      # Retrieves information about a VA facility from the Mobile Facility Service given its ID.
      #
      # @param facility_id [String] the ID of the VA facility to retrieve information about
      #
      # @return [OpenStruct] An OpenStruct object containing information about the facility.
      #
      def get_facility(facility_id)
        params = {}
        with_monitoring do
          response = perform(:get, facilities_url_with_id(facility_id), params, headers)
          OpenStruct.new(response[:body])
        end
      end

      # Retrieves a VA facility from the cache if it exists, otherwise retrieves the facility
      # from the Mobile Facility Service.
      #
      # @param facility_id [String] the ID of the VA facility to retrieve
      #
      # @return [OpenStruct] An OpenStruct object containing information about the facility
      #
      def get_facility_with_cache(facility_id)
        Rails.cache.fetch("vaos_facility_#{facility_id}", expires_in: 12.hours) do
          get_facility(facility_id)
        end
      end

      # Retrieves scheduling configurations for VA facilities based on the provided parameters.
      #
      # @param facility_ids [String] A comma-separated list of facility IDs to retrieve scheduling configurations for.
      # @param cc_enabled [Boolean] an optional parameter If true, then only scheduling configurations for
      #                   community care-enabled sites will be returned. If false, then only scheduling configurations
      #                   for community care-disabled sites will be returned. If not provided, then community care
      #                   status will be ignored.
      # @param pagination_params [Hash] an optional parameter that contains pagination parameters to use in the request.
      #
      # @return [Hash] a hash with two keys:
      #   - :data: A hash containing information about the scheduling configurations.
      #   - :meta: A hash containing pagination information.
      #
      def get_scheduling_configurations(facility_ids, cc_enabled = nil, pagination_params = {})
        params = {
          facilityIds: facility_ids,
          ccEnabled: cc_enabled
        }.merge(page_params(pagination_params)).compact

        with_monitoring do
          response = perform(:get, scheduling_url, params, headers)
          {
            data: deserialized_configurations(response.body[:data]),
            meta: pagination(pagination_params)
          }
        end
      end

      private

      def deserialized_configurations(configuration_list)
        return [] unless configuration_list

        configuration_list.map { |configuration| OpenStruct.new(configuration) }
      end

      def deserialized_facilities(facility_list)
        return [] unless facility_list

        facility_list.map { |facility| OpenStruct.new(facility) }
      end

      def bad_arg?(arg)
        (arg.length == 1 && arg[0].blank?) || arg.length.zero?
      end

      def pagination(pagination_params)
        {
          pagination: {
            current_page: pagination_params[:page] || 0,
            per_page: pagination_params[:per_page] || 0,
            total_pages: 0, # underlying api doesn't provide this; how do you build a pagination UI without it?
            total_entries: 0 # underlying api doesn't provide this.
          }
        }
      end

      def page_params(pagination_params)
        if pagination_params[:per_page]&.positive?
          { pageSize: pagination_params[:per_page], page: pagination_params[:page] }
        else
          { pageSize: pagination_params[:per_page] || 0 }
        end
      end

      def clinic_url(station_id)
        "/vaos/v1/locations/#{station_id}/clinics"
      end

      def scheduling_url
        '/facilities/v2/scheduling/configurations'
      end

      def facilities_url
        '/facilities/v2/facilities'
      end

      def facilities_url_with_id(id)
        "/facilities/v2/facilities/#{id}"
      end
    end
  end
end
