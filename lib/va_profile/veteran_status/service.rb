# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require 'va_profile/models/veteran_status'
require_relative 'configuration'
require_relative 'veteran_status_response'

module VAProfile
  module VeteranStatus
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::VeteranStatus::Configuration

      OID = '2.16.840.1.113883.3.42.10001.100001.12'  # double check swagger
      AAID = '^NI^200DOD^USDOD'  # double check swagger. 

      # GET's a user's veteran status info from the VAProfile API
      # If a user is not found in VAProfile, an empty VeteranStatusResponse with a 404 status will be returned
      # @return [VAProfile::VeteranStatus::VeteranStatusResponse] response wrapper around a veteran_status object
      def get_veteran_status_data
        def get_veteran_status_data
          with_monitoring do
            edipi_present!
        
            response = perform(:post, identity_path, VAProfile::Models::VeteranStatus.in_json)
        
            VeteranStatusResponse.from(@current_user, response)
          end
        rescue Common::Client::Errors::ClientError => e
          additional_params = { edipi: @user.edipi, title38_status: title38_status }  # Add title38_status to the logging
        
          if e.status == 404
            log_exception_to_sentry(
              e,
              additional_params,
              { va_profile: :veteran_status_title_not_found },
              :warning
            )
        
            return VeteranStatusResponse.new(404, veteran_status_title: nil)
          elsif e.status >= 400 && e.status < 500
            log_exception_to_sentry(
              e,
              additional_params,
              { va_profile: :client_error_related_to_title38 },
              :warning
            )
            return VeteranStatusResponse.new(e.status, veteran_status_title: nil)
          end
        
          handle_error(e)
        rescue => e
          handle_error(e)
        end
      end

      # @return [Boolean] true if user is a title 38 veteran
      def veteran?
        title38_status == 'V1'
      end

      # @return [String] Title 38 status code
      def title38_status
        get_veteran_status_data&.veteran_status_title&.title38_status_code
      end

      # Returns boolean for user being/not being considered a military person
      # based on their Title 38 Status Code.
      #
      # @return [Boolean]
      #
      def military_person?
        title38_status == 'V3' || title38_status == 'V6'
      end

      # VA Profile endpoints use the OID (Organizational Identifier), the EDIPI,
      # and the Assigning Authority ID to identify which person will be updated/retrieved.
      def identity_path
        "#{OID}/#{ERB::Util.url_encode(edipi_with_aaid.to_s)}"
      end

      private

      def edipi_present!
        raise 'User does not have a valid edipi' if @user&.edipi.blank?
      end

      def edipi_with_aaid
        "#{edipi_id}#{aaid}"
      end

      def edipi_id
        return @user&.edipi if @user&.edipi.present?
      end

      def aaid
        return AAID if @user&.edipi.present?
      end


    end
  end
end
