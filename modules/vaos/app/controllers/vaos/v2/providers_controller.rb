# frozen_string_literal: true

module VAOS
  module V2
    class ProvidersController < VAOS::BaseController
      def show
        provider = provider_service.get_provider_service(provider_id:)
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(provider, 'providers')
        render json: { data: serialized }
      end

      private

      def provider_service
        @provider_service ||= Eps::ProviderService.new(current_user)
      end

      def provider_id
        params[:provider_id]
      end
    end
  end
end
