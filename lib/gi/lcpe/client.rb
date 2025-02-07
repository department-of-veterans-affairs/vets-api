# frozen_string_literal: true

require 'gi/client'
require_relative 'configuration'

module GI
  module LCPE
    class Client < GI::Client
      configuration GI::LCPE::Configuration

      attr_accessor :redis_key, :v_client

      def initialize(version_id:, lcpe_type:)
        @v_client = version_id
        @redis_key = lcpe_type
        config.etag = compare_versions
      end

      def get_licenses_and_certs_v1(params = {})
        response = perform(:get, 'v1/lcpe/lacs', params)
        lcpe_response(response)
      end

      def get_license_and_cert_details_v1(params = {})
        lac_id = params[:id]
        response = perform(:get, "v1/lcpe/lacs/#{lac_id}", params.except(:id))
        lcpe_response(response)
      end

      def get_exams_v1(params = {})
        response = perform(:get, 'v1/lcpe/exams', params)
        lcpe_response(response)
      end

      def get_exam_details_v1(params = {})
        exam_id = params[:id]
        response = perform(:get, "v1/lcpe/exams/#{exam_id}", params.except(:id))
        gids_response(response)
      end

      private

      def compare_versions
        latest = [v_client.to_i, v_cache.to_i].max
        latest.to_s unless latest.zero?
      end

      def v_cache
        @v_cache ||= LCPERedis.find(redis_key)&.response&.version
      end

      def lcpe_response(response)
        LCPERedis.new.response_from(key: redis_key, v_client:, response:)
      end
    end
  end
end
