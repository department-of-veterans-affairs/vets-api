# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module GiBillStatus
    ##
    # Custom error for when the user is attempting to access the service
    # outside of working hours
    #
    class OutsideWorkingHours < Common::Exceptions::BaseError
      ##
      # @return [Array[Common::Exceptions::SerializableError]] An array containing the error
      #
      def errors
        [Common::Exceptions::SerializableError.new(i18n_data)]
      end

      ##
      # @return [Time] The time to retry the request
      #
      def retry_after
        # TODO: - this is correct format, but must write logic to properly calculate
        Time.now.httpdate.in_time_zone('Eastern Time (US & Canada)').to_s
      end

      ##
      # @return [String] The i18n key
      #
      def i18n_key
        'evss.gi_bill_status.outside_working_hours'
      end
    end
  end
end
