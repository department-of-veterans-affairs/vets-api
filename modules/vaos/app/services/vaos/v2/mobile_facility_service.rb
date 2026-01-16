# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobileFacilityService < VAOS::SessionService
      extend Memoist

      # Retrieves information about a VA clinic from the VAOS Service.
      #
      # @param station_id [String] the ID of the VA facility where the clinic is located
      # @param clinic_id [String] the ID of the clinic to retrieve
      #
      # @return [OpenStruct] An OpenStruct object containing information about the clinic.
      #
      def get_clinic!(station_id:, clinic_id:)
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
          get_clinic!(station_id:, clinic_id:)
        end
      end

      # Retrieves a clinic from the cache if it exists, otherwise retrieves the clinic from the VAOS Service.
      # Returns nil on error.
      #
      # @param station_id [String] the ID of the VA facility where the clinic is located
      # @param clinic_id [String] the ID of the clinic to retrieve
      #
      # @return [OpenStruct] an OpenStruct containing information about the clinic,
      #         retrieved from either the cache or the VAOS Service.
      #
      def get_clinic(location_id, clinic_id)
        get_clinic_with_cache(station_id: location_id, clinic_id:)
      rescue Common::Exceptions::BackendServiceException => e
        Rails.logger.error(
          "Error fetching clinic #{clinic_id} for location #{location_id}",
          clinic_id:,
          location_id:,
          vamf_msg: e.original_body
        )
        nil
      end
      memoize :get_clinic

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
      def get_facilities(ids:, schedulable:, children: nil, type: nil, pagination_params: {})
        params = {
          ids:,
          schedulable:,
          children:,
          type:
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

      # Returns the list of facility details for the given facility IDs.
      # The method first checks the Rails cache for each ID and returns the data
      # set, then fetches any IDs that were not already cached and caches that data for future use.
      #
      # @param ids [Array<String>] An array of facility IDs to retrieve details for.
      #
      # @raise [Common::Exceptions::ParameterMissing] if the `ids` argument is missing or empty.
      #
      # @return [Hash] A hash of facility details fetched from the cache and remote call.
      #   The hash has two keys: `:data` (an array of facility details) and `:meta` (pagination metadata).
      #   The `:data` array includes facility details in an [OpenStruct] format.
      #   The `:meta` hash includes pagination details and is currently always an empty hash.
      #
      def get_facilities_with_cache(*ids)
        raise Common::Exceptions::ParameterMissing, 'ids' if bad_arg?(ids)

        ids = ids.flatten.uniq
        cached = read_cached_facilities(ids)
        uncached = ids - cached.pluck(:id)
        fetched = fetch_uncached_and_cache(uncached)

        {
          data: cached.concat(fetched),
          meta: pagination({})
        }
      end

      # Retrieves information about a VA facility from the Mobile Facility Service given its ID.
      #
      # @param facility_id [String] the ID of the VA facility to retrieve information about
      #
      # @return [OpenStruct] An OpenStruct object containing information about the facility.
      #
      def get_facility!(facility_id)
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
          get_facility!(facility_id)
        end
      end

      # Retrieves a VA facility from the cache if it exists, otherwise retrieves the facility
      # from the Mobile Facility Service. Returns nil on error.
      #
      # @param facility_id [String] the ID of the VA facility to retrieve
      #
      # @return [OpenStruct] An OpenStruct object containing information about the facility
      #
      def get_facility(location_id)
        get_facility_with_cache(location_id)
      rescue Common::Exceptions::BackendServiceException
        Rails.logger.error(
          "VAOS Error fetching facility details for location_id #{location_id}",
          location_id:
        )
        nil
      end
      memoize :get_facility

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
        params = scheduling_params(facility_ids, cc_enabled, pagination_params)

        with_monitoring do
          response = perform(:get, scheduling_url, params, headers)
          {
            data: deserialized_configurations(response.body[:data]),
            meta: pagination(pagination_params)
          }
        end
      end

      private

      # Reads cached facilities from Rails cache. It reads the cache for each id
      # provided in the array, maps them into a new array and returns the new array
      # excluding nil values.
      #
      # @param ids [Array<String>] An array containing the ids of facilities.
      #
      # @return [Array<OpenStruct>] An array containing the cached facilities.
      #
      def read_cached_facilities(ids)
        ids.map { |id| Rails.cache.read("vaos_facility_#{id}") }.compact
      end

      # fetches the facilities via 'get_facilities' method that are not present in
      # the cache and caches them for future use.
      #
      # @param ids [Array<String>] An array containing the ids of facilities.
      #
      # @return [Array<OpenStruct>] An array containing the fetched facilities. Or
      #  an empty array if 'ids' is an empty array.
      #
      def fetch_uncached_and_cache(ids)
        return [] if ids.empty?

        facilities = get_facilities(ids: ids.join(','), schedulable: nil, children: false)
        facilities[:data].each do |facility|
          Rails.cache.write("vaos_facility_#{facility[:id]}", facility, expires_in: 12.hours)
        end
        facilities[:data]
      end

      def deserialized_configurations(configuration_list)
        return [] unless configuration_list

        if Flipper.enabled?(:va_online_scheduling_use_vpg, user)
          configuration_list.map do |configuration|
            OpenStruct.new({
                             facility_id: configuration[:facility_id],
                             va_services: configuration[:va_clinical_services],
                             cc_services: configuration[:cc_clinical_services],
                             community_care: configuration[:community_care]
                           })
          end
        else
          configuration_list.map { |configuration| OpenStruct.new(configuration) }
        end
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

      def scheduling_params(facility_ids, cc_enabled = nil, pagination_params = {})
        if Flipper.enabled?(:va_online_scheduling_use_vpg, user)
          { communityCare: cc_enabled, locations: facility_ids }.compact
        else
          {
            facilityIds: facility_ids,
            ccEnabled: cc_enabled
          }.merge(page_params(pagination_params)).compact
        end
      end

      def clinic_url(station_id)
        "/#{base_vaos_route}/locations/#{station_id}/clinics"
      end

      def scheduling_url
        if Flipper.enabled?(:va_online_scheduling_use_vpg, user)
          '/vpg/v1/scheduling/configurations'
        elsif Flipper.enabled?(:va_online_scheduling_cscs_migration, user)
          '/cscs/v1/configurations'
        else
          '/facilities/v2/scheduling/configurations'
        end
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
