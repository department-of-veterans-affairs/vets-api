# frozen_string_literal: true

module TravelPay
  module V0
    class ClaimsController < ApplicationController
      def index
        begin
          claims = service.get_claims(@current_user)
        rescue Faraday::Error => e
          TravelPay::ServiceError.raise_mapped_error(e)
        end

        render json: claims, status: :ok
      end

      private

      def service
        @service ||= TravelPay::ClaimsService.new
      end

      def common_exception(e)
        case e
        when Faraday::ResourceNotFound
          Common::Exceptions::ResourceNotFound.new
        else
          Common::Exceptions::InternalServerError.new
        end
      end
    end
  end
end
