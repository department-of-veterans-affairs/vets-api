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
      #     :status       => 200,
      #     :appointments => [
      #       {
      #         "clinic_code"             => "409",
      #         "clinic_name"             => "ZZCHY WID BACK",
      #         "start_time"              => "1996-01-12T08:12:00",
      #         "type_name"               => "REGULAR",
      #         "status_name"             => "CHECKED OUT",
      #         "status_code"             => "2",
      #         "other_information"       => "",
      #         "type_code"               => "9",
      #         "appointment_status_code" => nil,
      #         "local_id"                => "2960112.0812",
      #         "appointment_status_name" => nil,
      #         "assigning_facility"      => nil,
      #         "facility_name"           => "CHEYENNE VAMC",
      #         "facility_code"           => "442"
      #       },
      #       ...
      #     ]
      #   }
      #
      def appointments
        icn_present!

        with_monitoring do
          response = perform(:get, appointments_url, nil)

          report_error!(response)

          IHub::Appointments::Response.from(response)
        end
      rescue => e
        Raven.extra_context(
          message: e.message,
          url: config.base_path
        )
        Raven.tags_context(ihub: 'appointments')

        raise e
      end

      private

      def icn_present!
        if @user.icn.blank?
          error = Common::Client::Errors::ClientError.new('User has no ICN', 500, 'User has no ICN')

          raise_backend_exception!('IHUB_102', self.class, error)
        end
      end

      def appointments_url
        if Settings.ihub.in_production
          @user.icn
        else
          "#{@user.icn}?noFilter=true"
        end
      end

      # When an iHub error occurs, iHub sets a 'error_occurred' key to true, returns
      # a status of 200, and includes the error's details in the response.body hash.
      #
      # @param response [Faraday::Env] The raw response from the iHub Appointments endpoint.
      #   Sample response.body when an error has occurred:
      #     {
      #       "error_occurred" => true,
      #       "error_message"  => "An unexpected error occurred processing request!",
      #       "status"         => "Error",
      #       "debug_info"     => "Invalid CRM Webpart URL parameters. Invalid client name.",
      #       "data"           => []
      #     }
      #
      def report_error!(response)
        if response.body&.dig('error_occurred')
          log_error(response)
          raise_backend_exception!('IHUB_101', self.class, response)
        end
      end

      def log_error(response)
        Raven.extra_context(
          response_body: response.body.merge('status_code' => response.status)
        )
        Raven.tags_context(ihub: 'appointments_error_occurred')
      end

      def raise_backend_exception!(key, source, error = nil)
        raise Common::Exceptions::BackendServiceException.new(
          key,
          { source: source.to_s },
          error&.status,
          error&.body
        )
      end
    end
  end
end
