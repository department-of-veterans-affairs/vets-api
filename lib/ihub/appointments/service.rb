# frozen_string_literal: true

require 'common/client/base'

module IHub
  module Appointments
    class Service < IHub::Service
      include Common::Client::Monitoring

      configuration IHub::Appointments::Configuration

      # Fetches a collection of veteran appointment data from iHub.
      #
      # Per iHub docs, requires a service parameter of noFilter=true,
      # in non-production environments.
      #
      # @return [IHub::Appointments::Response] Sample response:
      #   {
      #     :status        => 200,
      #     :response_data => {
      #       "error_occurred" => false,
      #       "error_message"  => nil,
      #       "status"         => nil,
      #       "debug_info"     => nil,
      #       "data"           => [
      #         {
      #           "clinic_code"             => "409",
      #           "clinic_name"             => "ZZCHY WID BACK",
      #           "date_time_date"          => "1996-01-12T08:12:00",
      #           "type_name"               => "REGULAR",
      #           "status_name"             => "CHECKED OUT",
      #           "status_code"             => "2",
      #           "other_information"       => "",
      #           "type_code"               => "9",
      #           "date_time"               => "199601120812",
      #           "appointment_status_code" => nil,
      #           "local_id"                => "2960112.0812",
      #           "appointment_status_name" => nil,
      #           "assigning_facility"      => nil,
      #           "facility_name"           => "CHEYENNE VAMC",
      #           "facility_code"           => "442"
      #         },
      #       ...
      #     ]
      #   }
      #
      def appointments
        raise 'User has no ICN' if @user.icn.blank?

        with_monitoring do
          response = perform(:get, appointments_url, nil)

          IHub::Appointments::Response.from(response)
        end
      rescue StandardError => error
        log_message_to_sentry(
          error.message,
          :error,
          extra_context: { url: config.base_path },
          ihub: 'appointments'
        )

        raise error
      end

      def appointments_url
        if Settings.ihub.in_production
          @user.icn
        else
          "#{@user.icn}?noFilter=true"
        end
      end
    end
  end
end
