# frozen_string_literal: true

require 'gi/lcpe/client'

module V1
  module GIDS
    class LCPEController < GIDSController
      private

      def service
        super unless versioning_required?
        
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
    end
  end
end
