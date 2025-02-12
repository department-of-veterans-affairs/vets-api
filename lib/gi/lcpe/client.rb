# frozen_string_literal: true

require 'gi/client'
require 'gi/gids_response'
require_relative 'configuration'

module GI
  module LCPE
    class Client < GI::Client
      configuration GI::LCPE::Configuration

      attr_accessor :redis_key, :v_client

      def initialize(version_id: nil, lcpe_type: nil)
        @v_client = version_id
        @redis_key = lcpe_type
        config.allow_304 = versioning_enabled?
        super()
      end

      def get_licenses_and_certs_v1(params = {})
        config.etag = compare_versions if versioning_enabled?
        response = perform(:get, 'v1/lcpe/lacs', params)
        lcpe_response(response)
      end

      def get_license_and_cert_details_v1(params = {})
        validate_client_version do
          lac_id = params[:id]
          perform(:get, "v1/lcpe/lacs/#{lac_id}", params.except(:id, :version))
        end
      end

      def get_exams_v1(params = {})
        config.etag = compare_versions if versioning_enabled?
        response = perform(:get, 'v1/lcpe/exams', params)
        lcpe_response(response)
      end

      def get_exam_details_v1(params = {})
        exam_id = params[:id]
        response = perform(:get, "v1/lcpe/exams/#{exam_id}", params.except(:id))
        gids_response(response)
      end

      private

      def versioning_enabled?
        redis_key.present?
      end

      def lcpe_cache
        @lcpe_cache ||= LCPERedis.new(lcpe_type: redis_key)
      end

      # query GIDS with cache version if more recent than client version
      def compare_versions
        return if [v_client, v_cache].all?(&:nil?)

        [v_client.to_i, v_cache.to_i].max.to_s
      end

      def v_cache
        @v_cache ||= lcpe_cache.cached_version
      end

      # If versioning enabled, validate client has fresh collection before querying details
      def validate_client_version
        return gids_response(yield) unless versioning_enabled?

        # client (and not vets-api cache) must have fresh version
        config.etag = v_client
        response = perform(:get, 'v1/lcpe/lacs', {})
        case response.status
        when 304
          # version is fresh, redirect to query details
          gids_response(yield).body
        else
          # version stale, client must refresh preloaded collection
          lcpe_cache.force_client_refresh_and_cache(response)
        end
      end

      # default to GI::Client#gids_response if versioning not enabled
      def lcpe_response(response)
        if versioning_enabled?
          lcpe_cache.fresh_version_from(gids_response: response, v_client:).body
        else
          gids_response(response)
        end
      end
    end
  end
end
