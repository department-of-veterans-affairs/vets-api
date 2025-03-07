# frozen_string_literal: true

require 'gi/lcpe/client'

module V1
  module GIDS
    class LCPEController < GIDSController
      rescue_from LCPERedis::ClientCacheStaleError, with: :version_invalid

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

      # '<record id>@<preload version>'
      def preload_from_enriched_id
        params[:id]&.split('@')&.last
      end

      def preload_from_etag
        request.headers['If-None-Match']&.match(/W\/'(\d+)'/)&.captures&.first
      end

      def set_etag(version)
        response.set_header('ETag', "W/'#{version}'")
      end

      # If additional filter params present, bypass versioning
      def bypass_versioning?
        scrubbed_params.except(:id).present?
      end

      def version_invalid
        render json: { error: 'Version invalid' }, status: :conflict
      end
    end
  end
end
