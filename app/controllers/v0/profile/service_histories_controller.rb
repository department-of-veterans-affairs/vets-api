# frozen_string_literal: true

module V0
  module Profile
    class ServiceHistoriesController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :emis, :access? }

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
      #             "end_date"          => "2016-06-01"
      #           }
      #         ]
      #       }
      #     }
      #   }
      #
      def show
        response = EMISRedis::MilitaryInformation.for_user(@current_user).service_history

        handle_errors!(response)

        render json: response, serializer: ServiceHistorySerializer
      end

      private

      def handle_errors!(response)
        raise_error! unless response.is_a?(Array)

        log_profile_data_to_sentry(response) if response.try(:first).try(:dig, :branch_of_service).blank?
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'EMIS_HIST502',
          source: self.class.to_s
        )
      end
    end
  end
end
