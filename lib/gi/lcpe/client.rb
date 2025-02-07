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
      end

      def get_licenses_and_certs_v1(params = {})
        config.etag = compare_versions if versioning_enabled?
        response = perform(:get, 'v1/lcpe/lacs', params)
        lcpe_response(response)
      end

      def get_license_and_cert_details_v1(params = {})
        validate_client_version do
          lac_id = params[:id]
          response = perform(:get, "v1/lcpe/lacs/#{lac_id}", params.except(:id))
          gids_response(response)
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

      # query GIDS with cache version if more recent than client version
      def compare_versions
        return if [v_client, v_cache].all?(&:nil?)

        [v_client.to_i, v_cache.to_i].max.to_s
      end

      def v_cache
        @v_cache ||= LCPERedis.cached_version(redis_key)
      end

      def validate_client_version
        return yield unless versioning_enabled?

        config.etag = v_client
        response = perform(:get, 'v1/lcpe/lacs', {})
        case response.status
        when 304
          yield
        else
          LCPERedis.new.force_client_refresh_and_cache(key: redis_key, response:)
        end
      end

      # default to GIDS cache design if versioning not enabled
      def lcpe_response(response)
        if versioning_enabled?
          LCPERedis.new.response_from(key: redis_key, v_client:, response:)
        else
          gids_response(response)
        end
      end
    end
  end
end
