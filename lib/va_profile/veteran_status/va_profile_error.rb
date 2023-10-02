# frozen_string_literal: true

require 'common/client/concerns/monitoring'
require 'common/client/errors'
require 'va_profile/service'

module VAProfile
  module VeteranStatus
    class VAProfileError < StandardError
      attr_reader :status

      # @param status [Integer] An HTTP status code
      #
      def initialize(status: nil)
        super()
        @status = status
      end
    end
  end
end
