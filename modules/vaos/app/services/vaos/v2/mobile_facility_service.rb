# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobileFacilityService < VAOS::SessionService
      def get_scheduling_configurations(facility_ids, cc_enabled)
        params = {
          facility_ids: facility_ids,
          cc_enabled: cc_enabled
        }

        with_monitoring do
          response = perform(:get, url, params, headers)
          {
            data: deserialized_configuration(response.body),
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

      def url
        "/facilities/v2/scheduling/configurations"
      end
    end
  end
end
