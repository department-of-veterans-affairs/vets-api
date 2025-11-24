# frozen_string_literal: true

module SOB
  module V0
    class Ch33StatusesController < ApplicationController
      service_tag 'statement-of-benefits'

      STATSD_KEY_PREFIX = 'api.sob'

      skip_before_action :authenticate

      def show
        response = service.get_ch33_status
        render json: SOB::Ch33StatusSerializer.new(response)
      rescue => e
        byebug
        handle_error(e)
      ensure
        StatsD.increment("#{STATSD_KEY_PREFIX}.total")
      end

      private

      def handle_error(e)
        status = e.errors.first[:status].to_i
        StatsD.increment("#{STATSD_KEY_PREFIX}.fail", tags: ["error:#{status}"])
        render json: { errors: e.errors }, status: status || :internal_server_error
      end

      def service
        SOB::DGIB::Service.new('796126859')
      end
    end
  end
end
