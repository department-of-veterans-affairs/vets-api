# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'
require 'va_profile/stats'
require 'va_profile/models/disability'
require_relative 'configuration'
require_relative 'disability_response'  # not created yet.

module VAProfile
  module Disability
    class Service < VAProfile::Service
      include Common::Client::Concerns::Monitoring

      configuration VAProfile::Disability::Configuration

      OID = '2.16.840.1.113883.3.42.10001.100001.12'  # double check swagger
      AAID = '^NI^200DOD^USDOD'  # double check swagger. 

      # GET's a user's disability info from the VAProfile API
      # If a user is not found in VAProfile, an empty DisabilityResponse with a 404 status will be returned
      # @return [VAProfile::Disability::DisabilityResponse] response wrapper around an service_history object
      ## double check that ^^^
      def get_disability_data
        with_monitoring do
          edipi_present!

          response = perform(:post, identity_path, VAProfile::Models::Disability.in_json)

          DisabilityResponse.from(@current_user, response)  # this might be all I need.
        end
      rescue Common::Client::Errors::ClientError => e
        if e.status == 404
          log_exception_to_sentry(
            e,
            { edipi: @user.edipi },
            # { va_profile: :service_history_not_found },
            { va_profile: :disability_data_not_found },  # is this right??
            :warning
          )

          return DisabilityResponse.new(404, rating: nil)
        elsif e.status >= 400 && e.status < 500
          return DisabilityResponse.new(e.status, rating: nil)
        end

        handle_error(e)
      rescue => e
        handle_error(e)
      end

      # VA Profile military_personnel endpoints use the OID (Organizational Identifier), the EDIPI,
      # and the Assigning Authority ID to identify which person will be updated/retrieved.
      # CHECK TO MAKE SURE THIS IS ACCURATE ^^
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
