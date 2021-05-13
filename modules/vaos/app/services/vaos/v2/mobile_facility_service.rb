# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobileFacilityService < VAOS::SessionService
      def get_scheduling_configurations(facility_ids, cc_enabled, pagination_params = {})
        params = {
          facility_ids: facility_ids,
          cc_enabled: cc_enabled
        }.merge(page_params(pagination_params)).compact

        with_monitoring do
          response = perform(:get, url, params, headers)
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

      def url
        '/facilities/v2/scheduling/configurations'
      end
    end
  end
end
