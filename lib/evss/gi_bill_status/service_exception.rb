# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module GiBillStatus
    class ServiceException < Common::Exceptions::BaseError
      def initialize
        super
      end

      def errors
        [Common::Exceptions::SerializableError.new(i18n_data)]
      end

      def i18n_key
        'evss.gi_bill_status'
      end
    end
  end
end
