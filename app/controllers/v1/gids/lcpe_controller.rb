# frozen_string_literal: true

require 'gi/lcpe/client'

module V1
  module GIDS
    class LCPEController < GIDSController
      rescue_from LCPERedis::ClientCacheStaleError, with: :version_invalid

      private

      def service
        super if bypass_versioning?

        lcpe_client
      end

      def lcpe_client
        GI::LCPE::Client.new(version_id:, lcpe_type: controller_name)
      end

      def version_id
        request.headers['If-None-Match'] || params[:version]
      end

      def set_etag(version)
        response.set_header('ETag', version)
      end

      # If additional filter params present, bypass versioning
      def bypass_versioning?
        scrubbed_params.except(versioning_params).present?
      end

      def versioning_params
        self.class::VERSIONING_PARAMS
      end

      def version_invalid
        render json: { error: 'Version invalid' }, status: :conflict
      end
    end
  end
end
