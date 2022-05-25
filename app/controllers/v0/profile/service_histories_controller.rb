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
        if use_vaprofile?
          get_military_info
        else
          get_military_info_from_legacy
        end
      end

      private

      def get_military_info
        service = VAProfile::MilitaryPersonnel::Service.new(@current_user)
        response = service.get_service_history

        handle_errors!(response.episodes)
        report_results(response.episodes)

        json = JSON.parse(response.episodes.to_json, symbolize_names: true)

        render status: response.status, json: json, serializer: ServiceHistorySerializer
      end

      def get_military_info_from_legacy
        response = EMISRedis::MilitaryInformation.for_user(@current_user).service_history

        handle_errors!(response)
        report_results(response)

        render json: response, serializer: ServiceHistorySerializer
      end

      def check_authorization
        report_edipi_presence

        if use_vaprofile?
          authorize :mpi, :queryable?
        else
          authorize :emis, :access?
        end
      end

      def report_edipi_presence
        key = use_vaprofile? ? VAProfile::Stats::STATSD_KEY_PREFIX : EMIS::Service::STATSD_KEY_PREFIX
        tag = @current_user.edipi.present? ? 'present:true' : 'present:false'

        StatsD.increment("#{key}.edipi", tags: [tag])
      end

      def handle_errors!(response)
        raise_error! unless response.is_a?(Array)
      end

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          use_vaprofile? ? 'VET360_502' : 'EMIS_HIST502',
          source: self.class.to_s
        )
      end

      def report_results(response)
        key = use_vaprofile? ? VAProfile::Stats::STATSD_KEY_PREFIX : EMIS::Service::STATSD_KEY_PREFIX
        tag = response.present? ? 'present:true' : 'present:false'

        StatsD.increment("#{key}.service_history", tags: [tag])
      end

      def use_vaprofile?
        Flipper.enabled?(:profile_get_military_info_from_vaprofile, @current_user)
      end
    end
  end
end
