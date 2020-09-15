# frozen_string_literal: true

require 'emis/service'

module V0
  module Profile
    class ServiceHistoriesController < ApplicationController
      before_action :check_authorization

      # Fetches the service history for the current user.
      # This is an array of select military service episode data.
      #
      # @return [Response] Sample response.body:
      #   {
      #     "data" => {
      #       "id"         => "",
      #       "type"       => "arrays",
      #       "attributes" => {
      #         "service_history" => [
      #           {
      #             "branch_of_service" => "Air Force",
      #             "begin_date"        => "2007-04-01",
      #             "end_date"          => "2016-06-01",
      #             "personnel_category_type_code" => "V"
      #           }
      #         ]
      #       }
      #     }
      #   }
      #
      def show
        response = EMISRedis::MilitaryInformation.for_user(@current_user).service_history

        handle_errors!(response)
        report_results(response)

        render json: response, serializer: ServiceHistorySerializer
      end

      private

      def check_authorization
        report_edipi_presence

        authorize :emis, :access?
      end

      def report_edipi_presence
        if @current_user.edipi.present?
          StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", tags: ['present:true'])
        else
          StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.edipi", tags: ['present:false'])
        end
      end

      def handle_errors!(response)
        raise_error! unless response.is_a?(Array)
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'EMIS_HIST502',
          source: self.class.to_s
        )
      end

      def report_results(response)
        if response.present?
          StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.service_history", tags: ['present:true'])
        else
          StatsD.increment("#{EMIS::Service::STATSD_KEY_PREFIX}.service_history", tags: ['present:false'])
        end
      end
    end
  end
end
