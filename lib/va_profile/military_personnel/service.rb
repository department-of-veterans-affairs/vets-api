# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require 'va_profile/models/service_history'
require 'va_profile/models/dod_service_summary'
require_relative 'configuration'
require_relative 'service_history_response'
require_relative 'dod_service_summary_response'

##
# @see https://qa.vaprofile.va.gov:7005/profile-service/swagger-ui/index.html?urls.primaryName=ProfileServiceV3
# Swagger docs can only be accessed over VA network
module VAProfile
  module MilitaryPersonnel
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = "#{VAProfile::Service::STATSD_KEY_PREFIX}.military_personnel".freeze
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

          ServiceHistoryResponse.from(@user, response)
        end
      rescue Common::Client::Errors::ClientError => e
        error_status = e.status
        if error_status == 404
          log_exception_to_sentry(
            e, { edipi: @user.edipi }, { va_profile: :service_history_not_found }, :warning
          )

          return ServiceHistoryResponse.new(404, episodes: nil)
        elsif error_status && error_status >= 400 && error_status < 500
          return ServiceHistoryResponse.new(error_status, episodes: nil)
        end

        # Sometimes e.status is nil. Why?
        Rails.logger.info('Miscellaneous service history error', error: e)
        handle_error(e)
      rescue => e
        handle_error(e)
      end

      # GET's a user's DoD service summary from the VAProfile API
      # If a user is not found in VAProfile, an empty DodServiceSummaryResponse with a 404 status will be returned
      # @return [VAProfile::MilitaryPersonnel::DodServiceSummaryResponse] response wrapper around a
      # dod_service_summary object
      def get_dod_service_summary
        with_monitoring do
          edipi_present!

          response = perform(:post, identity_path, VAProfile::Models::DodServiceSummary.in_json)

          DodServiceSummaryResponse.from(response)
        end
      rescue Common::Client::Errors::ClientError => e
        error_status = e.status
        if error_status == 404
          Rails.logger.warn('Dod Service Summary not found', edipi: @user.edipi)

          return DodServiceSummaryResponse.new(404, dod_service_summary: nil)
        elsif error_status && (400...500).include?(error_status)
          return DodServiceSummaryResponse.new(error_status, dod_service_summary: nil)
        end

        # Sometimes e.status is nil. Why?
        Rails.logger.info('Miscellaneous DoD service summary error', error: e)
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
