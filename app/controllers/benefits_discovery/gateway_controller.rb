# frozen_string_literal: true

require 'lighthouse/benefits_discovery/service'

module BenefitsDiscovery
  class GatewayController < ApplicationController
    service_tag 'bds-gateway'

    skip_before_action :verify_authenticity_token, only: [:proxy]
    skip_before_action :authenticate, only: [:proxy]
    before_action :check_flipper_enabled, only: [:proxy]
    skip_after_action :set_csrf_header, only: [:proxy]

    def proxy
      api_key, app_id = credentials
      service = ::BenefitsDiscovery::Service.new(api_key:, app_id:)

      response_data = service.proxy_request(method: request.method_symbol, path: params[:path],
                                            body: request.raw_post.presence)
      render json: response_data
    rescue Common::Client::Errors::ClientError => e
      log_proxy_error(e, path: params[:path])
      render json: e.body, status: e.status
    rescue Common::Exceptions::Unauthorized => e
      log_proxy_error(e, path: params[:path])
      render json: { error: e.message }, status: :unauthorized
    rescue => e
      log_proxy_error(e, path: params[:path])
      render json: { error: e.message }, status: :internal_server_error
    end

    private

    def credentials
      app_id = request.headers['x-app-id']
      api_key = request.headers['x-api-key'] || fetch_api_key(app_id)

      [api_key, app_id]
    end

    def fetch_api_key(app_id)
      # Map specific app IDs to their API keys from settings
      case app_id
      when Settings.lighthouse.benefits_discovery.transition_experience_app_id
        Settings.lighthouse.benefits_discovery.transition_experience_api_key
      else
        raise Common::Exceptions::Unauthorized
      end
    end

    def log_proxy_error(error, path:)
      Rails.logger.error("Benefits Discovery Gateway proxy error: #{error.message}", path:)
    end

    def check_flipper_enabled
      raise Common::Exceptions::RoutingError, request.path unless Flipper.enabled?(:bds_gateway_enabled)
    end
  end
end
