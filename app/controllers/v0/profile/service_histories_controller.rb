# frozen_string_literal: true

require 'emis/service'
require 'va_profile/military_personnel/service'

module V0
  module Profile
    class ServiceHistoriesController < ApplicationController
      before_action :check_authorization

      # Fetches the service history for the current user.
      # This is an array of select military service episode data.
      # Data source is moving from eMIS to VA Profile.
      # Feature toggle will be used until transition is complete.
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
        get_military_info
      end

      private

      def get_military_info
        service = VAProfile::MilitaryPersonnel::Service.new(@current_user)
        response = service.get_service_history

        handle_errors!(response.episodes)
        report_results(response.episodes)

        json = JSON.parse(response.episodes.to_json, symbolize_names: true)

        render status: response.status,
               json:,
               serializer: ServiceHistorySerializer
      end

      def check_authorization
        report_edipi_presence
        authorize :vet360, :military_access?
      end

      def report_edipi_presence
        key = VAProfile::Stats::STATSD_KEY_PREFIX
        tag = @current_user.edipi.present? ? 'present:true' : 'present:false'

        StatsD.increment("#{key}.edipi", tags: [tag])
      end

      def handle_errors!(response)
        raise_error! unless response.is_a?(Array)
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'VET360_502',
          source: self.class.to_s
        )
      end

      def report_results(response)
        key = VAProfile::Stats::STATSD_KEY_PREFIX
        tag = response.present? ? 'present:true' : 'present:false'

        StatsD.increment("#{key}.service_history", tags: [tag])
      end
    end
  end
end
