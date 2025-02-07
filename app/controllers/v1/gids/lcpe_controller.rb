# frozen_string_literal: true

require 'gi/lcpe/client'

module V1
  module GIDS
    class LCPEController < GIDSController
      private

      def service
        GI::LCPE::Client.new(version_id: version_id, lcpe_type: controller_name)
      end

      def version_id
        request.headers['If-None-Match'] || params[:version]
      end
    end
  end
end
