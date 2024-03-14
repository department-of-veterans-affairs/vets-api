# frozen_string_literal: true

require 'lighthouse/facilities/client'

module AskVAApi
  module V0
    class HealthFacilitiesController < FacilitiesController
      around_action :handle_exceptions

      # Index supports the following query parameters:
      # @param bbox - Bounding box in form "xmin,ymin,xmax,ymax" in Lat/Long coordinates
      # @param type - Optional facility type, values = all (default), health, benefits, cemetery
      # @param services - Optional specialty services filter
      def index
        api_results = api.get_facilities(lighthouse_params)

        render_json(serializer, lighthouse_params, api_results)
      end

      def show
        api_result = api.get_by_id(params[:id])

        render_json(serializer, lighthouse_params, api_result)
      end

      private

      def api
        Lighthouse::Facilities::Client.new
      end

      def lighthouse_params
        params.permit(
          :exclude_mobile,
          :ids,
          :lat,
          :long,
          :mobile,
          :page,
          :per_page,
          :state,
          :type,
          :visn,
          :zip,
          bbox: [],
          services: []
        )
      end

      def serializer
        Lighthouse::Facilities::FacilitySerializer
      end

      def handle_exceptions
        yield
      rescue => e
        log_and_render_error('unexpected_error', e, e.status_code)
      end

      def resource_path(options)
        v0_health_facilities_url(options)
      end

      def log_and_render_error(action, exception, status)
        log_error(action, exception)
        render json: { error: exception.message }, status:
      end

      def log_error(action, exception)
        LogService.new.call(action) do |span|
          span.set_tag('error', true)
          span.set_tag('error.msg', exception.message)
        end
        Rails.logger.error("Error during #{action}: #{exception.message}")
      end
    end
  end
end
