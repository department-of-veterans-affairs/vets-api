# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require 'va_profile/models/service_history'
require_relative 'configuration'
require_relative 'service_history_response'

module VAProfile
  module MilitaryPersonnel
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::MilitaryPersonnel::Configuration

      OID = '2.16.840.1.113883.3.42.10001.100001.12'
      AAID = '^NI^200DOD^USDOD'

      # GET's a user's military service history from the VAProfile API
      # If a user is not found in VAProfile, an empty ServiceHistoryResponse with a 404 status will be returned
      # @return [VAProfile::MilitaryPersonnel::ServiceHistoryResponse] response wrapper around an service_history object
      def get_service_history
        with_monitoring do
          edipi_present!
          response = perform(:post, identity_path, VAProfile::Models::ServiceHistory.in_json)

          ServiceHistoryResponse.from(@current_user, response)
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          log_exception_to_sentry(
            e,
            { edipi: @user.edipi },
            { va_profile: :service_history_not_found },
            :warning
          )

          return ServiceHistoryResponse.new(404, episodes: nil)
        elsif e.status >= 400 && e.status < 500
          return ServiceHistoryResponse.new(e.status, episodes: nil)
        end

        handle_error(e)
      rescue => e
        handle_error(e)
      end

      # VA Profile military_personnel endpoints use the OID (Organizational Identifier), the EDIPI,
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
        @user&.edipi.presence
      end

      def aaid
        AAID if @user&.edipi.present?
      end
    end
  end
end
