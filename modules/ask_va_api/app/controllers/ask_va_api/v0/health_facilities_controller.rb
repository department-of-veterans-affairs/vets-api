# frozen_string_literal: true

require 'lighthouse/facilities/client'

module AskVAApi
  module V0
    class HealthFacilitiesController < FacilitiesApi::ApplicationController
      around_action :handle_exceptions
      skip_before_action :verify_authenticity_token

      def search
        params[:facilityIds] = params[:ids] if params[:ids].present?
        api_results = api.get_facilities(lighthouse_params)

        if Flipper.enabled?(:facilities_locator_mobile_covid_online_scheduling) && covid_mobile_params?
          api_results.each do |api_result|
            api_result.tmp_covid_online_scheduling = mobile_api_get_by_id(api_result.id)
          end
        end
        render_json(serializer, lighthouse_params, api_results)
      end

      def show
        api_result = api.get_by_id(params[:id])

        render_json(serializer, lighthouse_params, api_result)
      end

      private

      def api
        FacilitiesApi::V2::Lighthouse::Client.new
      end

      def lighthouse_params
        params.permit(
          :ids,
          :facilityIds,
          :lat,
          :long,
          :mobile,
          :page,
          :per_page,
          :radius,
          :state,
          :type,
          :visn,
          :zip,
          bbox: [],
          services: []
        )
      end

      def serializer
        FacilitiesApi::V2::Lighthouse::FacilitySerializer
      end

      def resource_path(options)
        v0_health_facilities_url(options)
      end

      def mobile_api
        FacilitiesApi::V2::MobileCovid::Client.new
      end

      def mobile_api_get_by_id(id)
        mobile_api.direct_booking_eligibility_criteria_by_id(id).covid_online_scheduling_available?
      end

      def covid_mobile_params?
        lighthouse_params.fetch(:type, '')[/health/i] && lighthouse_params[:services]&.any?(/Covid19Vaccine/i)
      end

      def handle_exceptions
        yield
      rescue => e
        log_and_render_error('unexpected_error', e, e.status_code)
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
