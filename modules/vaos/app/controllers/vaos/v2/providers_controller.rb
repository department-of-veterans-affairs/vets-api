# frozen_string_literal: true

module VAOS
  module V2
    class ProvidersController < VAOS::V0::BaseController
      def show
        provider_params
        response = mobile_ppms_service.get_provider(provider_identifier)
        render json: VAOS::V2::ProvidersSerializer.new(response, meta: response[:meta])
      end

      private

      def mobile_ppms_service
        VAOS::V2::MobilePPMSService.new(current_user)
      end

      def provider_params
        params.require(:id)
        params.permit(:id)
      end

      def provider_identifier
        params[:id]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('provider_identifier', params[:id])
      end
    end
  end
end
