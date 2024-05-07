# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'
require 'json'
require 'memoist'

module CheckIn
  module VAOS
    class FacilityService < Common::Client::Base
      include SentryLogging
      include Common::Client::Concerns::Monitoring

      STATSD_KEY_PREFIX = 'api.check_in.vaos.facilities'

      def get_facility(facility_id:)
        with_monitoring do
          response = perform(:get, facilities_url(facility_id:), {}, headers)
          response.body
        end
      end

      def get_clinic(facility_id:, clinic_id:)
        with_monitoring do
          response = perform(:get, clinics_url(facility_id:, clinic_id:), {}, headers)
          response.body
        end
      end

      def config
        CheckIn::VAOS::Configuration.instance
      end

      private

      def facilities_url(facility_id:)
        "/facilities/v2/facilities/#{facility_id}"
      end

      def clinics_url(facility_id:, clinic_id:)
        facilities_url(facility_id:) + "/clinics/#{clinic_id}"
      end

      def headers
        {
          'Content-Type' => 'application/json'
        }
      end
    end
  end
end
