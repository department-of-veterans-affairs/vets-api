# frozen_string_literal: true

require 'gi/client'
require 'gi/gids_response'
require_relative 'configuration'

module GI
  module LCPE
    class Client < GI::Client
      configuration GI::LCPE::Configuration

      attr_accessor :redis_key, :v_client

      def initialize(v_client: nil, lcpe_type: nil)
        @v_client = v_client
        @redis_key = lcpe_type
        super()
      end

      def get_licenses_and_certs_v1(params = {})
        config.set_etag(v_cache) if versioning_enabled?
        response = perform(:get, 'v1/lcpe/lacs', params)
        lcpe_response(response)
      end

      def get_license_and_cert_details_v1(params = {})
        validate_client_version do
          lac_id = params[:id]
          perform(:get, "v1/lcpe/lacs/#{lac_id}", params.except(:id))
        end
      end

      def get_exams_v1(params = {})
        config.set_etag(v_cache) if versioning_enabled?
        response = perform(:get, 'v1/lcpe/exams', params)
        lcpe_response(response)
      end

      def get_exam_details_v1(params = {})
        validate_client_version do
          exam_id = params[:id]
          perform(:get, "v1/lcpe/exams/#{exam_id}", params.except(:id))
        end
      end

      private

      # LCPE::Client can be called from GIDSRedis, in which case versioning is disabled
      def versioning_enabled?
        redis_key.present?
      end

      def lcpe_cache
        @lcpe_cache ||= LCPERedis.new(lcpe_type: redis_key)
      end

      def v_cache
        @v_cache ||= lcpe_cache.cached_version
      end

      # Validate client has fresh collection before querying details
      def validate_client_version
        # client (and not vets-api cache) must have fresh version
        config.set_etag(v_client)
        validation_response = perform(:get, "v1/lcpe/#{redis_key}", {})
        case validation_response.status
        when 304
          config.etag = nil
          # version is fresh, redirect to query details
          details_response = yield
          gids_response(details_response).body
        else
          # version stale, client must refresh preloaded collection
          lcpe_cache.force_client_refresh_and_cache(validation_response)
        end
      end

      # default to GI::Client#gids_response if versioning not enabled
      def lcpe_response(response)
        if versioning_enabled?
          lcpe_cache.fresh_version_from(response).body
        else
          gids_response(response)
        end
      end
    end
  end
end
