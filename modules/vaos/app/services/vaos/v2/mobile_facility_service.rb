# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobileFacilityService < VAOS::SessionService
      def get_clinic(station_id:, clinic_id:)
        params = {}
        parent_site_id = station_id[0, 3]
        clinic_path = "/facilities/v2/facilities/#{parent_site_id}/clinics/#{clinic_id}"
        with_monitoring do
          response = perform(:get, clinic_path, params, headers)
          OpenStruct.new(response[:body][:data])
        end
      end

      def get_facilities(ids:, children: nil, type: nil, pagination_params: {})
        params = {
          ids:,
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

      def get_facility(facility_id)
        params = {}
        with_monitoring do
          response = perform(:get, facilities_url_with_id(facility_id), params, headers)
          OpenStruct.new(response[:body])
        end
      end

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
