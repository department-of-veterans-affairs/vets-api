# frozen_string_literal: true

require 'gi/client'
require_relative 'configuration'

module GI
  module LCPE
    class Client < GI::Client
      configuration GI::LCPE::Configuration

      def get_licenses_and_certs_v1(params = {})
        response = perform(:get, 'v1/lcpe/lacs', params)
        set_redis_key_from(__method__, params)
        lcpe_response(response)
      end

      def get_license_and_cert_details_v1(params = {})
        enriched_id = params[:id]
        response = perform(:get, "v1/lcpe/lacs/#{enriched_id}", params.except(:id))
        set_redis_key_from(__method__, params)
        lcpe_response(response)
      end

      def get_exams_v1(params = {})
        response = perform(:get, 'v1/lcpe/exams', params)
        set_redis_key_from(__method__, params)
        lcpe_response(response)
      end

      def get_exam_details_v1(params = {})
        enriched_id = params[:id]
        response = perform(:get, "v1/lcpe/exams/#{enriched_id}", params.except(:id))
        set_redis_key_from(__method__, params)
        lcpe_response(response)
      end

      private

      def set_redis_key_from(method, params)
        @redis_key = method.to_s + params.except(:version).to_s
      end

      def lcpe_response(response)
        LCPERedis.new.response_from_redis_or_service(key: @redis_key, response:)
      end
    end
  end
end
