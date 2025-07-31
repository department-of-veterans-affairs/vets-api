# frozen_string_literal: true

require 'lighthouse/benefits_discovery/service'

module V0
  class BdsGatewayController < ApplicationController
    service_tag 'bds-gateway'

    skip_before_action :verify_authenticity_token, only: [:recommendations]
    skip_before_action :authenticate, only: [:recommendations]
    before_action :check_flipper_enabled, only: [:recommendations]
    skip_after_action :set_csrf_header, only: [:recommendations]

    def recommendations
      api_key, app_id = credentials
      service = BenefitsDiscovery::Service.new(api_key:, app_id:)

      response_data = service.get_eligible_benefits(recommendations_params)
      render json: response_data
    rescue => e
      Rails.logger.error("BDSGateway recommendations error: #{e.message}")
      render json: { error: e.message }, status: :internal_server_error
    end

    private

    def credentials
      app_id = request.headers['x-app-id']
      api_key = request.headers['x-api-key'] || api_key_for_app_id(app_id)

      [api_key, app_id]
    end

    def api_key_for_app_id(app_id)
      # Map specific app IDs to their API keys from settings
      case app_id
      when Settings.lighthouse.benefits_discovery.transition_experience_app_id
        Settings.lighthouse.benefits_discovery.transition_experience_api_key
      else
        raise StandardError, "Unsupported app_id: #{app_id} does not have a configured API key"
      end
    end

    def recommendations_params
      params.permit(:dateOfBirth, :disabilityRating,
                    dischargeStatus: [], branchOfService: [],
                    serviceDates: %i[startDate endDate])
    end

    def check_flipper_enabled
      raise Common::Exceptions::RoutingError, request.path unless Flipper.enabled?(:bds_gateway_enabled)
    end
  end
end
