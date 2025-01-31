# frozen_string_literal: true

module VAOS
  module V2
    class ProvidersController < VAOS::BaseController
      STATSD_KEY = 'api.vaos.providers'

      def show
        provider_data = vaos_serializer.serialize(provider, 'providers')
        render json: { data: provider_data }
      rescue => e
        StatsDMetric.new(key: STATSD_KEY).save
        StatsD.increment(STATSD_KEY, tags: ["error:#{e.class.name}"])

        raise e
      end

      private

      def vaos_serializer
        @vaos_serializer ||= VAOS::V2::VAOSSerializer.new
      end

      def provider_service
        @provider_service ||= Eps::ProviderService.new(current_user)
      end

      def provider
        provider_service.get_provider_service(provider_id: params[:provider_id])
      end
    end
  end
end
