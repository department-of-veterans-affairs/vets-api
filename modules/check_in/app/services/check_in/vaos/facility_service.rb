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

      attr_reader :facility_id

      ##
      # Builds a Service instance
      #
      # @param opts [Hash] options to create the object
      #
      # @return [Service] an instance of this class
      #
      def self.build(opts = {})
        new(opts)
      end

      def initialize(opts)
        @facility_id = opts[:facility_id]

        super()
      end

      def get_facility
        with_monitoring do
          response = perform(:get, facilities_base_path, {}, headers)
          response.body
        end
      end

      def get_clinic(clinic_id:)
        with_monitoring do
          response = perform(:get, facilities_base_path + "/clinics/#{clinic_id}", {}, headers)
          response.body
        end
      end

      def config
        CheckIn::VAOS::Configuration.instance
      end

      private

      def facilities_base_path
        "/facilities/v2/facilities/#{facility_id}"
      end

      def headers
        {
          'Content-Type' => 'application/json'
        }
      end
    end
  end
end
