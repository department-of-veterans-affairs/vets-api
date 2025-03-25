# frozen_string_literal: true

require 'gi/lcpe/client'

module V1
  module GIDS
    class LCPEController < GIDSController
      rescue_from LCPERedis::ClientCacheStaleError, with: :version_invalid

      FILTER_PARAMS = %i[edu_lac_type_nm state lac_nm page per_page].freeze

      private

      def service
        return super if bypass_versioning?

        lcpe_client
      end

      def lcpe_client
        GI::LCPE::Client.new(v_client: preload_version_id, lcpe_type: controller_name)
      end

      def preload_version_id
        preload_from_enriched_id || preload_from_etag
      end

      # '<record id>v<preload version>'
      def preload_from_enriched_id
        params[:id]&.split('v')&.last
      end

      def preload_from_etag
        request.headers['If-None-Match']&.match(%r{W/"(\d+)"})&.captures&.first
      end

      def set_headers(version)
        response.headers.delete('Cache-Control')
        response.headers.delete('Pragma')
        response.set_header('Expires', 1.week.since.to_s)
        response.set_header('ETag', "W/\"#{version}\"")
      end

      # If additional filter params present, bypass versioning
      def bypass_versioning?
        params.keys.map(&:to_sym).intersect?(FILTER_PARAMS)
      end

      def version_invalid
        render json: { error: 'Version invalid' }, status: :conflict
      end
    end
  end
end
