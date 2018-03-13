# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module GiBillStatus
    class OutsideWorkingHours < Common::Exceptions::BaseError
      def initialize
        super
      end

      def errors
        [Common::Exceptions::SerializableError.new(i18n_data)]
      end

      def retry_after
        # TODO - this is correct format, but must write logic to properly calculate
        "#{Time.now.httpdate.in_time_zone('Eastern Time (US & Canada)')}"
      end

      def i18n_key
        'evss.gi_bill_status.outside_working_hours'
      end
    end
  end
end
