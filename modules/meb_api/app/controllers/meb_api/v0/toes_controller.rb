# frozen_string_literal: true

require 'dgi/toe/sponsors_service'

module MebApi
  module V0
    class ToesController < MebApi::V0::BaseController
      before_action :check_toe_flipper, only: [:sponsor]

      def sponsors
        response = toe_service.post_sponsor

        render json: response, serializer: SponsorsSerializer
      end

      private

      def toe_service
        MebApi::DGI::Toe::Sponsor::Service.new(@current_user)
      end
    end
  end
end
